// routes/api/usuarios/[id].dart
import 'dart:io';
import 'dart:convert'; // Para jsonDecode
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:bcrypt/bcrypt.dart'; 

Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;

  if (rol != 'admin' && rol != 'supervisor') {
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

// --- MÉTODO PUT (Sin cambios) ---
Future<Response> _onPut(RequestContext context, String id) async {
  // ... (El código de _onPut que ya teníamos es idéntico) ...
  final payload = await context.request.body();
  final body = jsonDecode(payload) as Map<String, dynamic>;

  final updateFields = <String>[];
  final parameters = <String, dynamic>{'id': int.parse(id)};

  if (body.containsKey('rol')) {
    updateFields.add('rol = :rol');
    parameters['rol'] = body['rol'];
  }
  if (body.containsKey('perfil_id')) {
    updateFields.add('perfil_id = :perfilId');
    parameters['perfilId'] = body['perfil_id'];
  }
  if (body.containsKey('equipo_id')) {
    updateFields.add('equipo_id = :equipoId');
    parameters['equipoId'] = body['equipo_id'];
  }

  if (body.containsKey('password') && (body['password'] as String).isNotEmpty) {
    final passwordHash = BCrypt.hashpw(body['password'] as String, BCrypt.gensalt());
    updateFields.add('password_hash = :passwordHash');
    parameters['passwordHash'] = passwordHash;
  }

  if (updateFields.isEmpty) {
    return Response(statusCode: 400, body: 'No hay campos para actualizar');
  }

  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    final query = 'UPDATE Usuarios SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters);

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Usuario actualizado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró un usuario con el ID $id.'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN PUT /api/usuarios/$id! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el usuario.');
  } finally {
    await conn?.close();
  }
}

// --- ¡MÉTODO DELETE (ACTUALIZADO)! ---
Future<Response> _onDelete(RequestContext context, String id) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // --- ¡INICIO DE LA MODIFICACIÓN! ---
    // 1. Ahora, además de 'esta_activo = 0', cambiamos el email
    //    Usamos CONCAT() de SQL para añadir un sufijo único
    final resultado = await conn.execute(
      '''
      UPDATE Usuarios 
      SET 
        esta_activo = 0, 
        email = CONCAT(email, '_INACTIVO_ID_', :id)
      WHERE 
        id = :id AND esta_activo = 1 
      ''',
      {'id': int.parse(id)},
    );

    // 2. Verificamos si realmente se desactivó (y no estaba ya inactivo)
    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Usuario desactivado y email liberado.');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: El usuario no fue encontrado o ya estaba inactivo.'
      );
    }
    // --- FIN DE LA MODIFICACIÓN ---

  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/usuarios/$id! ---');
    print(e.toString());
    if (e.toString().contains('FOREIGN KEY')) {
      return Response(
        statusCode: HttpStatus.conflict,
        body: 'Error: No se puede eliminar el equipo porque aún tiene usuarios asignados.'
      );
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el usuario.');
  } finally {
    await conn?.close();
  }
}