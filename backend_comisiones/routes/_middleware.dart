import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_cors/dart_frog_cors.dart'; // <-- El import
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

  // 2. Provee la config Y APLICA EL CORS (LA FORMA CORRECTA)
  return handler
      .use(provider<Map<String, String>>((_) => _config!)) // Provee la config
      .use(cors( // <-- ¡ESTE ES EL COMANDO CORRECTO!
          
          // Permitimos cualquier origen, header y método para desarrollo
          // Esto solucionará el error 100%
          allowOrigin: '*', 
          allowHeaders: '*',
          allowMethods: '*',

          // NOTA: Para producción, seríamos más estrictos, ej:
          // allowOrigin: 'http://tu-dominio-frontend.com',
        ));
}