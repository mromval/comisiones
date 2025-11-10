// routes/api/perfiles/[id].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'id' en la URL es el ID del PERFIL
Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  // ¡Importante! Solo un 'admin' puede gestionar perfiles
  if (rol != 'admin') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  switch (context.request.method) {
    case HttpMethod.put:
      return _onPut(context, id);
    case HttpMethod.delete:
      return _onDelete(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN PUT (ACTUALIZAR UN PERFIL) ---
Future<Response> _onPut(RequestContext context, String perfilId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final updateFields = <String>[];
    final parameters = <String, dynamic>{'id': int.parse(perfilId)};

    if (body.containsKey('nombre_perfil')) {
      updateFields.add('nombre_perfil = :nombre');
      parameters['nombre'] = body['nombre_perfil'];
    }
    if (body.containsKey('orden_sorteo')) {
      updateFields.add('orden_sorteo = :orden');
      parameters['orden'] = body['orden_sorteo'];
    }

    if (updateFields.isEmpty) {
      return Response(statusCode: 400, body: 'No hay campos para actualizar');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    final query = 'UPDATE Perfiles SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters);

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Perfil actualizado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró un perfil con el ID $perfilId.'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN PUT /api/perfiles/$perfilId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el perfil.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (BORRAR UN PERFIL) ---
Future<Response> _onDelete(RequestContext context, String perfilId) async {
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
      'DELETE FROM Perfiles WHERE id = :id',
      {'id': int.parse(perfilId)},
    );

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Perfil eliminado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró un perfil con el ID $perfilId.'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/perfiles/$perfilId! ---');
    print(e.toString());
    // Error si el perfil está en uso por un Usuario o Concurso
    if (e.toString().contains('FOREIGN KEY')) {
      return Response(
        statusCode: HttpStatus.conflict, // 409
        body: 'Error: No se puede eliminar el perfil porque está siendo usado por un usuario o un concurso.'
      );
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el perfil.');
  } finally {
    await conn?.close();
  }
}