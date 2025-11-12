// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/providers/auth_provider.dart';
import 'package:frontend_comisiones_v2/screens/home_screen.dart';
import 'package:frontend_comisiones_v2/screens/login_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/admin_dashboard_screen.dart';
// 1. IMPORTAMOS LA NUEVA PANTALLA SPLASH (LA DE LOS LOGOS)
import 'package:frontend_comisiones_v2/screens/splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora de Comisiones',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      // 2. LE DECIMOS A LA APP QUE ARRANQUE EN LA NUEVA PANTALLA SPLASH
      home: const SplashScreen(), 
    );
  }
}

// 3. ESTE WIDGET ES EL ENRUTADOR PRINCIPAL
// (La SplashScreen navegará aquí después de 3 segundos)
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // --- ¡ESTE ES EL SWITCH MODIFICADO! ---
    return switch (authState) {
      
      Authenticated(usuario: final usuario) => 
        (usuario.rol == 'supervisor' || usuario.rol == 'admin')
          ? const AdminDashboardScreen() 
          : const HomeScreen(),

      // Mantenemos la LoginScreen viva durante Carga y Error
      // para que pueda mostrar sus propios indicadores.
      Unauthenticated() => const LoginScreen(),
      AuthError() => const LoginScreen(), 
      AuthLoading() => const LoginScreen(),
    };
  }
}