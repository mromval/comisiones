import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'id' en la URL es el ID del CONCURSO
Future<Response> onRequest(RequestContext context, String id) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // Identificamos el tipo de concurso para saber a qué tabla de tramos llamar
  final config = context.read<Map<String, String>>();
  final conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
  await conn.connect();
  final reglaRes = await conn.execute(
    'SELECT cr.clave_logica FROM Reglas_Concurso rc JOIN Componentes_Renta cr ON rc.componente_id = cr.id WHERE rc.id = :id',
    {'id': int.parse(id)}
  );
  if(reglaRes.rows.isEmpty) {
    await conn.close();
    return Response(statusCode: 404, body: 'Concurso no encontrado');
  }
  
  final claveLogica = reglaRes.rows.first.assoc()['clave_logica'];
  await conn.close(); // Cerramos la conexión de chequeo

  // "Router" de lógica: Llama a la función correcta según la clave
  switch(claveLogica) {
    case 'TRAMO_UF':
      return _handleTramosUF(context, id, config);
    // Aquí añadiremos 'BONO_PYME', 'BONO_REFERIDOS'
    default:
      return Response(statusCode: 404, body: 'Mantenedor de tramos no implementado para este tipo de concurso.');
  }
}

// --- MANEJADOR ESPECIALIZADO PARA TRAMOS_UF ---
Future<Response> _handleTramosUF(RequestContext context, String concursoId, Map<String, String> config) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGetTramosUF(context, concursoId, config);
    case HttpMethod.post:
      return _onPostTramosUF(context, concursoId, config);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (LISTAR TRAMOS DE UF) ---
Future<Response> _onGetTramosUF(RequestContext context, String concursoId, Map<String, String> config) async {
  MySQLConnection? conn;
  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // CONSULTA A LA TABLA CORREGIDA
    final resultado = await conn.execute(
      '''
      SELECT id, regla_id, tramo_desde_uf, tramo_hasta_uf, monto_periodo_1, monto_periodo_2
      FROM Reglas_Tramos_UF
      WHERE regla_id = :concursoId
      ORDER BY tramo_desde_uf ASC;
      ''',
      {'concursoId': int.parse(concursoId)},
    );
    final tramos = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: tramos);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/concursos/$concursoId/tramos (UF)! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar tramos UF.');
  } finally {
    await conn?.close();
  }
}

// --- FUNCIÓN POST (CREAR UN NUEVO TRAMO DE UF) ---
Future<Response> _onPostTramosUF(RequestContext context, String concursoId, Map<String, String> config) async {
  MySQLConnection? conn;
  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    // Leemos los nuevos campos
    final desdeUF = (body['tramo_desde_uf'] as num?)?.toDouble();
    final hastaUF = (body['tramo_hasta_uf'] as num?)?.toDouble();
    final montoP1 = (body['monto_periodo_1'] as num?)?.toDouble();
    final montoP2 = (body['monto_periodo_2'] as num?)?.toDouble();

    if (desdeUF == null || hastaUF == null || montoP1 == null || montoP2 == null) {
      return Response(statusCode: HttpStatus.badRequest, body: 'Faltan campos obligatorios.');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();
    
    // INSERTAMOS EN LA TABLA CORREGIDA
    await conn.execute(
      '''
      INSERT INTO Reglas_Tramos_UF
        (regla_id, tramo_desde_uf, tramo_hasta_uf, monto_periodo_1, monto_periodo_2)
      VALUES
        (:reglaId, :desde, :hasta, :montoP1, :montoP2)
      ''',
      {
        'reglaId': int.parse(concursoId),
        'desde': desdeUF,
        'hasta': hastaUF,
        'montoP1': montoP1,
        'montoP2': montoP2,
      },
    );
    return Response(statusCode: HttpStatus.created, body: 'Tramo UF creado exitosamente');
  } catch (e) {
    print('--- ¡ERROR EN POST /api/concursos/$concursoId/tramos (UF)! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el tramo UF.');
  } finally {
    await conn?.close();
  }
}