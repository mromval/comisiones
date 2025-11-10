import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

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
  final double ufVendidas = (jsonBody['uf_vendidas'] as num).toDouble();
  
  MySQLConnection? conn;

  try {
    // --- 2. CONECTAR A LA BD ---
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // a) Buscar el perfil del usuario
    final perfilRes = await conn.execute(
      'SELECT perfil_id FROM Usuarios WHERE id = :id', {'id': usuarioId},
    );
    if (perfilRes.rows.isEmpty) {
      return Response(statusCode: 404, body: 'Usuario no encontrado');
    }
    final perfilId = perfilRes.rows.first.assoc()['perfil_id'];

    // b) Buscar las métricas que cargó el supervisor (MISMO CÓDIGO DE ANTES)
    final metricasRes = await conn.execute(
      '''
      SELECT nombre_metrica, valor FROM Metricas_Mensuales_Ejecutivo
      WHERE usuario_id = :id AND MONTH(periodo) = MONTH(CURDATE()) AND YEAR(periodo) = YEAR(CURDATE())
      ''',
      {'id': usuarioId},
    );

    // c) Juntar todas las métricas en un mapa
    final Map<String, dynamic> datosCompletos = {
      'uf_vendidas': ufVendidas,
    };
    for (final metrica in metricasRes.rows) {
      final data = metrica.assoc();
      datosCompletos[data['nombre_metrica']!] = data['valor'];
    }

    // --- 3. NUEVO MOTOR DE CÁLCULO (BASADO EN FECHAS) ---
    
    double bonosTotales = 0;
    double factorFinal = 1.0;
    final List<String> desglose = [];

    // d) Buscar las REGLAS ACTIVAS para este perfil y este mes
    final reglasActivas = await conn.execute(
      '''
      SELECT rc.id as regla_id, cr.clave_logica
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
    for (final regla in reglasActivas.rows) {
      final dataRegla = regla.assoc();
      final String clave = dataRegla['clave_logica']!;
      final int reglaId = int.parse(dataRegla['regla_id']!);

      switch (clave) {
        
        case 'TRAMO_UF':
          // ¡Nueva lógica! Buscamos el tramo específico en la tabla hija
          final tramoRes = await conn.execute(
            '''
            SELECT monto_pago, tramo_desde_uf, tramo_hasta_uf FROM Reglas_Tramos
            WHERE regla_id = :reglaId AND :ufVendidas BETWEEN tramo_desde_uf AND tramo_hasta_uf
            ''',
            {'reglaId': reglaId, 'ufVendidas': ufVendidas},
          );

          if (tramoRes.rows.isNotEmpty) {
            final tramoData = tramoRes.rows.first.assoc();
            final double monto = double.parse(tramoData['monto_pago']!);
            bonosTotales += monto;
            desglose.add(
              'Bono Tramos UF (${tramoData['tramo_desde_uf']}-${tramoData['tramo_hasta_uf']}): \$${monto.toStringAsFixed(0)}'
            );
          } else {
            desglose.add('Bono Tramos UF: No alcanzaste el tramo mínimo.');
          }
          break;

        case 'FACTOR_FUGA':
          // Esta lógica (aún en standby) se configuraría en Reglas_Concurso
          // (por ejemplo, con una tabla "Reglas_Factores" similar a "Reglas_Tramos")
          desglose.add('Factor Fuga: (Lógica pendiente de definición)');
          break;

        default:
          desglose.add('Regla "$clave" no implementada');
      }
    }

    // --- 5. RESULTADO FINAL ---
    final double rentaFinal = bonosTotales * factorFinal;

    return Response.json(body: {
      'renta_final': rentaFinal,
      'bonos_base': bonosTotales,
      'factor_aplicado': factorFinal,
      'desglose': desglose,
      'datos_usados': datosCompletos,
    });

  } catch (e) {
    print('--- ¡ERROR EN /api/calcular! ---');
    print(e.toString());
    print("-------------------------------");
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al procesar el cálculo.');
  } finally {
    await conn?.close();
  }
}