// routes/api/componentes/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;

  // 2. Manejamos GET (todos los admin/supervisores) o POST (solo admin)
  switch (context.request.method) {
    case HttpMethod.get:
      if (rol != 'admin' && rol != 'supervisor') {
        return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
      }
      return _onGet(context);
      
    case HttpMethod.post:
      if (rol != 'admin') {
        return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado: Solo administradores.');
      }
      return _onPost(context);
      
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (LISTAR TODOS LOS COMPONENTES) ---
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
      'SELECT id, nombre_componente, clave_logica FROM Componentes_Renta'
    );

    final componentes = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: componentes);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/componentes! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar componentes.');
  } finally {
    await conn?.close();
  }
}

// --- ¡NUEVA FUNCIÓN POST! (CREAR UN NUEVO COMPONENTE) ---
Future<Response> _onPost(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    final nombre = body['nombre_componente'] as String?;
    final clave = body['clave_logica'] as String?;

    if (nombre == null || nombre.isEmpty || clave == null || clave.isEmpty) {
      return Response(statusCode: HttpStatus.badRequest, body: 'Faltan "nombre_componente" o "clave_logica".');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    await conn.execute(
      '''
      INSERT INTO Componentes_Renta (nombre_componente, clave_logica)
      VALUES (:nombre, :clave)
      ''',
      {
        'nombre': nombre,
        'clave': clave.toUpperCase(), // Guardamos la clave en mayúsculas
      },
    );

    return Response(statusCode: HttpStatus.created, body: 'Componente creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/componentes! ---');
    print(e.toString());
    if (e.toString().contains('clave_logica_unica')) {
      return Response(statusCode: 409, body: 'Error: La "Clave Lógica" ya existe.');
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el componente.');
  } finally {
    await conn?.close();
  }
}