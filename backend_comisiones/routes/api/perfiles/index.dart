// backend_comisiones/routes/api/perfiles/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;

  // --- MODIFICACIÓN: Lógica de permisos separada por método ---
  switch (context.request.method) {
    case HttpMethod.get:
      // Permitir GET a admin y supervisor para llenar los dropdowns
      if (rol != 'admin' && rol != 'supervisor') {
         return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
      }
      return _onGet(context);
      
    case HttpMethod.post:
      // Solo Admin puede CREAR perfiles
      if (rol != 'admin') {
        return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado: Solo administradores.');
      }
      return _onPost(context);
      
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (LISTAR TODOS LOS PERFILES) ---
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

    final resultado = await conn.execute(
      'SELECT id, nombre_perfil, orden_sorteo FROM Perfiles ORDER BY orden_sorteo ASC'
    );

    final perfiles = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: perfiles);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/perfiles! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar perfiles.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN POST (CREAR UN NUEVO PERFIL) ---
Future<Response> _onPost(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    final nombrePerfil = body['nombre_perfil'] as String?;
    final ordenSorteo = body['orden_sorteo'] as int?;

    if (nombrePerfil == null || nombrePerfil.isEmpty || ordenSorteo == null) {
      return Response(statusCode: HttpStatus.badRequest, body: 'Faltan "nombre_perfil" u "orden_sorteo".');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    await conn.execute(
      '''
      INSERT INTO Perfiles (nombre_perfil, orden_sorteo)
      VALUES (:nombre, :orden)
      ''',
      {
        'nombre': nombrePerfil,
        'orden': ordenSorteo,
      },
    );

    return Response(statusCode: HttpStatus.created, body: 'Perfil creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/perfiles! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el perfil.');
  } finally {
    await conn?.close();
  }
}