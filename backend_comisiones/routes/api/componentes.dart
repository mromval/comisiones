import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Solo método GET
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. Verificamos el ROL (admin/supervisor)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin' && rol != 'supervisor') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado.');
  }

  // 3. Leemos la configuración de la BD
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // 4. Consultamos la tabla de Componentes
    final resultado = await conn.execute('SELECT id, nombre_componente, clave_logica FROM Componentes_Renta');

    final componentes = resultado.rows.map((row) => row.assoc()).toList();
    return Response.json(body: componentes);

  } catch (e) {
    print('--- ¡ERROR EN /api/componentes! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar componentes.');
  } finally {
    await conn?.close();
  }
}