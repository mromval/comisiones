// Este middleware protegerá TODAS las rutas dentro de /api/
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Handler middleware(Handler handler) {
  return (context) async {
    
    // 1. Leemos el token del header 'Authorization: Bearer <token>'
    final authHeader = context.request.headers[HttpHeaders.authorizationHeader];
    String? token;

    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7); // Extrae el token
    }

    if (token == null) {
      // Si no hay token, no autorizado
      return Response(statusCode: HttpStatus.unauthorized, body: 'No autorizado: Token no provisto');
    }

    // 2. Leemos el secreto (que el middleware raíz ya cargó)
    final config = context.read<Map<String, String>>();
    final jwtSecret = config['JWT_SECRET']!;

    try {
      // 3. Verificamos el token
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      final payload = jwt.payload as Map<String, dynamic>;

      // 4. ¡ÉXITO! "Inyectamos" los datos del usuario en el contexto
      // para que /api/calcular sepa QUIÉN está llamando.
      final response = await handler(
        context.provide<Map<String, dynamic>>(() => payload),
      );
      return response;

    } on JWTExpiredException {
      return Response(statusCode: HttpStatus.unauthorized, body: 'No autorizado: Token expirado');
    } on JWTException catch (e) {
      return Response(statusCode: HttpStatus.unauthorized, body: 'No autorizado: Token inválido (${e.message})');
    } catch (e) {
       // ¡Mejora de depuración!
        print('--- ¡ERROR EN EL MIDDLEWARE DE API (/api/_middleware.dart)! ---');
        print(e.toString());
        print('------------------------------------------------------------');
        return Response(statusCode: HttpStatus.internalServerError, body: 'Error interno (Revisa la terminal)');
    }  };
}