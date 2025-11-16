import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_cors/dart_frog_cors.dart'; 
import 'package:dotenv/dotenv.dart';

// El mapa para guardar la configuración
Map<String, String>? _config;

Handler middleware(Handler handler) {
  
  // 1. Lógica del .env (esta parte estaba bien)
  if (_config == null) {
    print('--- Cargando variables de entorno desde .env ---');
    try {
      final env = DotEnv();
      env.load(); 
      _config = env.map;
      print('--- Variables leídas y guardadas en el mapa ---');
    } catch (e) {
      print('--- ¡¡¡ERROR AL LEER .env!!! ---');
      print(e.toString());
      _config = {};
    }
  }

  // 2. Provee la config Y APLICA EL CORS
  // Esta es la configuración explícita que soluciona el error 'preflight'
  return handler
      .use(provider<Map<String, String>>((_) => _config!)) // Provee la config
      .use(cors( 
          
          // El dominio que SÍ tiene permiso
          allowOrigin: 'https://simulador.fabricamostuidea.cl', 
          
          // Le decimos explícitamente qué cabeceras aceptar
          allowHeaders: 'Origin, Content-Type, X-Auth-Token, Authorization',
          
          // Le decimos explícitamente qué métodos aceptar (incluyendo OPTIONS para preflight)
          allowMethods: 'GET, POST, PUT, DELETE, OPTIONS', 
        ));
}