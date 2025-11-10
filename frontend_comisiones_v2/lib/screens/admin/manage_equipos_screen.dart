// lib/screens/admin/manage_equipos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class ManageEquiposScreen extends ConsumerWidget {
  const ManageEquiposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observamos AMBOS providers.
    // Esto es crucial para que la lista de supervisores
    // esté disponible para los diálogos.
    final asyncEquipos = ref.watch(teamListProvider);
    final asyncUsuarios = ref.watch(userListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenedor de Equipos'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Recargamos ambos
          ref.invalidate(teamListProvider);
          return ref.refresh(userListProvider.future);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.indigo.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          
          // Anidamos los .when() para asegurarnos de que AMBOS carguen
          child: asyncUsuarios.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error al cargar usuarios: $err')),
            data: (usuarios) {
              // Ahora que los usuarios cargaron, cargamos los equipos
              return asyncEquipos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error al cargar equipos: $err')),
                data: (equipos) {
                  
                  // Filtramos la lista de supervisores UNA VEZ
                  final List<AdminUser> supervisors = usuarios
                      .where((user) => user.rol == 'supervisor' || user.rol == 'admin')
                      .toList();

                  if (equipos.isEmpty) {
                    return const Center(child: Text('No se encontraron equipos.'));
                  }

                  // Mostramos la lista centrada (como te gustó)
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
                            itemCount: equipos.length,
                            itemBuilder: (context, index) {
                              final team = equipos[index];
                              // Pasamos la lista de supervisores a la tarjeta
                              return TeamListCard(team: team, supervisors: supervisors);
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Leemos la lista de supervisores (que ya está cargada)
          final supervisors = ref.read(userListProvider).asData?.value
              ?.where((user) => user.rol == 'supervisor' || user.rol == 'admin')
              .toList() ?? [];
              
          _showTeamDialog(context, ref, supervisors: supervisors);
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Tarjeta para la lista de Equipos ---
class TeamListCard extends ConsumerWidget {
  final AdminTeam team;
  final List<AdminUser> supervisors; // Recibe la lista pre-filtrada
  const TeamListCard({super.key, required this.team, required this.supervisors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Icon(Icons.group_work, color: Colors.indigo.shade700),
        ),
        title: Text(team.nombreEquipo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Supervisor: ${team.nombreSupervisor ?? "Sin asignar"}',
          style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              // Pasa la lista de supervisores al diálogo de edición
              _showTeamDialog(context, ref, supervisors: supervisors, teamToEdit: team);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, ref, team);
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

// --- Diálogo para CREAR o EDITAR un equipo ---
void _showTeamDialog(BuildContext context, WidgetRef ref, {required List<AdminUser> supervisors, AdminTeam? teamToEdit}) {
  
  final _nameController = TextEditingController(text: teamToEdit?.nombreEquipo ?? '');
  final formKey = GlobalKey<FormState>();
  
  int? _selectedSupervisorId;
  if (teamToEdit?.nombreSupervisor != "Sin asignar") {
    try {
      _selectedSupervisorId = supervisors
          .firstWhere((s) => s.nombreCompleto == teamToEdit!.nombreSupervisor!)
          .id;
    } catch (e) {
      _selectedSupervisorId = null; // No lo encontró
    }
  }

  final bool isEditing = teamToEdit != null;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(isEditing ? 'Editar Equipo' : 'Crear Nuevo Equipo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Equipo'),
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              // Menú desplegable para el Supervisor
              DropdownButtonFormField<int?>(
                value: _selectedSupervisorId,
                decoration: const InputDecoration(labelText: 'Asignar Supervisor (Opcional)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null, 
                    child: Text('Sin asignar', style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  ...supervisors.map((user) {
                    return DropdownMenuItem<int?>(
                      value: user.id,
                      child: Text(user.nombreCompleto),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  _selectedSupervisorId = value;
                },
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
                  'nombre_equipo': _nameController.text,
                  'supervisor_id': _selectedSupervisorId,
                };
                
                try {
                  if (isEditing) {
                    await ref.read(teamListProvider.notifier).updateTeam(teamToEdit.id, data);
                  } else {
                    await ref.read(teamListProvider.notifier).addTeam(data);
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
void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AdminTeam team) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar Equipo?'),
      content: Text('¿Estás seguro de que deseas eliminar "${team.nombreEquipo}"?'),
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
              await ref.read(teamListProvider.notifier).removeTeam(team.id);
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