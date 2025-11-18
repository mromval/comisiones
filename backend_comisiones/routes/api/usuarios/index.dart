// routes/api/usuarios/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:bcrypt/bcrypt.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL
  final jwtPayload = context.read<Map<String, dynamic>>();
  
  // --- CORRECCIÓN CLAVE: Sanitizamos el rol (minúsculas y sin espacios) ---
  final rol = (jwtPayload['rol'] as String).trim().toLowerCase(); 

  // ¡OJO! Un ejecutivo no puede hacer NADA en esta ruta
  if (rol == 'ejecutivo') {
    return Response(
      statusCode: HttpStatus.forbidden,
      body: 'Acceso denegado.',
    );
  }

  // 2. Usamos un SWITCH para manejar GET y POST
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context, jwtPayload, rol); // Pasamos el rol limpio
    case HttpMethod.post:
      // Solo un admin puede crear usuarios
      if (rol != 'admin') {
         return Response(statusCode: HttpStatus.forbidden, body: 'Acceso denegado: Solo administradores.');
      }
      return _onPost(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- FUNCIÓN GET (MEJORADA) ---
Future<Response> _onGet(RequestContext context, Map<String, dynamic> jwtPayload, String rol) async {
  
  final config = context.read<Map<String, String>>();
  final miId = int.parse(jwtPayload['id'] as String); 
  
  print('--- DEBUG USUARIOS GET ---');
  print('Usuario ID: $miId');
  print('Rol Detectado: "$rol"'); // Veremos esto en la consola para confirmar

  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    String query;
    Map<String, dynamic> parameters = {};

    // --- LÓGICA DE PERMISOS ROBUSTA ---
    if (rol == 'admin') {
      
      print('-> Ejecutando consulta de ADMIN (Ver todo)');
      query = '''
        SELECT 
          u.id, u.email, u.nombre_completo, u.rol, u.esta_activo,
          p.nombre_perfil, 
          e.nombre_equipo
        FROM Usuarios u
        LEFT JOIN Perfiles p ON u.perfil_id = p.id
        LEFT JOIN Equipos e ON u.equipo_id = e.id
        WHERE u.esta_activo = 1
        ORDER BY u.nombre_completo;
      ''';

    } else { 
      // Si NO es admin (es decir, es supervisor)
      print('-> Ejecutando consulta de SUPERVISOR (Ver solo equipo)');
      
      // Usamos una SUBCONSULTA: "Traeme usuarios cuyo equipo tenga como jefe a MI ID"
      // Esto es más seguro que el JOIN anterior.
      query = '''
        SELECT 
          u.id, u.email, u.nombre_completo, u.rol, u.esta_activo,
          p.nombre_perfil, 
          e.nombre_equipo
        FROM Usuarios u
        LEFT JOIN Perfiles p ON u.perfil_id = p.id
        LEFT JOIN Equipos e ON u.equipo_id = e.id
        WHERE 
          u.esta_activo = 1 
          AND u.equipo_id IN (SELECT id FROM Equipos WHERE supervisor_id = :miId)
        ORDER BY u.nombre_completo;
      ''';
      parameters['miId'] = miId;
    }

    final resultado = await conn.execute(query, parameters);

    final usuarios = resultado.rows.map((row) {
      final data = row.assoc();
      data['nombre_equipo'] = data['nombre_equipo'] ?? 'Sin asignar';
      return data;
    }).toList();

    return Response.json(body: usuarios);

  } catch (e) {
    print('--- ¡ERROR EN GET /api/usuarios! ---');
    print(e.toString());
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar usuarios.');
  } finally {
    await conn?.close();
  }
}


// --- FUNCIÓN POST (Sin cambios) ---
Future<Response> _onPost(RequestContext context) async {
  final config = context.read<Map<String, String>>();
  MySQLConnection? conn;
  String? email;

  try {
    final payload = await context.request.body();
    final body = jsonDecode(payload) as Map<String, dynamic>;
    
    email = body['email'] as String?;
    final password = body['password'] as String?;
    final nombre = body['nombre_completo'] as String?;
    final rol = body['rol'] as String?;
    final perfilId = body['perfil_id'] as int?;
    final equipoId = body['equipo_id'] as int?;

    if (email == null || password == null || nombre == null || rol == null) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: 'Faltan campos obligatorios',
      );
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    await conn.execute(
      '''
      INSERT INTO Usuarios (email, password_hash, nombre_completo, rol, perfil_id, equipo_id)
      VALUES (:email, :hash, :nombre, :rol, :perfilId, :equipoId)
      ''',
      {
        'email': email,
        'hash': passwordHash,
        'nombre': nombre,
        'rol': rol,
        'perfilId': perfilId,
        'equipoId': equipoId,
      },
    );

    return Response(statusCode: HttpStatus.created, body: 'Usuario creado exitosamente');

  } catch (e) {
    print('--- ¡ERROR EN POST /api/usuarios! ---');
    print(e.toString());
    if (e.toString().contains('email_unico')) {
       return Response(
        statusCode: HttpStatus.conflict,
        body: 'El email $email ya existe.',
      );
    }
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el usuario.');
  } finally {
    await conn?.close();
  }
}