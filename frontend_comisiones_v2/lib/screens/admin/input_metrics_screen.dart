import 'package:flutter/material.dart';

class InputMetricsScreen extends StatelessWidget {
  const InputMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar Métricas'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Aquí el supervisor ingresará el % de fuga de su equipo (Próximamente)'),
      ),
    );
  }
}