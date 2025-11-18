// backend_comisiones/routes/api/usuarios/importar.dart
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:csv/csv.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Verificar Rol
  final jwtPayload = context.read<Map<String, dynamic>>();
  final rol = jwtPayload['rol'] as String;
  if (rol != 'admin') {
    // CORRECCIÓN: Devolver JSON
    return Response.json(
      statusCode: HttpStatus.forbidden,
      body: {'message': 'Acceso denegado: Solo administradores.'},
    );
  }

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

  try {
    conn = await MySQLConnection.createConnection(
      host: host, port: port, userName: user, password: pass, databaseName: dbName,
    );
    await conn.connect();

    final profileMap = await _getProfileMap(conn);
    final teamMap = await _getTeamMap(conn);

    final csvData = await context.request.body();
    if (csvData.isEmpty) {
      // CORRECCIÓN: Devolver JSON
      return Response.json(
        statusCode: HttpStatus.badRequest, 
        body: {'message': 'El archivo enviado está vacío.'}
      );
    }

    var usuariosCreados = 0;
    final List<String> erroresDetalle = [];

    // Usamos coma ',' como delimitador
    final List<List<dynamic>> csvRows =
        const CsvToListConverter(fieldDelimiter: ',').convert(csvData);

    if (csvRows.length <= 1) {
      // CORRECCIÓN: Devolver JSON
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': 'El archivo CSV no tiene filas de datos.'}
      );
    }

    // (El resto del bucle FOR se mantiene igual, la lógica es correcta)
    for (var i = 1; i < csvRows.length; i++) {
      final row = csvRows[i];
      final numeroFila = i + 1;

      if (row.length < 5) {
        erroresDetalle.add('Fila $numeroFila: Ignorada. No tiene las 5 columnas obligatorias.');
        continue;
      }

      final nombre = row[0].toString();
      final email = row[1].toString();
      final password = row[2].toString();
      final rol = row[3].toString().toLowerCase();
      final nombrePerfil = row[4].toString();
      final nombreEquipo = row.length > 5 ? row[5].toString() : null;

      if (nombre.isEmpty || email.isEmpty || password.isEmpty || rol.isEmpty || nombrePerfil.isEmpty) {
        erroresDetalle.add('Fila $numeroFila ($email): Faltan datos obligatorios.');
        continue;
      }

      if (rol != 'ejecutivo' && rol != 'supervisor' && rol != 'admin') {
        erroresDetalle.add('Fila $numeroFila ($email): Rol "$rol" inválido.');
        continue;
      }

      final int? perfilId = profileMap[nombrePerfil];
      if (perfilId == null) {
        erroresDetalle.add('Fila $numeroFila ($email): Perfil "$nombrePerfil" no existe.');
        continue;
      }

      int? equipoId;
      if (nombreEquipo != null && nombreEquipo.isNotEmpty) {
        equipoId = teamMap[nombreEquipo];
        if (equipoId == null) {
          erroresDetalle.add('Fila $numeroFila ($email): Equipo "$nombreEquipo" no existe.');
          continue;
        }
      }

      try {
        final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
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
        usuariosCreados++;
      } catch (e) {
        if (e.toString().contains('email_unico')) {
          erroresDetalle.add('Fila $numeroFila ($email): El email ya existe.');
        } else {
          erroresDetalle.add('Fila $numeroFila ($email): Error BD: ${e.toString()}');
        }
      }
    } 

    return Response.json(
      statusCode: HttpStatus.ok,
      body: {
        'usuariosCreados': usuariosCreados,
        'erroresEncontrados': erroresDetalle.length,
        'detalleErrores': erroresDetalle,
      },
    );

  } catch (e) {
    print('--- ¡ERROR EN IMPORTACIÓN! ---');
    print(e.toString());
    // CORRECCIÓN: Devolver JSON con el error técnico
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'message': 'Error interno: ${e.toString()}'}
    );
  } finally {
    await conn?.close();
  }
}

// (Helpers _getProfileMap y _getTeamMap se mantienen igual)
Future<Map<String, int>> _getProfileMap(MySQLConnection conn) async {
  final Map<String, int> map = {};
  final resultado = await conn.execute('SELECT id, nombre_perfil FROM Perfiles');
  for (final row in resultado.rows) {
    final data = row.assoc();
    map[data['nombre_perfil']!] = int.parse(data['id']!);
  }
  return map;
}

Future<Map<String, int>> _getTeamMap(MySQLConnection conn) async {
  final Map<String, int> map = {};
  final resultado = await conn.execute('SELECT id, nombre_equipo FROM Equipos');
  for (final row in resultado.rows) {
    final data = row.assoc();
    map[data['nombre_equipo']!] = int.parse(data['id']!);
  }
  return map;
}