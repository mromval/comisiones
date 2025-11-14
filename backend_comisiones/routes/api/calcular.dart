// routes/api/calcular.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Para Future.wait
import 'dart:math';   // Para min()
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:http/http.dart' as http; // Import para la API de UF
import 'package:intl/intl.dart'; // Import para formatear números

// --- Constantes de Claves Lógicas (Sin cambios) ---
const String CLAVE_TRAMO_P1 = 'TRAMO_P1';
const String CLAVE_TRAMO_P2 = 'TRAMO_P2';
const String CLAVE_REF_P1 = 'REF_P1';
const String CLAVE_REF_P2 = 'REF_P2';
const String CLAVE_PYME_T = 'PYME_PCT_T';
const String CLAVE_PYME_M = 'PYME_PCT_M';
const String CLAVE_RANKING_SEGUROS = 'RANK_SEG';
const String CLAVE_RANKING_PYME = 'RANK_PYME';
const String CLAVE_RANKING_ISAPRE = 'RANK_ISAPRE';

Future<Response> onRequest(RequestContext context) async {
  
  // --- (Lógica inicial de onRequest sin cambios) ---
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final config = context.read<Map<String, String>>();
  final jwtPayload = context.read<Map<String, dynamic>>();
  final usuarioId = int.parse(jwtPayload['id'] as String);

  final requestBody = await context.request.body();
  final jsonBody = jsonDecode(requestBody) as Map<String, dynamic>;
  
  double safeParseDouble(dynamic val) => (val as num?)?.toDouble() ?? 0.0;
  int safeParseInt(dynamic val) => (val as num?)?.toInt() ?? 0;

  final inputs = <String, dynamic>{ 
    'uf_p1': safeParseDouble(jsonBody['uf_p1']),
    'uf_p2': safeParseDouble(jsonBody['uf_p2']),
    'uf_pyme_t': safeParseDouble(jsonBody['uf_pyme_t']),
    'uf_pyme_m': safeParseDouble(jsonBody['uf_pyme_m']),
    'ref_p1': safeParseInt(jsonBody['ref_p1']),
    'ref_p2': safeParseInt(jsonBody['ref_p2']),
    'sim_rankings': jsonBody['sim_rankings'] as Map<String, dynamic>? ?? {},
  };
  
  final double totalUfTramos = (inputs['uf_p1'] as double) + (inputs['uf_p2'] as double);
  final double totalUfPyme = (inputs['uf_pyme_t'] as double) + (inputs['uf_pyme_m'] as double);
  final double totalUfGeneral = totalUfTramos + totalUfPyme;
  final int totalContratosReferidos = (inputs['ref_p1'] as int) + (inputs['ref_p2'] as int);
  
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // Leemos el valor de la UF, pero ya no necesitamos el Sueldo Base aquí
    final valoresGlobales = await _getValoresGlobales(conn);
    final double VALOR_UF = valoresGlobales['valor_uf']!;
    
    // --- (Lógica de perfil y métricas sin cambios) ---
    final perfilRes = await conn.execute(
      'SELECT perfil_id FROM Usuarios WHERE id = :id', {'id': usuarioId},
    );
    if (perfilRes.rows.isEmpty) {
      return Response(statusCode: 404, body: 'Usuario no encontrado');
    }
    final perfilId = perfilRes.rows.first.assoc()['perfil_id'];
    if (perfilId == null) {
      return Response.json(
        statusCode: 400,
        body: {'message': 'Tu usuario no tiene un Perfil de Comisión asignado. Contacta a un administrador.'},
      );
    }
    final metricasRes = await conn.execute(
      '''
      SELECT nombre_metrica, valor FROM Metricas_Mensuales_Ejecutivo
      WHERE usuario_id = :id AND MONTH(periodo) = MONTH(CURDATE()) AND YEAR(periodo) = YEAR(CURDATE())
      ''',
      {'id': usuarioId},
    );
    final Map<String, dynamic> metricas = {};
    for (final metrica in metricasRes.rows) {
      final data = metrica.assoc();
      metricas[data['nombre_metrica']!] = double.tryParse(data['valor'] ?? '0.0') ?? 0.0;
    }
    metricas.addAll(inputs);
    metricas['total_uf_tramos'] = totalUfTramos;
    metricas['total_uf_pyme'] = totalUfPyme;
    metricas['total_uf_general'] = totalUfGeneral;
    metricas['total_contratos_ref'] = totalContratosReferidos;
    metricas['valor_uf_dia'] = VALOR_UF; 
    // --- (Fin de lógica de perfil) ---


    // --- 3. MOTOR DE CÁLCULO ---
    double totalBonos = 0;
    final List<String> desglose = [];
    final f = NumberFormat.decimalPattern('es_CL');
    final fPesos = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);

    final reglasActivas = await conn.execute(
      '''
      SELECT 
        rc.id as regla_id, 
        rc.requisito_min_uf_total,
        rc.requisito_tasa_recaudacion,
        rc.requisito_min_contratos,
        rc.tope_monto,
        cr.nombre_componente,
        cr.clave_logica
      FROM Reglas_Concurso rc
      JOIN Componentes_Renta cr ON rc.componente_id = cr.id
      WHERE rc.perfil_id = :perfilId 
        AND rc.esta_activa = 1
        AND CURDATE() BETWEEN rc.periodo_inicio AND rc.periodo_fin
      ''',
      {'perfilId': perfilId},
    );

    if (reglasActivas.rows.isEmpty) {
      desglose.add('No se encontraron concursos activos para tu perfil este mes.');
    }

    final simRankings = metricas['sim_rankings'] as Map<String, dynamic>;

    for (final row in reglasActivas.rows) {
      final regla = row.assoc();
      final nombreComponente = regla['nombre_componente']!;
      final clave = regla['clave_logica']!;
      final reglaId = int.parse(regla['regla_id']!);
      
      final String? motivoFallo = _checkRequisitos(regla, metricas, clave); 
      if (motivoFallo != null) {
        desglose.add('Bono "$nombreComponente" NO OBTENIDO: $motivoFallo');
        continue; 
      }

      double bonoCalculado = 0;
      String desgloseBono = '';
      double valorInput = 0.0; // Para la lógica de "no mostrar desglose si es 0"
      
      switch (clave) {
        case CLAVE_TRAMO_P1:
          valorInput = metricas['uf_p1'] as double;
          final monto = await _buscarMontoFijoEnTramos(conn, reglaId, valorInput);
          if (monto != null) {
            bonoCalculado = monto;
            desgloseBono = fPesos.format(bonoCalculado);
          }
          break; 
        case CLAVE_TRAMO_P2:
          valorInput = metricas['uf_p2'] as double;
          final monto = await _buscarMontoFijoEnTramos(conn, reglaId, valorInput);
          if (monto != null) {
            bonoCalculado = monto;
            desgloseBono = fPesos.format(bonoCalculado);
          }
          break;
          
        case CLAVE_REF_P1:
          valorInput = (metricas['ref_p1'] as int).toDouble();
          final montoUnitario = await _buscarMontoVariableEnTramos(conn, reglaId, valorInput);
          if (montoUnitario != null) {
            bonoCalculado = valorInput * montoUnitario;
            desgloseBono = '$valorInput contratos x ${fPesos.format(montoUnitario)} c/u = ${fPesos.format(bonoCalculado)}';
          }
          break;
        case CLAVE_REF_P2:
          valorInput = (metricas['ref_p2'] as int).toDouble();
          final montoUnitario = await _buscarMontoVariableEnTramos(conn, reglaId, valorInput);
          if (montoUnitario != null) {
            bonoCalculado = valorInput * montoUnitario;
            desgloseBono = '$valorInput contratos x ${fPesos.format(montoUnitario)} c/u = ${fPesos.format(bonoCalculado)}';
          }
          break;
        
        case CLAVE_PYME_T:
          valorInput = metricas['uf_pyme_t'] as double;
          final pymeT = await _buscarPorcentajeEnTramos(conn, reglaId, valorInput);
          if (pymeT != null) {
            bonoCalculado = (valorInput * pymeT) * VALOR_UF;
            desgloseBono = 'UF ${f.format(valorInput)} x ${pymeT * 100}% x UF del Día = ${fPesos.format(bonoCalculado)}';
          }
          break;
        case CLAVE_PYME_M:
          valorInput = metricas['uf_pyme_m'] as double;
          final pymeM = await _buscarPorcentajeEnTramos(conn, reglaId, valorInput);
          if (pymeM != null) {
            bonoCalculado = (valorInput * pymeM) * VALOR_UF;
            desgloseBono = 'UF ${f.format(valorInput)} x ${pymeM * 100}% x UF del Día = ${fPesos.format(bonoCalculado)}';
          }
          break;

        case CLAVE_RANKING_SEGUROS:
        case CLAVE_RANKING_PYME:
        case CLAVE_RANKING_ISAPRE:
          final posSimulada = (simRankings[clave] as int?)?.toDouble() ?? 0.0;
          valorInput = posSimulada; // El "valor" es la posición seleccionada
          if (posSimulada > 0) {
            final monto = await _buscarMontoFijoEnTramos(conn, reglaId, posSimulada);
            if (monto != null) {
               bonoCalculado = monto;
               desgloseBono = fPesos.format(bonoCalculado);
            }
          }
          break; 

        default:
          desgloseBono = 'Regla "$nombreComponente" (clave: $clave) no implementada';
      }

      final double? topeRegla = double.tryParse(regla['tope_monto'] ?? '');
      if (topeRegla != null && bonoCalculado > topeRegla) {
        desglose.add('Bono "$nombreComponente" con TOPE: ${fPesos.format(topeRegla)} (Original: ${fPesos.format(bonoCalculado)})');
        bonoCalculado = topeRegla;
      }
      
      if (bonoCalculado > 0) {
        desglose.add('Bono "$nombreComponente": $desgloseBono');
        totalBonos += bonoCalculado;
      } else if (desgloseBono.isEmpty) { 
        
        // --- ¡MODIFICACIÓN! (Req. 7) ---
        // Solo mostrar "NO OBTENIDO" si el usuario ingresó un valor > 0
        if (valorInput > 0) {
          final minTramoStr = await _buscarTramoMinimo(conn, reglaId);
          if (minTramoStr != null) {
            desglose.add('Bono "$nombreComponente" NO OBTENIDO: No se alcanza el tramo mínimo (Mín: $minTramoStr)');
          } else {
            desglose.add('Bono "$nombreComponente" NO OBTENIDO: \$0 (Sin tramos definidos)');
          }
        }
      } else if (desgloseBono.isNotEmpty && !clave.startsWith('RANK_')) {
         desglose.add(desgloseBono);
      }
      
    } // Fin del For Loop de reglas

    // --- ¡MODIFICACIÓN! (Req. 1) ---
    // Renta Final ahora es SOLO el total de bonos
    final double rentaFinal = totalBonos;

    return Response.json(body: {
      'renta_final': rentaFinal.round(),
      // 'sueldo_base' se elimina de la respuesta principal
      'total_bonos': totalBonos.round(),
      'valor_uf_usado': VALOR_UF.round(), 
      'desglose': desglose,
      'debug_metricas_usadas': metricas, 
    });

  } catch (e) {
    print('--- ¡ERROR EN /api/calcular! ---');
    print(e.toString());
    print("-------------------------------");
    return Response.json(
      statusCode: HttpStatus.internalServerError, 
      body: {'message': 'Error interno al procesar el cálculo: ${e.toString()}'}
    );
  } finally {
    await conn?.close();
  }
}

// --- ¡HELPER MODIFICADO! (Req. 1) ---
// Ya no necesitamos traer el Sueldo Base
Future<Map<String, double>> _getValoresGlobales(MySQLConnection conn) async {
  
  final fUfFallback = conn.execute("SELECT valor FROM Configuracion WHERE llave = 'FALLBACK_VALOR_UF'");
  final fUfApi = http.get(Uri.parse('https://mindicador.cl/api/uf'));

  // Solo esperamos por la UF
  final results = await Future.wait([fUfFallback, fUfApi.catchError((_) => http.Response('', 404))]);

  double ufFallback = 40000; 
  try {
    final ufFallbackRes = results[0] as IResultSet;
    if (ufFallbackRes.rows.isNotEmpty) {
      ufFallback = double.parse(ufFallbackRes.rows.first.assoc()['valor']!);
    }
  } catch (e) { print('Error al leer FALLBACK_VALOR_UF de la BD: $e'); }
  
  double valorUf = ufFallback;
  try {
    final ufRes = results[1] as http.Response;
    if (ufRes.statusCode == 200) {
      final data = jsonDecode(ufRes.body);
      valorUf = (data['serie'][0]['valor'] as num).toDouble();
    } else {
      print('API mindicador.cl falló (Status: ${ufRes.statusCode}). Usando valor UF de fallback.');
    }
  } catch (e) {
    print('Error al contactar API mindicador.cl: $e. Usando valor UF de fallback.');
  }

  return {
    'valor_uf': valorUf,
    // 'sueldo_base' ya no es necesario
  };
}

// --- (Helper _checkRequisitos sin cambios) ---
String? _checkRequisitos(Map<String, String?> regla, Map<String, dynamic> metricas, String claveLogica) {
  
  double? safeParseDouble(String? val) => (val == null || val.isEmpty) ? null : double.tryParse(val);
  int? safeParseInt(String? val) => (val == null || val.isEmpty) ? null : int.tryParse(val);

  final minUf = safeParseDouble(regla['requisito_min_uf_total']);
  final minTasa = safeParseDouble(regla['requisito_tasa_recaudacion']);
  final minContratos = safeParseInt(regla['requisito_min_contratos']);

  double ufEjecutivo = (metricas['total_uf_general'] as double?) ?? 0.0;
  String ufTipo = "Total General";
  
  if (claveLogica.startsWith('TRAMO_') || claveLogica == CLAVE_RANKING_SEGUROS) {
    ufEjecutivo = (metricas['total_uf_tramos'] as double?) ?? 0.0;
    ufTipo = "Total Tramos";
  } else if (claveLogica.startsWith('PYME_') || claveLogica == CLAVE_RANKING_PYME) {
    ufEjecutivo = (metricas['total_uf_pyme'] as double?) ?? 0.0;
    ufTipo = "Total PYME";
  }
  
  int contratosEjecutivo = (metricas['total_contratos_ref'] as int?) ?? 0;
  final tasaEjecutivo = (metricas['tasa_recaudacion'] as double?) ?? 0.0; 

  if (minUf != null && ufEjecutivo < minUf) {
    return 'Mínimo $minUf UF ($ufTipo)';
  }
  if (minTasa != null && tasaEjecutivo < minTasa) {
    return 'Mínimo $minTasa% Tasa Recaudación';
  }
  if (minContratos != null && contratosEjecutivo < minContratos) {
    return 'Mínimo $minContratos Contratos';
  }
  
  return null; // ¡Pasa todos los requisitos!
}

// --- (Helper _buscarTramoMinimo sin cambios) ---
Future<String?> _buscarTramoMinimo(MySQLConnection conn, int reglaId) async {
  final minRes = await conn.execute(
    'SELECT MIN(tramo_desde_uf) as min_tramo FROM Reglas_Tramos WHERE regla_id = :reglaId',
    {'reglaId': reglaId},
  );

  if (minRes.rows.isNotEmpty) {
    return minRes.rows.first.assoc()['min_tramo'];
  }
  return null;
}


// --- (Helper _buscarMontoFijoEnTramos sin cambios) ---
Future<double?> _buscarMontoFijoEnTramos(MySQLConnection conn, int reglaId, double valor) async {
  if (valor <= 0) return null; 

  final tramoRes = await conn.execute(
    '''
    SELECT monto_pago FROM Reglas_Tramos
    WHERE regla_id = :reglaId AND :valor BETWEEN tramo_desde_uf AND tramo_hasta_uf
    LIMIT 1
    ''',
    {'reglaId': reglaId, 'valor': valor},
  );

  if (tramoRes.rows.isNotEmpty) {
    final tramoData = tramoRes.rows.first.assoc();
    return double.parse(tramoData['monto_pago']!);
  }
  return null;
}

// --- (Helper _buscarMontoVariableEnTramos sin cambios) ---
Future<double?> _buscarMontoVariableEnTramos(MySQLConnection conn, int reglaId, double valor) async {
  if (valor <= 0) return null;

  final tramoRes = await conn.execute(
    '''
    SELECT monto_pago FROM Reglas_Tramos
    WHERE regla_id = :reglaId AND :valor BETWEEN tramo_desde_uf AND tramo_hasta_uf
    LIMIT 1
    ''',
    {'reglaId': reglaId, 'valor': valor},
  );

  if (tramoRes.rows.isNotEmpty) {
    final tramoData = tramoRes.rows.first.assoc();
    return double.parse(tramoData['monto_pago']!);
  }
  return null;
}


// --- (Helper _buscarPorcentajeEnTramos sin cambios) ---
Future<double?> _buscarPorcentajeEnTramos(MySQLConnection conn, int reglaId, double uf) async {
  if (uf <= 0) return null;

  final tramoRes = await conn.execute(
    '''
    SELECT monto_pago FROM Reglas_Tramos
    WHERE regla_id = :reglaId AND :uf BETWEEN tramo_desde_uf AND tramo_hasta_uf
    LIMIT 1
    ''',
    {'reglaId': reglaId, 'uf': uf},
  );

  if (tramoRes.rows.isNotEmpty) {
    final tramoData = tramoRes.rows.first.assoc();
    return double.parse(tramoData['monto_pago']!);
  }
  return null;
}