// routes/api/equipos/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // 2. Manejamos GET o POST
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context);
    case HttpMethod.post:
      return _onPost(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (LISTAR TODOS LOS EQUIPOS) ---
// (Esta es la que ya tenías)
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

    final resultado = await conn.execute('''
      SELECT 
        e.id, e.nombre_equipo,
        u.nombre_completo as nombre_supervisor
      FROM Equipos e
      LEFT JOIN Usuarios u ON e.supervisor_id = u.id
      ORDER BY e.nombre_equipo;
    ''');

    final equipos = resultado.rows.map((row) {
      final data = row.assoc();
      data['nombre_supervisor'] = data['nombre_supervisor'] ?? 'Sin asignar';
      return data;
    }).toList();

    return Response.json(body: equipos);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/equipos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar equipos.');
  } finally {
    await conn?.close();
  }
}


// --- ¡NUEVA FUNCIÓN POST! (CREAR UN NUEVO EQUIPO) ---
Future<Response> _onPost(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    // 1. Leemos el JSON (ej: {"nombre_equipo": "Equipo Isapre B", "supervisor_id": 103})
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    final nombreEquipo = body['nombre_equipo'] as String?;
    final supervisorId = body['supervisor_id'] as int?; // Opcional

    if (nombreEquipo == null || nombreEquipo.isEmpty) {
      return Response(statusCode: HttpStatus.badRequest, body: 'El "nombre_equipo" es obligatorio.');
    }

    // 2. Conectar a la BD
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // 3. Insertar el nuevo equipo
    await conn.execute(
      '''
      INSERT INTO Equipos (nombre_equipo, supervisor_id)
      VALUES (:nombre, :supervisorId)
      ''',
      {
        'nombre': nombreEquipo,
        'supervisorId': supervisorId, // Será NULL si no se envía
      },
    );

    return Response(statusCode: HttpStatus.created, body: 'Equipo creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/equipos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el equipo.');
  } finally {
    await conn?.close();
  }
}