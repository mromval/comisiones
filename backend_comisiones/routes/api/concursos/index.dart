// routes/api/concursos/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;

  switch (context.request.method) {
    case HttpMethod.get:
      // GET está permitido para todos los roles logueados (incluido ejecutivo)
      return _onGet(context);
      
    case HttpMethod.post:
      // POST (crear) solo para admin/supervisor
      if (rol != 'admin' && rol != 'supervisor') {
        return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado: Solo admin/supervisor pueden crear.');
      }
      return _onPost(context);
      
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (ACTUALIZADA) ---
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

    // --- ¡MODIFICACIÓN! ---
    // Seleccionamos las nuevas columnas de requisitos
    final resultado = await conn.execute('''
      SELECT 
        rc.id, 
        rc.periodo_inicio, 
        rc.periodo_fin, 
        rc.esta_activa,
        rc.requisito_min_uf_total,
        rc.requisito_tasa_recaudacion,
        rc.requisito_min_contratos,
        rc.tope_monto,
        p.nombre_perfil, 
        cr.nombre_componente,
        cr.clave_logica
      FROM Reglas_Concurso rc
      JOIN Perfiles p ON rc.perfil_id = p.id
      JOIN Componentes_Renta cr ON rc.componente_id = cr.id
      ORDER BY rc.periodo_inicio DESC;
    ''');
    // --- FIN DE MODIFICACIÓN ---

    final concursos = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: concursos);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/concursos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar concursos.');
  } finally {
    await conn?.close();
  }
}


// --- FUNCIÓN POST (ACTUALIZADA) ---
Future<Response> _onPost(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    // Campos obligatorios
    final perfilId = body['perfil_id'] as int?;
    final componenteId = body['componente_id'] as int?;
    final periodoInicio = body['periodo_inicio'] as String?;
    final periodoFin = body['periodo_fin'] as String?;

    // --- ¡MODIFICACIÓN! ---
    // Campos de requisitos (opcionales, pueden ser null)
    final minUf = (body['requisito_min_uf_total'] as num?)?.toDouble();
    final tasaRecaudacion = (body['requisito_tasa_recaudacion'] as num?)?.toDouble();
    final minContratos = body['requisito_min_contratos'] as int?;
    final topeMonto = (body['tope_monto'] as num?)?.toDouble();
    // --- FIN DE MODIFICACIÓN ---

    if (perfilId == null || componenteId == null || periodoInicio == null || periodoFin == null) {
      return Response(statusCode: HttpStatus.badRequest, body: 'Faltan campos obligatorios.');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // --- ¡MODIFICACIÓN! ---
    // Añadimos las nuevas columnas al INSERT
    await conn.execute(
      '''
      INSERT INTO Reglas_Concurso (
        perfil_id, componente_id, periodo_inicio, periodo_fin,
        requisito_min_uf_total, requisito_tasa_recaudacion, 
        requisito_min_contratos, tope_monto
      )
      VALUES (
        :perfilId, :componenteId, :inicio, :fin,
        :minUf, :tasa, :minContratos, :tope
      )
      ''',
      {
        'perfilId': perfilId,
        'componenteId': componenteId,
        'inicio': periodoInicio,
        'fin': periodoFin,
        'minUf': minUf,
        'tasa': tasaRecaudacion,
        'minContratos': minContratos,
        'tope': topeMonto,
      },
    );
    // --- FIN DE MODIFICACIÓN ---

    return Response(statusCode: HttpStatus.created, body: 'Concurso creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/concursos! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el concurso.');
  } finally {
    await conn?.close();
  }
}