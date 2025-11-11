// routes/api/tramos/[tramoId].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'tramoId' en la URL es el ID del TRAMO (de la tabla Reglas_Tramos)
Future<Response> onRequest(RequestContext context, String tramoId) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // Manejamos PUT o DELETE
  switch (context.request.method) {
    case HttpMethod.put:
      return _onPut(context, tramoId);
    case HttpMethod.delete:
      return _onDelete(context, tramoId);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN PUT (ACTUALIZAR UN TRAMO) ---
Future<Response> _onPut(RequestContext context, String tramoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final updateFields = <String>[];
    final parameters = <String, dynamic>{'id': int.parse(tramoId)};

    // ¡Lógica corregida para 'monto_pago'!
    if (body.containsKey('tramo_desde_uf')) {
      updateFields.add('tramo_desde_uf = :desde');
      parameters['desde'] = (body['tramo_desde_uf'] as num).toDouble();
    }
    if (body.containsKey('tramo_hasta_uf')) {
      updateFields.add('tramo_hasta_uf = :hasta');
      parameters['hasta'] = (body['tramo_hasta_uf'] as num).toDouble();
    }
    if (body.containsKey('monto_pago')) {
      updateFields.add('monto_pago = :monto');
      parameters['monto'] = (body['monto_pago'] as num).toDouble();
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

    final query = 'UPDATE Reglas_Tramos SET ${updateFields.join(', ')} WHERE id = :id';
    await conn.execute(query, parameters);

    return Response(body: 'Tramo actualizado correctamente');

  } catch (e) {
    print('--- ¡ERROR EN PUT /api/tramos/$tramoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el tramo.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (BORRAR UN TRAMO) ---
Future<Response> _onDelete(RequestContext context, String tramoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    await conn.execute(
      'DELETE FROM Reglas_Tramos WHERE id = :id',
      {'id': int.parse(tramoId)},
    );

    return Response(body: 'Tramo eliminado correctamente');

  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/tramos/$tramoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el tramo.');
  } finally {
    await conn?.close();
  }
}