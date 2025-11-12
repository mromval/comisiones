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
  
  // --- ¡MODIFICACIÓN! Añadir SWITCH ---
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context);
    case HttpMethod.post:
      return _onPost(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- ¡NUEVA FUNCIÓN GET! ---
Future<Response> _onGet(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // Trae todas las métricas del mes actual
    final resultado = await conn.execute(
      '''
      SELECT usuario_id, nombre_metrica, valor 
      FROM Metricas_Mensuales_Ejecutivo
      WHERE MONTH(periodo) = MONTH(CURDATE()) AND YEAR(periodo) = YEAR(CURDATE())
      '''
    );
    
    final metricas = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: metricas);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/metricas! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar métricas.');
  } finally {
    await conn?.close();
  }
}

// --- Renombra tu función existente a _onPost ---
Future<Response> _onPost(RequestContext context) async {
  
  // 1. Verificamos el ROL (ya hecho arriba, pero por seguridad)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }
  
  // (El resto de tu código POST original va aquí sin cambios)
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