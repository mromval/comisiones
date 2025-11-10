// routes/api/configuracion/[llave].dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

// El 'llave' en la URL es la 'llave' de la tabla (Ej: SUELDO_BASE)
Future<Response> onRequest(RequestContext context, String llave) async {
  
  // 1. Verificamos el ROL (¡Solo ADMIN puede editar!)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin') {
    return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado. Solo admin.');
  }

  // 2. Solo método PUT
  if (context.request.method != HttpMethod.put) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;

  try {
    // 3. Leer el body (Ej: {"valor": "530000"})
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    final valor = body['valor'] as String?;

    if (valor == null) {
      return Response(statusCode: 400, body: 'Falta el campo "valor" en el body.');
    }

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    // 4. Ejecutar el UPDATE
    final resultado = await conn.execute(
      'UPDATE Configuracion SET valor = :valor WHERE llave = :llave',
      {
        'valor': valor,
        'llave': llave,
      },
    );

    if (resultado.affectedRows > BigInt.zero) {
      return Response(body: 'Configuración actualizada correctamente');
    } else {
      return Response(
        statusCode: HttpStatus.notFound,
        body: 'Error: No se encontró una configuración con la llave "$llave".'
      );
    }
  } catch (e) {
    print('--- ¡ERROR EN PUT /api/configuracion/$llave! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al actualizar.');
  } finally {
    await conn?.close();
  }
}