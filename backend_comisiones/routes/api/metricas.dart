// routes/api/metricas.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL (admin/supervisor pueden escribir)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }
  
  // 2. Solo método POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final usuarioId = body['usuario_id'] as int?;
    final nombreMetrica = body['nombre_metrica'] as String?;
    final valor = (body['valor'] as num?)?.toDouble();
    final periodo = body['periodo'] as String?; // ej: "2025-11-01"
    final supervisorId = int.parse(jwtPayload['id'] as String);

    if (usuarioId == null || nombreMetrica == null || valor == null || periodo == null) {
      return Response(statusCode: 400, body: 'Faltan campos: usuario_id, nombre_metrica, valor, periodo.');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // 3. Hacemos un "UPSERT" (INSERT ... ON DUPLICATE KEY UPDATE)
    // Esto crea la métrica si no existe, o la actualiza si ya existe
    // para ese usuario y ese mes.
    await conn.execute(
      '''
      INSERT INTO Metricas_Mensuales_Ejecutivo
        (usuario_id, periodo, nombre_metrica, valor, ingresado_por_id)
      VALUES
        (:usuario_id, :periodo, :nombre_metrica, :valor, :supervisor_id)
      ON DUPLICATE KEY UPDATE
        valor = :valor,
        ingresado_por_id = :supervisor_id,
        fecha_ingreso = CURRENT_TIMESTAMP
      ''',
      {
        'usuario_id': usuarioId,
        'periodo': periodo,
        'nombre_metrica': nombreMetrica,
        'valor': valor,
        'supervisor_id': supervisorId,
      }
    );

    return Response(statusCode: 200, body: 'Métrica guardada');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/metricas! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al guardar la métrica.');
  } finally {
    await conn?.close();
  }
}