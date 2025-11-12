// routes/api/concursos/[id]/tramos.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'id' en la URL es el ID del CONCURSO
Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  
  // Usamos el ID del concurso para todas las operaciones
  final concursoId = int.parse(id);
  
  switch (context.request.method) {
    case HttpMethod.get:
      // GET (Leer tramos) está permitido para todos los roles logueados
      return _onGet(context, concursoId);
      
    case HttpMethod.post:
      // POST (Crear tramo) solo para admin/supervisor
      if (rol != 'admin' && rol != 'supervisor') {
        return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
      }
      return _onPost(context, concursoId);
      
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (LISTAR TRAMOS DE ESTE CONCURSO) ---
Future<Response> _onGet(RequestContext context, int concursoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // Buscamos todos los tramos que pertenecen a este ID de concurso
    final resultado = await conn.execute(
      '''
      SELECT id, regla_id, tramo_desde_uf, tramo_hasta_uf, monto_pago
      FROM Reglas_Tramos
      WHERE regla_id = :concursoId
      ORDER BY tramo_desde_uf ASC;
      ''',
      {'concursoId': concursoId},
    );

    final tramos = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: tramos);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/concursos/$concursoId/tramos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar tramos.');
  } finally {
    await conn?.close();
  }
}


// --- FUNCIÓN POST (CREAR UN NUEVO TRAMO PARA ESTE CONCURSO) ---
Future<Response> _onPost(RequestContext context, int concursoId) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    // ¡AHORA BUSCAMOS 'monto_pago'!
    final desdeUF = (body['tramo_desde_uf'] as num?)?.toDouble();
    final hastaUF = (body['tramo_hasta_uf'] as num?)?.toDouble();
    final monto = (body['monto_pago'] as num?)?.toDouble(); // <-- Lógica corregida

    if (desdeUF == null || hastaUF == null || monto == null) {
      return Response(statusCode: HttpStatus.badRequest, body: 'Faltan campos obligatorios: tramo_desde_uf, tramo_hasta_uf, monto_pago.');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    await conn.execute(
      '''
      INSERT INTO Reglas_Tramos
        (regla_id, tramo_desde_uf, tramo_hasta_uf, monto_pago)
      VALUES
        (:reglaId, :desde, :hasta, :monto)
      ''',
      {
        'reglaId': concursoId,
        'desde': desdeUF,
        'hasta': hastaUF,
        'monto': monto,
      },
    );

    return Response(statusCode: HttpStatus.created, body: 'Tramo creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/concursos/$concursoId/tramos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el tramo.');
  } finally {
    await conn?.close();
  }
}