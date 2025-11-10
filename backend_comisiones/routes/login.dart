// (En backend_comisiones/routes/login.dart)
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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
  final jwtSecret = config['JWT_SECRET']!; 

  MySQLConnection? conn;

  try {
    final requestBody = await context.request.body();
    final jsonBody = jsonDecode(requestBody) as Map<String, dynamic>;
    final email = jsonBody['email'] as String?;
    final password = jsonBody['password'] as String?;

    if (email == null || password == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': 'Falta email o password en el JSON'},
      );
    }

    conn = await MySQLConnection.createConnection(
      host: host, port: port, userName: user, password: pass, databaseName: dbName,
    );
    await conn.connect();

    final resultado = await conn.execute(
      'SELECT id, nombre_completo, email, password_hash, rol, perfil_id, equipo_id FROM Usuarios WHERE email = :email AND esta_activo = 1',
      {'email': email},
    );

    if (resultado.rows.isEmpty) {
      // --- ¡ARREGLO AQUÍ! ---
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'message': 'Email o contraseña incorrectos (o usuario inactivo)'},
      );
    }

    final usuario = resultado.rows.first.assoc();
    final passwordHash = usuario['password_hash']!;

    final esValida = BCrypt.checkpw(password, passwordHash);

    if (!esValida) {
      // --- ¡ARREGLO AQUÍ! ---
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'message': 'Email o contraseña incorrectos'},
      );
    }

    final payload = {
      'id': usuario['id'],
      'email': usuario['email'],
      'rol': usuario['rol'],
      'iat': DateTime.now().millisecondsSinceEpoch,
    };
    
    final jwt = JWT(payload);
    final token = jwt.sign(SecretKey(jwtSecret), expiresIn: Duration(hours: 8));

    return Response.json(body: {
      'token': token,
      'usuario': {
        'id': usuario['id'],
        'nombre_completo': usuario['nombre_completo'],
        'email': usuario['email'],
        'rol': usuario['rol'],
      }
    });

  } catch (e) {
    print('--- ¡ERROR EN /login! ---');
    print(e.toString());
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'message': 'Error interno del servidor.'},
    );
  } finally {
    await conn?.close();
  }
}