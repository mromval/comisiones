// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/providers/auth_provider.dart';
import 'package:frontend_comisiones_v2/screens/admin/input_metrics_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/manage_concursos_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/manage_equipos_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/manage_perfiles_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/manage_users_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/manage_configuracion_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = (ref.watch(authProvider) as Authenticated).usuario;
    
    // Helper para saber si es admin
    final bool esAdmin = usuario.rol == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.indigo.shade700, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 400, 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, 
              children: [
                Text(
                  'Bienvenido, ${usuario.nombreCompleto}',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // --- 1. Botón Gestionar Ejecutivos (Visible para ambos) ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('Gestionar Ejecutivos'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManageUsersScreen(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18)
                  ),
                ),
                const SizedBox(height: 16),
                
                // --- 2. Botones SOLO ADMIN ---
                if (esAdmin) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_work),
                    label: const Text('Mantenedor de Equipos'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ManageEquiposScreen(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18)
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_ind),
                    label: const Text('Mantenedor de Perfiles'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ManagePerfilesScreen(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18)
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Mantenedor de Concursos'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ManageConcursosScreen(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18)
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Variables Globales'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ManageConfiguracionScreen(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18)
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- 3. Botón Métricas (Visible para ambos, TEXTO CAMBIADO) ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Ingresar Porcentaje de Recaudación'), // <-- CAMBIO DE GLOSA
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const InputMetricsScreen(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    padding: const EdgeInsets.all(20),
                    textStyle: const TextStyle(fontSize: 18)
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}