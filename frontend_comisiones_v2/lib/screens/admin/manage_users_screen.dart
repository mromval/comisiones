// lib/screens/admin/manage_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:frontend_comisiones_v2/screens/admin/create_user_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/edit_user_screen.dart';
// --- ¡NUEVO IMPORT! ---
import 'package:frontend_comisiones_v2/screens/admin/import_users_screen.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(userListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Ejecutivos'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        // --- ¡INICIO DE LA MODIFICACIÓN! ---
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file), // Icono de "Importar"
            tooltip: 'Importar Usuarios (Masivo)',
            onPressed: () {
              // Navegamos a la nueva pantalla de importación
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ImportUsersScreen(),
                ),
              ).then((_) {
                // Al volver de la importación, refrescamos la lista
                ref.invalidate(userListProvider);
              });
            },
          ),
        ],
        // --- FIN DE LA MODIFICACIÓN! ---
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(userListProvider.notifier);
        },
        child: Container(
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
              if (users.isEmpty) {
                return const Center(child: Text('No se encontraron usuarios.'));
              }
              
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
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return UserListCard(user: user);
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
          ref.invalidate(teamListProvider);
          ref.invalidate(profileListProvider);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateUserScreen(),
            ),
          ).then((_) {
            // Cuando volvemos, invalidamos la lista de usuarios
            // por si creamos uno nuevo.
            ref.invalidate(userListProvider);
          });
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Widget separado para el item de la lista ---
class UserListCard extends ConsumerWidget {
  const UserListCard({super.key, required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.rol == 'supervisor' ? Colors.indigo.shade100 : Colors.deepPurple.shade50,
          child: Icon(
            user.rol == 'supervisor' ? Icons.admin_panel_settings : Icons.person,
            color: user.rol == 'supervisor' ? Colors.indigo.shade700 : Colors.deepPurple.shade700,
          ),
        ),
        title: Text(user.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Text(
              'Perfil: ${user.nombrePerfil ?? "No definido"}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              'Equipo: ${user.nombreEquipo ?? "Sin asignar"}',
              style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
        
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              ref.invalidate(teamListProvider);
              ref.invalidate(profileListProvider);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditUserScreen(user: user),
                ),
              ).then((_) {
                ref.invalidate(userListProvider);
              });

            } else if (value == 'delete') {
              _showDeactivateConfirmation(context, ref, user);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, color: Colors.indigo.shade700), 
                title: const Text('Editar')
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.person_off, color: Colors.red.shade700), 
                title: const Text('Inactivar', style: TextStyle(color: Colors.red))
              ),
            ),
          ],
          icon: Chip(
            label: Text(
              user.rol.toUpperCase(),
              style: TextStyle(
                color: user.rol == 'supervisor' ? Colors.indigo.shade900 : Colors.deepPurple.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            backgroundColor: user.rol == 'supervisor' ? Colors.indigo.shade100 : Colors.deepPurple.shade100,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            side: BorderSide.none,
          ),
        ),
        onTap: null, 
      ),
    );
  }
}

// --- Diálogo de Confirmación de Borrado ---
void _showDeactivateConfirmation(BuildContext context, WidgetRef ref, AdminUser user) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Inactivar Usuario?'),
      content: Text('¿Estás seguro de que deseas inactivar a "${user.nombreCompleto}"?\n\nEl usuario ya no podrá iniciar sesión, pero sus datos históricos se conservarán.'),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sí, Inactivar'),
          onPressed: () async {
            try {
              await ref.read(userListProvider.notifier).removeUser(user.id);
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