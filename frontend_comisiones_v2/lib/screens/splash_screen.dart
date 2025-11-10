// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend_comisiones_v2/main.dart'; // Importamos main.dart para poder navegar al AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // Inicia un temporizador de 3 segundos
    Timer(const Duration(seconds: 10), () {
      // Cuando el tiempo se acaba, reemplaza esta pantalla
      // por el AuthWrapper
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el mismo fondo degradado que en el resto de la app
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Texto de Bienvenida
              Text(
                'Simulador de Renta',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.deepPurple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),

              // Tu Logo CasaIoT
              // Asegúrate de que la ruta 'assets/logo_casaiot.png' sea correcta
              Image.asset(
                'assets/logo_casaiot.png',
                height: 220, // Ajusta el tamaño como prefieras
              ),
              const SizedBox(height: 24),
              
              // Glosa
              Text(
                'Creado orgullosamente en Chile 🇨🇱 por',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'www.casaiot.cl',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),

              // --- INICIO DE LA MODIFICACIÓN ---
              const SizedBox(height: 8),
              // 1. Nueva glosa de RomVal
              Text(
                'Una Empresa del grupo RomVal SpA',
                style: TextStyle(
                  fontSize: 16, // Más pequeño
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24), // Espacio antes del logo
              
              // 2. Logo de RomVal
              // Asegúrate de que la ruta 'assets/logo_romval.png' sea correcta
              Image.asset(
                'assets/logo_romval.png', // Ruta al nuevo logo
                height: 120, // "en pequeño"
              ),
              // --- FIN DE LA MODIFICACIÓN ---
            ],
          ),
        ),
      ),
    );
  }
}