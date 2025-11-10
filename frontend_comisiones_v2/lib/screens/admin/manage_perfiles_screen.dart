// lib/screens/admin/manage_perfiles_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class ManagePerfilesScreen extends ConsumerWidget {
  const ManagePerfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observamos el nuevo provider
    final asyncPerfiles = ref.watch(profileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenedor de Perfiles'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(profileListProvider.future);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.indigo.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: asyncPerfiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error al cargar perfiles: $err'),
              ),
            ),
            data: (perfiles) {
              if (perfiles.isEmpty) {
                return const Center(child: Text('No se encontraron perfiles.'));
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
                        itemCount: perfiles.length,
                        itemBuilder: (context, index) {
                          final profile = perfiles[index];
                          return ProfileListCard(profile: profile);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Botón '+' para CREAR un nuevo perfil
          _showProfileDialog(context, ref);
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Tarjeta para la lista de Perfiles ---
class ProfileListCard extends ConsumerWidget {
  final AdminProfile profile;
  const ProfileListCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // Mostramos el número de orden
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(
            profile.ordenSorteo.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
          ),
        ),
        title: Text(profile.nombrePerfil, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              // Botón EDITAR
              _showProfileDialog(context, ref, profileToEdit: profile);
            } else if (value == 'delete') {
              // Botón ELIMINAR
              _showDeleteConfirmation(context, ref, profile);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: ListTile(leading: Icon(Icons.edit), title: Text('Editar')),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete), title: Text('Eliminar')),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Diálogo para CREAR o EDITAR un perfil ---
void _showProfileDialog(BuildContext context, WidgetRef ref, {AdminProfile? profileToEdit}) {
  
  final _nameController = TextEditingController(text: profileToEdit?.nombrePerfil ?? '');
  final _orderController = TextEditingController(text: profileToEdit?.ordenSorteo.toString() ?? '99');
  final formKey = GlobalKey<FormState>();
  
  final bool isEditing = profileToEdit != null;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(isEditing ? 'Editar Perfil' : 'Crear Nuevo Perfil'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Perfil'),
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                decoration: const InputDecoration(labelText: 'Número de Orden'),
                keyboardType: TextInputType.number,
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
            child: Text(isEditing ? 'Guardar Cambios' : 'Crear'),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final data = {
                  'nombre_perfil': _nameController.text,
                  'orden_sorteo': int.parse(_orderController.text),
                };
                
                try {
                  if (isEditing) {
                    await ref.read(profileListProvider.notifier).updateProfile(profileToEdit.id, data);
                  } else {
                    await ref.read(profileListProvider.notifier).addProfile(data);
                  }
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

// --- Diálogo de Confirmación de Borrado ---
void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AdminProfile profile) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar Perfil?'),
      content: Text('¿Estás seguro de que deseas eliminar "${profile.nombrePerfil}"? Esta acción puede fallar si el perfil está en uso por un usuario o un concurso.'),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sí, Eliminar'),
          onPressed: () async {
            try {
              await ref.read(profileListProvider.notifier).removeProfile(profile.id);
              if(context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if(context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      ],
    ),
  );
}