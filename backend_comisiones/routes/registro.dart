import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';

import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart'; 

Future<Response> onRequest(RequestContext context) async {
  
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final config = context.read<Map<String, String>>();
  final host = config['DB_HOST']!;
  final port = int.parse(config['DB_PORT']!);
  final user = config['DB_USER']!;
  final pass = config['DB_PASS']!;
  final dbName = config['DB_NAME']!;

  MySQLConnection? conn;
  
  // --- INICIO DE LA CORRECCIÓN ---
  // Declaramos email aquí para que sea accesible en el catch
  String? email; 
  // --- FIN DE LA CORRECCIÓN ---

  try {
    final requestBody = await context.request.body();
    final jsonBody = jsonDecode(requestBody) as Map<String, dynamic>;

    // Asignamos valor a la variable (sin 'final')
    email = jsonBody['email'] as String?; 
    final password = jsonBody['password'] as String?;
    final nombre = jsonBody['nombre_completo'] as String?;
    final perfilId = jsonBody['perfil_id'] as int?;

    if (email == null || password == null || nombre == null || perfilId == null) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: 'Faltan datos (email, password, nombre_completo, perfil_id)',
      );
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    conn = await MySQLConnection.createConnection(
      host: host, port: port, userName: user, password: pass, databaseName: dbName,
    );
    await conn.connect();

    await conn.execute(
      '''
      INSERT INTO Usuarios 
        (email, password_hash, nombre_completo, perfil_id, rol)
      VALUES 
        (:email, :hash, :nombre, :perfil, :rol)
      ''',
      {
        'email': email,
        'hash': passwordHash,
        'nombre': nombre,
        'perfil': perfilId,
        'rol': 'ejecutivo',
      },
    );

    return Response.json(
      statusCode: HttpStatus.created, // 201
      body: {
        'mensaje': 'Usuario $email creado exitosamente.',
        'hash_generado': passwordHash,
      },
    );

  } catch (e) {
    print('--- ¡ERROR EN /registro! ---');
    print(e);
    print('--------------------------');
    
    // Ahora 'email' SÍ está disponible aquí
    if (e.toString().contains('email_unico')) {
       return Response(
        statusCode: HttpStatus.conflict, // 409
        body: 'El email ${email ?? "desconocido"} ya existe.', // Usamos '??' por si acaso
      );
    }
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Error interno del servidor.',
    );
  } finally {
    await conn?.close();
  }
}