// lib/screens/admin/edit_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class EditUserScreen extends ConsumerStatefulWidget {
  final AdminUser user; 
  
  const EditUserScreen({super.key, required this.user});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  late String _selectedRol;
  int? _selectedEquipoId;
  int? _selectedPerfilId;

  @override
  void initState() {
    super.initState();
    _selectedRol = widget.user.rol;
    
    try {
      _selectedEquipoId = ref.read(teamListProvider).asData?.value
        .firstWhere((team) => team.nombreEquipo == widget.user.nombreEquipo)
        .id;
    } catch (e) {
      _selectedEquipoId = null;
    }
    
    try {
      _selectedPerfilId = ref.read(profileListProvider).asData?.value
        .firstWhere((profile) => profile.nombrePerfil == widget.user.nombrePerfil)
        .id;
    } catch (e) {
      _selectedPerfilId = null;
    }
  }

  // --- ¡FUNCIÓN DE GUARDAR ACTUALIZADA! ---
  Future<void> _onSave() async {
    
    // --- ¡INICIO DE LA NUEVA VALIDACIÓN! ---
    // 1. Revisamos si los campos obligatorios están seleccionados
    if (_selectedPerfilId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Debes seleccionar un "Perfil de Comisión".'),
          backgroundColor: Colors.orange,
        ),
      );
      return; // Detenemos la función aquí
    }
    // (Puedes añadir más validaciones aquí si lo necesitas, ej: equipo_id)
    // --- FIN DE LA NUEVA VALIDACIÓN ---


    // 2. Construimos el mapa de datos (ahora sabemos que perfil_id no es nulo)
    final data = {
      'rol': _selectedRol,
      'equipo_id': _selectedEquipoId,
      'perfil_id': _selectedPerfilId,
    };

    // 3. Llamamos al notifier (el resto de la función es igual)
    await ref.read(userUpdateProvider.notifier).saveChanges(widget.user.id, data);
    
    if (mounted) {
      final updateState = ref.read(userUpdateProvider);
      if (updateState is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${updateState.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  // --- ¡NUEVA FUNCIÓN PARA EL POP-UP DE CONTRASEÑA! ---
  Future<void> _showResetPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resetear Contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ingresa la nueva contraseña para ${widget.user.nombreCompleto}.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(labelText: 'Nueva Contraseña'),
                  obscureText: true,
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
              child: const Text('Confirmar'),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  // Preparamos solo el dato de la contraseña
                  final data = {'password': newPasswordController.text};
                  
                  // Usamos el MISMO provider de guardado
                  await ref.read(userUpdateProvider.notifier).saveChanges(widget.user.id, data);
                  
                  if (mounted) {
                    Navigator.of(context).pop(); // Cerramos el pop-up
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
  // --- FIN DE LA NUEVA FUNCIÓN ---

  @override
  Widget build(BuildContext context) {
    final asyncTeams = ref.watch(teamListProvider);
    final asyncProfiles = ref.watch(profileListProvider);
    final updateState = ref.watch(userUpdateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.nombreCompleto),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (updateState is AsyncLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _onSave,
              tooltip: 'Guardar Cambios',
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
        child: asyncTeams.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error al cargar equipos: $e')),
          data: (equipos) => asyncProfiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error al cargar perfiles: $e')),
            data: (perfiles) {
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

  Widget _buildForm(BuildContext context, List<AdminTeam> equipos, List<AdminProfile> perfiles) {
    return ListView(
      padding: const EdgeInsets.all(32.0),
      shrinkWrap: true,
      children: [
        Text(
          'Editando a ${widget.user.nombreCompleto}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.indigo.shade800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Dropdown de ROL
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

        // Dropdown de EQUIPO
        _buildDropdown(
          context: context,
          label: 'Equipo Asignado',
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

        // Dropdown de PERFIL DE COMISIÓN
        _buildDropdown(
          context: context,
          label: 'Perfil de Comisión',
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
        
        const Divider(height: 32, thickness: 1),

        // --- ¡NUEVO BOTÓN! ---
        ElevatedButton.icon(
          icon: const Icon(Icons.lock_reset),
          label: const Text('Resetear Contraseña'),
          onPressed: _showResetPasswordDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
        // --- FIN NUEVO BOTÓN ---
      ],
    );
  }

  // Helper de Dropdown (sin cambios)
  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    // ... (código del dropdown sin cambios) ...
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