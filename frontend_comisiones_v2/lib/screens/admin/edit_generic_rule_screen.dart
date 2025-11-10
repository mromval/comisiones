// lib/screens/admin/edit_generic_rule_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';

class EditGenericRuleScreen extends StatelessWidget {
  final AdminConcurso concurso;
  const EditGenericRuleScreen({super.key, required this.concurso});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(concurso.nombreComponente),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mantenedor para: ${concurso.nombreComponente}',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Esta pantalla es un placeholder.\nAquí es donde construiríamos el formulario específico para las métricas de esta regla (ej. "Meta de Fuga").',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}