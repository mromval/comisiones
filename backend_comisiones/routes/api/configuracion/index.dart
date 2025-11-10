// routes/api/configuracion/index.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL (admin/supervisor pueden ver)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // 2. Solo método GET
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
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

    // 3. Hacemos el SELECT
    final resultado = await conn.execute(
      'SELECT llave, valor, descripcion FROM Configuracion ORDER BY llave ASC'
    );

    final configs = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: configs);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/configuracion! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar configuracion.');
  } finally {
    await conn?.close();
  }
}