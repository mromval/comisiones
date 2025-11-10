import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'tramoId' en la URL es el ID del TRAMO
Future<Response> onRequest(RequestContext context, String tramoId) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // 1. Averiguamos a qué tabla pertenece este TRAMO
  final config = context.read<Map<String, String>>();
  final conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
  await conn.connect();

  // Buscamos el tramo en TODAS las tablas de tramos
  final rTramoUF = await conn.execute('SELECT regla_id FROM Reglas_Tramos_UF WHERE id = :id', {'id': tramoId});
  // (Aquí añadiríamos la búsqueda en Reglas_Tramos_Pyme, etc.)

  String? tabla;
  if(rTramoUF.rows.isNotEmpty) tabla = 'Reglas_Tramos_UF';

  await conn.close();

  if(tabla == null) {
    return Response(statusCode: 404, body: 'Tramo no encontrado en ninguna tabla.');
  }

  // 2. "Router" de lógica: Llama a la función correcta
  switch (context.request.method) {
    case HttpMethod.put:
      return _onPut(context, tramoId, tabla, config);
    case HttpMethod.delete:
      return _onDelete(context, tramoId, tabla, config);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN PUT (ACTUALIZAR UN TRAMO) ---
Future<Response> _onPut(RequestContext context, String tramoId, String tabla, Map<String, String> config) async {
  MySQLConnection? conn;
  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;

    final updateFields = <String>[];
    final parameters = <String, dynamic>{'id': int.parse(tramoId)};

    // Construimos la consulta dinámicamente para la tabla específica
    if(tabla == 'Reglas_Tramos_UF') {
      if (body.containsKey('tramo_desde_uf')) {
        updateFields.add('tramo_desde_uf = :desde');
        parameters['desde'] = (body['tramo_desde_uf'] as num).toDouble();
      }
      if (body.containsKey('tramo_hasta_uf')) {
        updateFields.add('tramo_hasta_uf = :hasta');
        parameters['hasta'] = (body['tramo_hasta_uf'] as num).toDouble();
      }
      if (body.containsKey('monto_periodo_1')) {
        updateFields.add('monto_periodo_1 = :montoP1');
        parameters['montoP1'] = (body['monto_periodo_1'] as num).toDouble();
      }
      if (body.containsKey('monto_periodo_2')) {
        updateFields.add('monto_periodo_2 = :montoP2');
        parameters['montoP2'] = (body['monto_periodo_2'] as num).toDouble();
      }
    }
    // (Aquí añadiríamos la lógica para las otras tablas de tramos)

    if (updateFields.isEmpty) {
      return Response(statusCode: 400, body: 'No hay campos para actualizar');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // Usamos el nombre de la tabla dinámicamente
    final query = 'UPDATE $tabla SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters);

    if(resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Tramo actualizado correctamente');
    } else {
      return Response(statusCode: 404, body: 'Tramo no encontrado');
    }

  } catch (e) {
    print('--- ¡ERROR EN PUT /api/tramos/$tramoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el tramo.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (BORRAR UN TRAMO) ---
Future<Response> _onDelete(RequestContext context, String tramoId, String tabla, Map<String, String> config) async {
  MySQLConnection? conn;
  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // Usamos el nombre de la tabla dinámicamente
    final resultado = await conn.execute(
      'DELETE FROM $tabla WHERE id = :id',
      {'id': int.parse(tramoId)},
    );

    if(resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Tramo eliminado correctamente');
    } else {
      return Response(statusCode: 404, body: 'Tramo no encontrado');
    }
  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/tramos/$tramoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al eliminar el tramo.');
  } finally {
    await conn?.close();
  }
}