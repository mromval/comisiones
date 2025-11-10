// lib/screens/admin/create_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  // Controladores para los campos de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();

  // Variables de estado para los dropdowns
  String _selectedRol = 'ejecutivo';
  int? _selectedEquipoId;
  int? _selectedPerfilId;

  // Provider para manejar el estado de "Guardando..."
  final _createProvider = StateProvider<AsyncValue<void>>((ref) => const AsyncData(null));

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  // --- Función para GUARDAR ---
  Future<void> _onSave() async {
    // 1. Validar que los campos no estén vacíos
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos (Email, Clave, Nombre).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Poner estado de "Cargando"
    ref.read(_createProvider.notifier).state = const AsyncLoading();

    // 3. Construir el mapa de datos
    final data = {
      'email': _emailController.text,
      'password': _passwordController.text,
      'nombre_completo': _nombreController.text,
      'rol': _selectedRol,
      'equipo_id': _selectedEquipoId,
      'perfil_id': _selectedPerfilId,
    };

    try {
      // 4. Llamar al API Client
      await ref.read(adminApiClientProvider).createUser(data);

      // 5. ¡Éxito! Refrescar la lista de usuarios y cerrar la pantalla
      ref.invalidate(userListProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario creado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      // 6. ¡Error! Mostrar el error
      ref.read(_createProvider.notifier).state = AsyncError(e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Observamos los providers que traen las listas de opciones
    final asyncTeams = ref.watch(teamListProvider);
    final asyncProfiles = ref.watch(profileListProvider);
    
    // Observamos el estado de "Guardando..."
    final createStatus = ref.watch(_createProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Usuario'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Mostramos un spinner si está guardando
          if (createStatus is AsyncLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _onSave,
              tooltip: 'Guardar Usuario',
            )
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
        // Esperamos que las listas de Equipos y Perfiles carguen
        child: asyncTeams.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error al cargar equipos: $e')),
          data: (equipos) => asyncProfiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error al cargar perfiles: $e')),
            data: (perfiles) {
              // ¡Listo! Mostramos el formulario
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    elevation: 6,
                    margin: const EdgeInsets.all(24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: _buildForm(context, equipos, perfiles),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget que construye el formulario con los campos
  Widget _buildForm(BuildContext context, List<AdminTeam> equipos, List<AdminProfile> perfiles) {
    return ListView(
      padding: const EdgeInsets.all(32.0),
      shrinkWrap: true,
      children: [
        // --- Campos de Texto ---
        _buildTextField(_nombreController, 'Nombre Completo', Icons.person),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(_passwordController, 'Contraseña', Icons.lock, obscureText: true),
        
        const Divider(height: 32, thickness: 1),

        // --- Dropdown de ROL ---
        _buildDropdown(
          context: context,
          label: 'Rol del Usuario',
          value: _selectedRol,
          items: ['ejecutivo', 'supervisor', 'admin'].map((rol) {
            return DropdownMenuItem<String>(
              value: rol,
              child: Text(rol.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedRol = value);
          },
        ),
        
        const SizedBox(height: 16),

        // --- Dropdown de EQUIPO ---
        _buildDropdown(
          context: context,
          label: 'Equipo Asignado (Opcional)',
          value: _selectedEquipoId,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sin asignar', style: TextStyle(fontStyle: FontStyle.italic))),
            ...equipos.map((team) {
              return DropdownMenuItem<int?>(
                value: team.id,
                child: Text(team.nombreEquipo),
              );
            }).toList(),
          ],
          onChanged: (value) {
             setState(() => _selectedEquipoId = value);
          },
        ),

        const SizedBox(height: 16),

        // --- Dropdown de PERFIL DE COMISIÓN ---
        _buildDropdown(
          context: context,
          label: 'Perfil de Comisión (Opcional)',
          value: _selectedPerfilId,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('No definido', style: TextStyle(fontStyle: FontStyle.italic))),
            ...perfiles.map((profile) {
              return DropdownMenuItem<int?>(
                value: profile.id,
                child: Text(profile.nombrePerfil),
              );
            }).toList(),
          ],
          onChanged: (value) {
             setState(() => _selectedPerfilId = value);
          },
        ),
      ],
    );
  }

  // Helper para construir un TextField
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }

  // Helper para construir un Dropdown
  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          isExpanded: true,
        ),
      ],
    );
  }
}