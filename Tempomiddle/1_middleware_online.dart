import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_cors/dart_frog_cors.dart'; 
import 'package:dotenv/dotenv.dart';
import 'dart:io'; // <-- ¡IMPORTANTE AÑADIR ESTO!

Map<String, String>? _config;

Handler middleware(Handler handler) {
  
  if (_config == null) {
    print('--- Cargando variables de entorno ---');
    
    // --- INICIO DE LA CORRECCIÓN ---
    // 1. Leemos las variables del sistema (las que puso CasaOS)
    _config = Platform.environment; 
    
    // 2. (Opcional) Intentamos cargar .env como fallback para desarrollo local
    //    Si no lo encuentra, no pasa nada, ya tenemos las del sistema.
    try {
      final env = DotEnv();
      env.load();
      // Mezclamos, dando prioridad a las variables del .env si existen
      _config = {..._config!, ...env.map};
      print('--- Variables de .env (locales) añadidas ---');
    } catch (e) {
      print('--- No se encontró .env, usando solo variables del sistema (normal en producción) ---');
    }
    // --- FIN DE LA CORRECCIÓN ---

    if (_config!.isEmpty) {
       print('¡¡¡ALERTA: NO SE CARGÓ NINGUNA VARIABLE DE ENTORNO!!!');
    } else {
       print('--- Variables cargadas exitosamente ---');
       // Por seguridad, no imprimimos los valores en el log
       // print(_config); 
    }
  }

  // 2. Provee la config Y APLICA EL CORS
  return handler
      .use(provider<Map<String, String>>((_) => _config!)) // Provee la config
      .use(cors( 
          allowOrigin: '*', 
          allowHeaders: '*',
          allowMethods: '*', 
        ));
}