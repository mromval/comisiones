// lib/screens/admin/create_concurso_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';

class CreateConcursoScreen extends ConsumerStatefulWidget {
  const CreateConcursoScreen({super.key});

  @override
  ConsumerState<CreateConcursoScreen> createState() => _CreateConcursoScreenState();
}

class _CreateConcursoScreenState extends ConsumerState<CreateConcursoScreen> {
  // Estados para los dropdowns
  int? _selectedPerfilId;
  int? _selectedComponenteId;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // --- ¡NUEVOS CONTROLADORES! ---
  final _minUfController = TextEditingController();
  final _tasaController = TextEditingController();
  final _minContratosController = TextEditingController();
  final _topeController = TextEditingController();

  @override
  void dispose() {
    _minUfController.dispose();
    _tasaController.dispose();
    _minContratosController.dispose();
    _topeController.dispose();
    super.dispose();
  }

  // (Helper _selectDate sin cambios...)
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  // --- FUNCIÓN DE GUARDAR (ACTUALIZADA) ---
  Future<void> _onSave() async {
    if (_selectedPerfilId == null || _selectedComponenteId == null ||
        _selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos obligatorios (Perfil, Regla, Fechas).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Convertimos los campos de texto opcionales a números (o null)
    final double? minUf = double.tryParse(_minUfController.text);
    final double? tasa = double.tryParse(_tasaController.text);
    final int? minContratos = int.tryParse(_minContratosController.text);
    final double? tope = double.tryParse(_topeController.text);

    // 2. Formatear las fechas y añadir TODOS los campos
    final data = {
      'perfil_id': _selectedPerfilId,
      'componente_id': _selectedComponenteId,
      'periodo_inicio': _selectedStartDate!.toIso8601String().split('T').first,
      'periodo_fin': _selectedEndDate!.toIso8601String().split('T').first,
      
      // --- ¡NUEVOS CAMPOS! ---
      'requisito_min_uf_total': minUf,
      'requisito_tasa_recaudacion': tasa,
      'requisito_min_contratos': minContratos,
      'tope_monto': tope,
    };

    // 3. Llamar al provider para guardar
    await ref.read(concursoCreateProvider.notifier).saveConcurso(data);

    // 4. Revisar el resultado y cerrar
    if (mounted) {
      final createStatus = ref.read(concursoCreateProvider);
      if (createStatus is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear: ${createStatus.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        Navigator.of(context).pop(); // Cerrar y volver a la lista
      }
    }
  }
  // --- FIN DE LA ACTUALIZACIÓN ---

  @override
  Widget build(BuildContext context) {
    final asyncProfiles = ref.watch(profileListProvider);
    final asyncComponents = ref.watch(componentListProvider);
    final createStatus = ref.watch(concursoCreateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Concurso'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          (createStatus is AsyncLoading)
            ? const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              )
            : IconButton(
                icon: const Icon(Icons.save),
                onPressed: _onSave,
                tooltip: 'Guardar Concurso',
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
        child: asyncProfiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error al cargar perfiles: $e')),
          data: (perfiles) => asyncComponents.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error al cargar componentes: $e')),
            data: (componentes) {
              return _buildForm(context, perfiles, componentes);
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET DEL FORMULARIO (ACTUALIZADO) ---
  Widget _buildForm(BuildContext context, List<AdminProfile> perfiles, List<AdminComponent> componentes) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 6,
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListView( // Cambiado a ListView para scrolling
            padding: const EdgeInsets.all(32.0),
            // shrinkWrap: true, // No es necesario en un ListView dentro de ConstrainedBox
            children: [
              Text(
                'Detalles del Concurso',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.indigo.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // --- Dropdown de PERFIL ---
              _buildDropdown<int?>(
                context: context,
                label: '¿Para qué Perfil de Usuario? (*)',
                value: _selectedPerfilId,
                items: perfiles.map((profile) {
                  return DropdownMenuItem<int?>(
                    value: profile.id,
                    child: Text(profile.nombrePerfil),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPerfilId = value);
                },
              ),
              const SizedBox(height: 16),

              // --- Dropdown de COMPONENTE ---
              _buildDropdown<int?>(
                context: context,
                label: '¿Qué tipo de regla se usará? (*)',
                value: _selectedComponenteId,
                items: componentes.map((component) {
                  return DropdownMenuItem<int?>(
                    value: component.id,
                    child: Text(component.nombreComponente),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedComponenteId = value);
                },
              ),
              
              const Divider(height: 32, thickness: 1),

              // --- Selectores de Fecha ---
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      context,
                      label: 'Fecha de Inicio (*)',
                      date: _selectedStartDate,
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateField(
                      context,
                      label: 'Fecha de Fin (*)',
                      date: _selectedEndDate,
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 32, thickness: 1),
              
              Text(
                'Requisitos Previos (Opcional)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.indigo.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // --- ¡NUEVOS CAMPOS DE TEXTO! ---
              _buildTextField(
                _minUfController, 
                'Requisito Mínimo UF (Ej: 13)', 
                TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _tasaController, 
                'Requisito Tasa Recaudación (Ej: 0.85)', 
                TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _minContratosController, 
                'Requisito Mínimo Contratos (Ej: 4)', 
                TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _topeController, 
                'Tope Máximo del Bono (Ej: 1000000)', 
                TextInputType.number,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para construir un TextField (¡Nuevo!)
  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
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
  
  // Helper para construir un campo de fecha
  Widget _buildDateField(BuildContext context, {required String label, DateTime? date, required VoidCallback onTap}) {
    // ... (código del campo de fecha sin cambios) ...
    final text = date == null 
        ? 'Seleccionar...' 
        : '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(text, style: const TextStyle(fontSize: 16)),
                const Icon(Icons.calendar_month, color: Colors.indigo),
              ],
            ),
          ),
        ),
      ],
    );
  }
}