import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Para Future.wait
import 'dart:math';   // Para min()
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:http/http.dart' as http; // <-- ¡NUEVO IMPORT!

// --- Constantes de Claves Lógicas (Deben coincidir con tu BD) ---
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
  
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // --- 1. LEER DATOS INICIALES ---
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
    'sim_ranking': jsonBody['sim_ranking'] as String?,
  };
  
  final double totalUfTramos = (inputs['uf_p1'] as double) + (inputs['uf_p2'] as double);
  final double totalUfPyme = (inputs['uf_pyme_t'] as double) + (inputs['uf_pyme_m'] as double);
  final double totalUfGeneral = totalUfTramos + totalUfPyme;
  final int totalContratosReferidos = (inputs['ref_p1'] as int) + (inputs['ref_p2'] as int);
  
  MySQLConnection? conn;

  try {
    // --- 2. CONECTAR A LA BD Y OBTENER DATOS GLOBALES ---
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // ¡Obtiene Sueldo Base y UF en paralelo!
    final valoresGlobales = await _getValoresGlobales(conn);
    final double SUELDO_BASE = valoresGlobales['sueldo_base']!;
    final double VALOR_UF = valoresGlobales['valor_uf']!;
    
    // a) Buscar el perfil_id del usuario
    final perfilRes = await conn.execute(
      'SELECT perfil_id FROM Usuarios WHERE id = :id', {'id': usuarioId},
    );
    if (perfilRes.rows.isEmpty) {
      return Response(statusCode: 404, body: 'Usuario no encontrado');
    }
    final perfilId = perfilRes.rows.first.assoc()['perfil_id'];
    if (perfilId == null) {
      return Response.json(
        statusCode: 400, // Bad Request
        body: {'message': 'Tu usuario no tiene un Perfil de Comisión asignado. Contacta a un administrador.'},
      );
    }

    // b) Buscar las métricas que cargó el supervisor (ej: tasa_recaudacion)
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
      metricas[data['nombre_metrica']!] = data['valor'];
    }
    
    // c) Juntar todas las métricas en un mapa
    metricas.addAll(inputs);
    metricas['total_uf_tramos'] = totalUfTramos;
    metricas['total_uf_pyme'] = totalUfPyme;
    metricas['total_uf_general'] = totalUfGeneral;
    metricas['total_contratos_ref'] = totalContratosReferidos;
    metricas['valor_uf_dia'] = VALOR_UF; // Añadimos la UF por si se necesita

    // --- 3. MOTOR DE CÁLCULO ---
    double totalBonos = 0;
    final List<String> desglose = [];

    // d) Buscar las REGLAS ACTIVAS para este perfil y este mes
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

    // e) Iterar sobre cada regla activa
    for (final row in reglasActivas.rows) {
      final regla = row.assoc();
      final nombreComponente = regla['nombre_componente']!;
      final clave = regla['clave_logica']!;
      final reglaId = int.parse(regla['regla_id']!);
      
      // 1. Verificar Requisitos
      final String? motivoFallo = _checkRequisitos(regla, metricas);
      if (motivoFallo != null) {
        desglose.add('Bono "$nombreComponente" NO OBTENIDO: $motivoFallo');
        continue; 
      }

      // 2. Si pasa, calcular el bono
      double bonoCalculado = 0;
      
      switch (clave) {
        // --- Bonos de Monto Fijo (Tramos y Referidos) ---
        case CLAVE_TRAMO_P1:
          bonoCalculado = await _buscarMontoFijoEnTramos(conn, reglaId, metricas['uf_p1'] as double);
          break;
        case CLAVE_TRAMO_P2:
          bonoCalculado = await _buscarMontoFijoEnTramos(conn, reglaId, metricas['uf_p2'] as double);
          break;
        case CLAVE_REF_P1:
          bonoCalculado = await _buscarMontoFijoEnTramos(conn, reglaId, (metricas['ref_p1'] as int).toDouble());
          break;
        case CLAVE_REF_P2:
          bonoCalculado = await _buscarMontoFijoEnTramos(conn, reglaId, (metricas['ref_p2'] as int).toDouble());
          break;
          
        // --- Bonos de Porcentaje (% de UF) ---
        case CLAVE_PYME_T:
          bonoCalculado = await _calcularPyme(conn, reglaId, metricas['uf_pyme_t'] as double, VALOR_UF);
          break;
        case CLAVE_PYME_M:
          bonoCalculado = await _calcularPyme(conn, reglaId, metricas['uf_pyme_m'] as double, VALOR_UF);
          break;

        // --- Bonos de Ranking (Monto Fijo) ---
        case CLAVE_RANKING_SEGUROS:
        case CLAVE_RANKING_PYME:
        case CLAVE_RANKING_ISAPRE:
          bonoCalculado = _calcularRanking(regla, metricas);
          break;

        default:
          desglose.add('Regla "$nombreComponente" (clave: $clave) no implementada');
      }

      // 3. Aplicar TOPE (si existe)
      final double? topeRegla = double.tryParse(regla['tope_monto'] ?? '');
      if (topeRegla != null && bonoCalculado > topeRegla) {
        desglose.add('Bono "$nombreComponente" aplicado con TOPE de \$${topeRegla.toStringAsFixed(0)} (Original: \$${bonoCalculado.toStringAsFixed(0)})');
        bonoCalculado = topeRegla;
      }
      
      // 4. Sumar al total
      if (bonoCalculado > 0) {
        desglose.add('Bono "$nombreComponente": \$${bonoCalculado.toStringAsFixed(0)}');
        totalBonos += bonoCalculado;
      }
    }

    // --- 4. RESULTADO FINAL ---
    final double rentaFinal = SUELDO_BASE + totalBonos;

    return Response.json(body: {
      'renta_final': rentaFinal.round(),
      'sueldo_base': SUELDO_BASE.round(),
      'total_bonos': totalBonos.round(),
      'desglose': desglose,
      'debug_metricas_usadas': metricas, // Para depuración
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

// --- HELPER: Obtener Sueldo Base y Valor UF ---
Future<Map<String, double>> _getValoresGlobales(MySQLConnection conn) async {
  
  // 1. Preparamos las tareas en paralelo
  final fSueldo = conn.execute("SELECT valor FROM Configuracion WHERE llave = 'SUELDO_BASE'");
  final fUfFallback = conn.execute("SELECT valor FROM Configuracion WHERE llave = 'FALLBACK_VALOR_UF'");
  final fUfApi = http.get(Uri.parse('https://mindicador.cl/api/uf'));

  // 2. Ejecutamos todo al mismo tiempo
  final results = await Future.wait([fSueldo, fUfFallback, fUfApi.catchError((_) => http.Response('', 404))]);

  // 3. Procesamos Sueldo Base
  double sueldoBase = 529000; // Default por si falla la BD
  try {
    final sueldoRes = results[0] as IResultSet;
    if (sueldoRes.rows.isNotEmpty) {
      sueldoBase = double.parse(sueldoRes.rows.first.assoc()['valor']!);
    }
  } catch (e) { print('Error al leer SUELDO_BASE de la BD: $e'); }

  // 4. Procesamos UF Fallback
  double ufFallback = 40000; // Default
  try {
    final ufFallbackRes = results[1] as IResultSet;
    if (ufFallbackRes.rows.isNotEmpty) {
      ufFallback = double.parse(ufFallbackRes.rows.first.assoc()['valor']!);
    }
  } catch (e) { print('Error al leer FALLBACK_VALOR_UF de la BD: $e'); }
  
  // 5. Procesamos API UF
  double valorUf = ufFallback;
  try {
    final ufRes = results[2] as http.Response;
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
    'sueldo_base': sueldoBase,
    'valor_uf': valorUf,
  };
}


// --- HELPER: Chequeo de Requisitos ---
String? _checkRequisitos(Map<String, String?> regla, Map<String, dynamic> metricas) {
  
  double? safeParseDouble(String? val) => (val == null || val.isEmpty) ? null : double.tryParse(val);
  int? safeParseInt(String? val) => (val == null || val.isEmpty) ? null : int.tryParse(val);

  final minUf = safeParseDouble(regla['requisito_min_uf_total']);
  final minTasa = safeParseDouble(regla['requisito_tasa_recaudacion']);
  final minContratos = safeParseInt(regla['requisito_min_contratos']);

  final ufEjecutivo = (metricas['total_uf_general'] as double?) ?? 0.0;
  // ¡Importante! El doc dice 85%, asumimos que el supervisor ingresa "85" y no "0.85"
  final tasaEjecutivo = (metricas['tasa_recaudacion'] as num?)?.toDouble() ?? 0.0; 
  final contratosEjecutivo = (metricas['total_contratos_ref'] as int?) ?? 0;

  if (minUf != null && ufEjecutivo < minUf) {
    return 'No cumples el Mínimo de UF (Requerido: $minUf / Tienes: $ufEjecutivo)';
  }
  if (minTasa != null && tasaEjecutivo < minTasa) {
    return 'No cumples la Tasa de Recaudación (Requerido: $minTasa% / Tienes: $tasaEjecutivo%)';
  }
  if (minContratos != null && contratosEjecutivo < minContratos) {
    return 'No cumples el Mínimo de Contratos (Requerido: $minContratos / Tienes: $contratosEjecutivo)';
  }
  
  return null; // ¡Pasa todos los requisitos!
}


// --- HELPER: Busca un MONTO FIJO en la tabla de tramos ---
Future<double> _buscarMontoFijoEnTramos(MySQLConnection conn, int reglaId, double valor) async {
  
  if (valor <= 0) return 0.0; // No buscar si no hay ventas

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
    // 'monto_pago' es un monto fijo (ej: 50000)
    return double.parse(tramoData['monto_pago']!);
  }
  return 0.0;
}

// --- HELPER: Busca un PORCENTAJE en tramos y lo convierte a pesos ---
Future<double> _calcularPyme(MySQLConnection conn, int reglaId, double uf, double valorUf) async {
  
  if (uf <= 0) return 0.0;

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
    // 'monto_pago' es un porcentaje (ej: 0.30)
    final double porcentaje = double.parse(tramoData['monto_pago']!);
    
    // Convertimos a pesos
    final double bonoEnPesos = (uf * porcentaje) * valorUf;
    return bonoEnPesos;
  }
  return 0.0;
}


// --- HELPER: Cálculo Ranking (Hardcodeado del doc) ---
double _calcularRanking(Map<String, String?> regla, Map<String, dynamic> metricas) {
  final rankingSimulado = metricas['sim_ranking'] as String?;
  final claveRegla = regla['clave_logica']!;

  const montosRanking = {
    // Seguros
    'RANK_SEG_1': 400000.0,
    'RANK_SEG_2_3': 350000.0,
    'RANK_SEG_4_5': 300000.0,
    'RANK_SEG_6_8': 200000.0,
    'RANK_SEG_9_10': 150000.0,
    
    // PYME
    'RANK_PYME_1': 400000.0,
    'RANK_PYME_2_3': 350000.0,
    'RANK_PYME_4_5': 300000.0,
    'RANK_PYME_6_7': 150000.0,
    
    // Isapre
    'RANK_ISAPRE_1': 500000.0,
    'RANK_ISAPRE_2_3': 400000.0,
    'RANK_ISAPRE_4_5': 300000.0,
    'RANK_ISAPRE_6_8': 150000.0,
  };

  if (rankingSimulado == null) {
    return 0.0;
  }
  
  // El ranking simulado (ej: 'RANK_SEG_1') debe pertenecer
  // al concurso activo (ej: 'RANK_SEG')
  if (rankingSimulado.startsWith(claveRegla)) {
     return montosRanking[rankingSimulado] ?? 0.0;
  }
  
  return 0.0;
}