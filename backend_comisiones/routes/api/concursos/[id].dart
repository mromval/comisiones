// routes/api/concursos/[id].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context, id);
    case HttpMethod.put:
      return _onPut(context, id);
    case HttpMethod.delete:
      return _onDelete(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (ACTUALIZADA) ---
Future<Response> _onGet(RequestContext context, String concursoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;
  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // --- ¡MODIFICACIÓN! ---
    // Seleccionamos todo para que la pantalla de edición
    // pueda leer los requisitos actuales.
    final resultado = await conn.execute(
      'SELECT * FROM Reglas_Concurso WHERE id = :id', 
      {'id': int.parse(concursoId)}
    );
    // --- FIN DE MODIFICACIÓN ---

    if (resultado.rows.isEmpty) {
      return Response(statusCode: 404, body: 'Concurso no encontrado');
    }
    return Response.json(body: resultado.rows.first.assoc());
  } catch (e) {
    return Response(statusCode: 500, body: 'Error al consultar concurso.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN PUT (¡ACTUALIZADA!) ---
Future<Response> _onPut(RequestContext context, String concursoId) async {
  final config = context.read<Map<String, String>>();
  final payload = await context.request.body();
  final body = jsonDecode(payload) as Map<String, dynamic>;
  MySQLConnection? conn;

  final updateFields = <String>[];
  final parameters = <String, dynamic>{'id': int.parse(concursoId)};

  // --- ¡INICIO DE LA MODIFICACIÓN! ---
  // Añadimos la lógica para todos los campos nuevos
  if (body.containsKey('esta_activa')) {
    updateFields.add('esta_activa = :estaActiva');
    parameters['estaActiva'] = (body['esta_activa'] as bool) ? 1 : 0;
  }
  if (body.containsKey('periodo_inicio')) {
    updateFields.add('periodo_inicio = :inicio');
    parameters['inicio'] = body['periodo_inicio'];
  }
  if (body.containsKey('periodo_fin')) {
    updateFields.add('periodo_fin = :fin');
    parameters['fin'] = body['periodo_fin'];
  }
  if (body.containsKey('requisito_min_uf_total')) {
    updateFields.add('requisito_min_uf_total = :minUf');
    parameters['minUf'] = (body['requisito_min_uf_total'] as num?)?.toDouble();
  }
  if (body.containsKey('requisito_tasa_recaudacion')) {
    updateFields.add('requisito_tasa_recaudacion = :tasa');
    parameters['tasa'] = (body['requisito_tasa_recaudacion'] as num?)?.toDouble();
  }
  if (body.containsKey('requisito_min_contratos')) {
    updateFields.add('requisito_min_contratos = :minContratos');
    parameters['minContratos'] = body['requisito_min_contratos'] as int?;
  }
  if (body.containsKey('tope_monto')) {
    updateFields.add('tope_monto = :tope');
    parameters['tope'] = (body['tope_monto'] as num?)?.toDouble();
  }
  // --- FIN DE LA MODIFICACIÓN ---

  if (updateFields.isEmpty) {
    return Response(statusCode: 400, body: 'No hay campos para actualizar');
  }

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    final query = 'UPDATE Reglas_Concurso SET ${updateFields.join(', ')} WHERE id = :id';
    final resultado = await conn.execute(query, parameters); 
    
    if (resultado.affectedRows > BigInt.zero) {
       return Response(body: 'Concurso actualizado correctamente');
    } else {
      return Response(statusCode: 404, body: 'Error: Concurso no encontrado');
    }

  } catch (e) {
    print('--- ¡ERROR EN PUT /api/concursos/$concursoId! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar el concurso.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN DELETE (Sin cambios) ---
Future<Response> _onDelete(RequestContext context, String concursoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;
  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    final resultado = await conn.execute( // Capturamos resultado
      'DELETE FROM Reglas_Concurso WHERE id = :id', 
      {'id': int.parse(concursoId)}
    );
    
    // Verificamos si se borró
    if (resultado.affectedRows > BigInt.zero) {
       return Response(body: 'Concurso eliminado correctamente');
    } else {
       return Response(statusCode: 404, body: 'Error: Concurso no encontrado');
    }

  } catch (e) {
    print('--- ¡ERROR EN DELETE /api/concursos/$concursoId! ---');
    print(e.toString());
    if (e.toString().contains('FOREIGN KEY')) {
      return Response(statusCode: 500, body: 'Error: No se puede eliminar porque está en uso.');
    }
    return Response(statusCode: 500, body: 'Error al eliminar el concurso.');
  } finally {
    await conn?.close();
  }
}