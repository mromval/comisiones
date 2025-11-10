// routes/api/componentes/[id].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'id' en la URL es el ID del COMPONENTE
Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  // ¡Importante! Solo un 'admin' puede gestionar componentes
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

// --- FUNCIÓN PUT (ACTUALIZAR UN COMPONENTE) ---
Future<Response> _onPut(RequestContext context, String componenteId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final updateFields = <String>[];
    final parameters = <String, dynamic>{'id': int.parse(componenteId)};

    if (body.containsKey('nombre_componente')) {
      updateFields.add('nombre_componente = :nombre');
      parameters['nombre'] = body['nombre_componente'];
    }
    if (body.containsKey('clave_logica')) {
      updateFields.add('clave_logica = :clave');
      parameters['clave'] = (body['clave_logica'] as String).toUpperCase();
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

    final query = 'UPDATE Componentes_Renta SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters);

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Componente actualizado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró un componente con el ID $componenteId.'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN PUT /api/componentes/$componenteId! ---');
    print(e.toString());
    if (e.toString().contains('clave_logica_unica')) {
      return Response(statusCode: 409, body: 'Error: La "Clave Lógica" ya existe.');
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el componente.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (BORRAR UN COMPONENTE) ---
Future<Response> _onDelete(RequestContext context, String componenteId) async {
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
      'DELETE FROM Componentes_Renta WHERE id = :id',
      {'id': int.parse(componenteId)},
    );

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Componente eliminado correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró un componente con el ID $componenteId.'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/componentes/$componenteId! ---');
    print(e.toString());
    if (e.toString().contains('FOREIGN KEY')) {
      return Response(
        statusCode: HttpStatus.conflict, // 409
        body: 'Error: No se puede eliminar el componente porque está siendo usado por un concurso.'
      );
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el componente.');
  } finally {
    await conn?.close();
  }
}