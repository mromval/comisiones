// routes/api/equipos/[id].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'id' en la URL es el ID del EQUIPO
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

// --- FUNCIÓN PUT (CORREGIDA CON VALIDACIÓN DE ROL) ---
Future<Response> _onPut(RequestContext context, String equipoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final updateFields = <String>[];
    final parameters = <String, dynamic>{'id': int.parse(equipoId)};

    // --- CONECTAR A LA BD (LO HACEMOS ANTES PARA VALIDAR) ---
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // --- ¡INICIO DE LA VALIDACIÓN DE SUPERVISOR! ---
    if (body.containsKey('supervisor_id')) {
      final newSupervisorId = body['supervisor_id'] as int?;
      
      // Si el ID no es nulo, verificamos el rol de ese usuario
      if (newSupervisorId != null) {
        final userCheck = await conn.execute(
          'SELECT rol FROM Usuarios WHERE id = :id',
          {'id': newSupervisorId}
        );
        
        if (userCheck.rows.isEmpty) {
          return Response(statusCode: 404, body: 'Error: El usuario supervisor asignado no existe.');
        }
        
        final userRol = userCheck.rows.first.assoc()['rol'];
        if (userRol != 'supervisor' && userRol != 'admin') {
          return Response(
            statusCode: 400, // 400 Bad Request
            body: 'Error: El usuario seleccionado no tiene rol de supervisor o admin.'
          );
        }
      }
      
      // Si el ID es nulo o si pasó la validación, lo añadimos
      updateFields.add('supervisor_id = :supervisorId');
      parameters['supervisorId'] = newSupervisorId;
    }
    // --- FIN DE LA VALIDACIÓN ---

    if (body.containsKey('nombre_equipo')) {
      updateFields.add('nombre_equipo = :nombre');
      parameters['nombre'] = body['nombre_equipo'];
    }

    if (updateFields.isEmpty) {
      return Response(statusCode: 400, body: 'No hay campos para actualizar');
    }

    // --- Ejecutamos el UPDATE ---
    final query = 'UPDATE Equipos SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters);

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Equipo actualizado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound, // 404
        body: 'Error: No se encontró un equipo con el ID $equipoId.'
      );
    }

  } catch (e) {
    print('--- ¡ERROR EN PUT /api/equipos/$equipoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el equipo.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (CORREGIDA CON VERIFICACIÓN) ---
Future<Response> _onDelete(RequestContext context, String equipoId) async {
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
    // 1. Capturamos el resultado
    final resultado = await conn.execute(
      'DELETE FROM Equipos WHERE id = :id',
      {'id': int.parse(equipoId)},
    );

    // 2. Verificamos si realmente se borró una fila
    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Equipo eliminado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound, // 404
        body: 'Error: No se encontró un equipo con el ID $equipoId.'
      );
    }
    // --- FIN DE LA MODIFICACIÓN ---

  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/equipos/$equipoId! ---');
    print(e.toString());
    if (e.toString().contains('FOREIGN KEY')) {
      return Response(
        statusCode: HttpStatus.conflict,
        body: 'Error: No se puede eliminar el equipo porque aún tiene usuarios asignados.'
      );
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el equipo.');
  } finally {
    await conn?.close();
  }
}