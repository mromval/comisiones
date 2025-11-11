// lib/screens/admin/input_metrics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class InputMetricsScreen extends ConsumerWidget {
  const InputMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observamos la lista de usuarios (que ya está filtrada por rol)
    final asyncUsers = ref.watch(userListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar Métricas Mensuales'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: asyncUsers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error al cargar usuarios: $err'),
            ),
          ),
          data: (users) {
            // 2. Filtramos solo los ejecutivos (un admin/supervisor no se ingresa métricas a sí mismo)
            final ejecutivos = users.where((u) => u.rol == 'ejecutivo').toList();

            if (ejecutivos.isEmpty) {
              return const Center(child: Text('No se encontraron ejecutivos.'));
            }
            
            // 3. Mostramos la lista centrada (como en las otras pantallas)
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: ejecutivos.length,
                      itemBuilder: (context, index) {
                        final user = ejecutivos[index];
                        // 4. Usamos un Card reutilizable
                        return MetricaUserCard(user: user);
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- Widget para la tarjeta de cada Ejecutivo ---
class MetricaUserCard extends ConsumerStatefulWidget {
  final AdminUser user;
  const MetricaUserCard({super.key, required this.user});

  @override
  ConsumerState<MetricaUserCard> createState() => _MetricaUserCardState();
}

class _MetricaUserCardState extends ConsumerState<MetricaUserCard> {
  final _tasaController = TextEditingController();
  // (Aquí podrías añadir más controladores para otras métricas, ej: _diasTrabajadosController)

  Future<void> _onSave() async {
    final apiClient = ref.read(adminApiClientProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // 1. Validar que el campo no esté vacío
    final double? valorTasa = double.tryParse(_tasaController.text);
    if (valorTasa == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Valor inválido. Ingresa solo números (ej: 85.5)'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 2. Poner estado de "cargando"
    ref.read(metricSaveLoadingProvider.notifier).state = true;

    // 3. Formatear la fecha del período (primer día del mes actual)
    final now = DateTime.now();
    final periodo = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";

    try {
      // 4. Preparar y enviar los datos
      final data = {
        'usuario_id': widget.user.id,
        'nombre_metrica': 'tasa_recaudacion', // ¡Clave importante!
        'valor': valorTasa,
        'periodo': periodo,
      };
      await apiClient.saveMetrica(data);
      
      // (Opcional: aquí podrías guardar otras métricas si tuvieras más campos)

      scaffoldMessenger.showSnackBar(
         SnackBar(content: Text('Tasa guardada para ${widget.user.nombreCompleto}'), backgroundColor: Colors.green),
      );

    } catch (e) {
      scaffoldMessenger.showSnackBar(
         SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      // 5. Quitar estado de "cargando"
      // Usamos un post-frame callback para evitar errores de 'setState' durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(metricSaveLoadingProvider.notifier).state = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _tasaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el provider de carga
    final isLoading = ref.watch(metricSaveLoadingProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade50,
          child: Icon(Icons.person, color: Colors.deepPurple.shade700),
        ),
        title: Text(widget.user.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(widget.user.email),
        trailing: SizedBox(
          width: 200, // Ancho fijo para el campo y el botón
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Campo para la Tasa
              Expanded(
                child: TextField(
                  controller: _tasaController,
                  decoration: InputDecoration(
                    labelText: 'Tasa %',
                    hintText: '85.0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              // Botón de Guardar
              isLoading
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 3)
                  )
                : IconButton(
                    icon: const Icon(Icons.save, color: Colors.indigo),
                    tooltip: 'Guardar Tasa',
                    onPressed: _onSave,
                  )
            ],
          ),
        ),
      ),
    );
  }
}