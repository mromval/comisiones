// lib/screens/admin/manage_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:frontend_comisiones_v2/screens/admin/create_user_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/edit_user_screen.dart';

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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
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
              
              // --- ¡INICIO DE LA MEJORA GRÁFICA! ---
              // 1. Centramos la lista
              return Center(
                child: ConstrainedBox(
                  // 2. Le damos un ancho máximo (puedes ajustar esto)
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    // 3. Envolvemos el ListView en un Card
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias, // Para que la lista respete los bordes
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
              // --- FIN DE LA MEJORA GRÁFICA ---
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
          );
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
        trailing: Chip(
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
        onTap: () {
          // Invalidamos para que la pantalla de edición SIEMPRE tenga datos frescos
          ref.invalidate(teamListProvider);
          ref.invalidate(profileListProvider);

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditUserScreen(user: user),
            ),
          );
        },
      ),
    );
  }
}