// routes/api/usuarios/index.dart
import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:bcrypt/bcrypt.dart';

Future<Response> onRequest(RequestContext context) async {
  
  // 1. Verificamos el ROL (Middleware ya lo hizo)
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;

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
      // Pasamos el payload completo porque necesitaremos el ID del supervisor
      return _onGet(context, jwtPayload); 
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

// --- FUNCIÓN GET (MODIFICADA CON LÓGICA DE ROLES) ---
Future<Response> _onGet(RequestContext context, Map<String, dynamic> jwtPayload) async {
  
  final config = context.read<Map<String, String>>();
  final rol = jwtPayload['rol'] as String;
  final miId = int.parse(jwtPayload['id'] as String); // El ID del usuario que hace la petición
  
  MySQLConnection? conn;

  try {
    conn = await MySQLConnection.createConnection(
      host: config['DB_HOST']!, port: int.parse(config['DB_PORT']!),
      userName: config['DB_USER']!, password: config['DB_PASS']!,
      databaseName: config['DB_NAME']!,
    );
    await conn.connect();

    String query;
    Map<String, dynamic> parameters;

    // --- ¡INICIO DE LA LÓGICA DE PERMISOS! ---
    if (rol == 'admin') {
      
      // 1. Si es ADMIN, trae a TODOS (la consulta que ya teníamos)
      print('Permiso: ADMIN. Obteniendo todos los usuarios.');
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
      parameters = {};

    } else { // Si es 'supervisor'

      // 2. Si es SUPERVISOR, busca solo los usuarios DE SU EQUIPO
      print('Permiso: SUPERVISOR. Obteniendo solo su equipo.');
      query = '''
        SELECT 
          u.id, u.email, u.nombre_completo, u.rol, u.esta_activo,
          p.nombre_perfil, 
          e.nombre_equipo
        FROM Usuarios u
        LEFT JOIN Perfiles p ON u.perfil_id = p.id
        LEFT JOIN Equipos e ON u.equipo_id = e.id
        -- Hacemos un JOIN con Equipos OTRA VEZ para encontrar el equipo del supervisor
        JOIN Equipos e_supervisor ON e_supervisor.supervisor_id = :miId
        -- El WHERE filtra que el equipo del usuario sea el mismo que supervisa
        WHERE u.equipo_id = e_supervisor.id AND u.esta_activo = 1
        ORDER BY u.nombre_completo;
      ''';
      parameters = {'miId': miId};
    }
    // --- FIN DE LA LÓGICA DE PERMISOS ---

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
    print("----------------------------------");
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al consultar usuarios.');
  } finally {
    await conn?.close();
  }
}


// --- FUNCIÓN POST (Sin cambios, pero con la restricción de admin arriba) ---
Future<Response> _onPost(RequestContext context) async {
  // ... (El código de _onPost que ya teníamos es idéntico) ...
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
        body: 'Faltan campos obligatorios (email, password, nombre_completo, rol)',
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
        statusCode: HttpStatus.conflict, // 409
        body: 'El email $email ya existe.',
      );
    }
    
    print("---------------------------------");
    return Response(statusCode: HttpStatus.internalServerError, body: 'Error al crear el usuario.');
  } finally {
    await conn?.close();
  }
}