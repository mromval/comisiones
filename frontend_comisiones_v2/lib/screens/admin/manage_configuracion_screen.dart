// lib/screens/admin/manage_configuracion_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class ManageConfiguracionScreen extends ConsumerWidget {
  const ManageConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observamos el nuevo provider
    final asyncConfig = ref.watch(configListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenedor de Variables'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(configListProvider.future);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.indigo.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: asyncConfig.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error al cargar variables: $err'),
              ),
            ),
            data: (configs) {
              if (configs.isEmpty) {
                return const Center(child: Text('No se encontraron variables de configuración.'));
              }
              // Mostramos la lista centrada
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
                        itemCount: configs.length,
                        itemBuilder: (context, index) {
                          final config = configs[index];
                          return ConfigListCard(config: config);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // No hay FloatingActionButton porque no permitimos crear nuevas llaves
    );
  }
}

// --- Tarjeta para la lista de Configuración ---
class ConfigListCard extends ConsumerWidget {
  final AdminConfig config;
  const ConfigListCard({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Icon(Icons.settings, color: Colors.indigo.shade700),
        ),
        title: Text(config.llave, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valor: ${config.valor}', 
              style: TextStyle(color: Colors.grey.shade900, fontSize: 15)
            ),
            Text(
              config.descripcion ?? 'Sin descripción', 
              style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.indigo),
          tooltip: 'Editar Valor',
          onPressed: () {
            // Botón EDITAR
            _showConfigDialog(context, ref, configToEdit: config);
          },
        ),
      ),
    );
  }
}

// --- Diálogo para EDITAR una variable ---
void _showConfigDialog(BuildContext context, WidgetRef ref, {required AdminConfig configToEdit}) {
  
  final _valorController = TextEditingController(text: configToEdit.valor);
  final formKey = GlobalKey<FormState>();
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Editar Variable: ${configToEdit.llave}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(configToEdit.descripcion ?? 'Editando el valor de esta variable.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(labelText: 'Nuevo Valor'),
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Guardar Cambios'),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final data = {
                  'valor': _valorController.text,
                };
                
                try {
                  await ref.read(configListProvider.notifier).updateConfig(configToEdit.llave, data);
                  if(context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  if(context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
        ],
      );
    },
  );
}