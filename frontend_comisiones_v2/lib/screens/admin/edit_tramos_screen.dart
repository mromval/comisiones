// lib/screens/admin/edit_tramos_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:intl/intl.dart'; 

class EditTramosScreen extends ConsumerStatefulWidget {
  final AdminConcurso concurso;
  const EditTramosScreen({super.key, required this.concurso});

  @override
  ConsumerState<EditTramosScreen> createState() => _EditTramosScreenState();
}

class _EditTramosScreenState extends ConsumerState<EditTramosScreen> {
  
  // Estados para las fechas
  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;

  // --- ¡NUEVOS CONTROLADORES! ---
  // (Para los campos de requisitos)
  final _minUfController = TextEditingController();
  final _tasaController = TextEditingController();
  final _minContratosController = TextEditingController();
  final _topeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargamos las fechas actuales
    _selectedStartDate = DateTime.parse(widget.concurso.periodoInicio);
    _selectedEndDate = DateTime.parse(widget.concurso.periodoFin);

    // --- ¡NUEVO! ---
    // Cargamos los requisitos actuales del concurso en los controladores
    _minUfController.text = widget.concurso.requisitoMinUfTotal?.toStringAsFixed(2) ?? '';
    _tasaController.text = widget.concurso.requisitoTasaRecaudacion?.toStringAsFixed(2) ?? '';
    _minContratosController.text = widget.concurso.requisitoMinContratos?.toString() ?? '';
    _topeController.text = widget.concurso.topeMonto?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _minUfController.dispose();
    _tasaController.dispose();
    _minContratosController.dispose();
    _topeController.dispose();
    super.dispose();
  }

  // Helper para mostrar el selector de fechas
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
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
      // Guardamos solo las fechas (los otros campos se guardan con el botón)
      _onSaveConcursoDetails({'periodo_inicio': _selectedStartDate.toIso8601String().split('T').first,});
    }
  }

  // --- ¡FUNCIÓN DE GUARDAR (ACTUALIZADA)! ---
  // Ahora guarda TODOS los campos
  Future<void> _onSaveConcursoDetails([Map<String, dynamic>? dateData]) async {
    
    // Si no vinieron datos de fecha, son los de los textfields
    final data = dateData ?? {
      'requisito_min_uf_total': double.tryParse(_minUfController.text),
      'requisito_tasa_recaudacion': double.tryParse(_tasaController.text),
      'requisito_min_contratos': int.tryParse(_minContratosController.text),
      'tope_monto': double.tryParse(_topeController.text),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando...'), duration: Duration(seconds: 1)),
    );

    try {
      await ref.read(concursoListProvider.notifier).updateConcurso(widget.concurso.id, data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- FIN DE LA ACTUALIZACIÓN ---


  @override
  Widget build(BuildContext context) {
    final asyncTramos = ref.watch(tramoListProvider(widget.concurso.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.concurso.nombreComponente} - ${widget.concurso.nombrePerfil}'),
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
        child: asyncTramos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error al cargar tramos: $err'),
            ),
          ),
          data: (tramos) {
            // Mostramos los Tramos Y las Fechas
            // ¡CAMBIO! Envolvemos todo en un ListView para scrolling
            return ListView(
              children: [
                // --- ¡WIDGET DE FECHAS Y REQUISITOS! ---
                _buildConcursoEditor(context),
                
                // --- Título de la lista de Tramos ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Tramos de Pago',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.indigo.shade800),
                  ),
                ),

                // --- Lista de Tramos ---
                if (tramos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('Este concurso aún no tiene tramos.')),
                  )
                else
                  // Usamos shrinkWrap y physics para que funcione dentro del ListView
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), 
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: tramos.length,
                    itemBuilder: (context, index) {
                      final tramo = tramos[index];
                      return TramoListCard(tramo: tramo, concursoId: widget.concurso.id);
                    },
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showTramoDialog(context, ref, concursoId: widget.concurso.id);
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12, width: 1)),
        ),
        child: TextButton.icon(
          icon: const Icon(Icons.delete_forever),
          label: const Text('ELIMINAR ESTE CONCURSO'),
          onPressed: () {
            _showDeleteConfirmation(context, ref, widget.concurso.id, widget.concurso.nombreComponente);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // --- ¡WIDGET ACTUALIZADO! ---
  // Ahora es una tarjeta para editar Periodo Y Requisitos
  Widget _buildConcursoEditor(BuildContext context) {
    String startDate = DateFormat('dd/MM/yyyy').format(_selectedStartDate);
    String endDate = DateFormat('dd/MM/yyyy').format(_selectedEndDate);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración del Concurso',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.indigo.shade800),
            ),
            const SizedBox(height: 16),
            
            // --- Editores de Fecha ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Inicio: $startDate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200, 
                      foregroundColor: Colors.black87
                    ),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Fin: $endDate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200, 
                      foregroundColor: Colors.black87
                    ),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32, thickness: 1),

            // --- ¡NUEVOS CAMPOS DE REQUISITOS! ---
            Text(
              'Requisitos (Opcional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.indigo.shade700),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _onSaveConcursoDetails(),
              child: const Text('Guardar Requisitos'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44)
              ),
            )
          ],
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

} // Fin de _EditTramosScreenState


// --- Diálogo de Confirmación de Borrado (Sin cambios) ---
void _showDeleteConfirmation(BuildContext context, WidgetRef ref, int concursoId, String concursoNombre) {
  // ... (código idéntico) ...
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar Concurso?'),
      content: Text('¿Estás seguro de que deseas eliminar "$concursoNombre"? Esta acción es permanente y borrará todos sus tramos.'),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sí, Eliminar'),
          onPressed: () {
            ref.read(concursoListProvider.notifier).deleteConcurso(concursoId);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    ),
  );
}

// --- Tarjeta de Tramo (Sin cambios) ---
class TramoListCard extends ConsumerWidget {
  // ... (código idéntico) ...
  final AdminTramo tramo;
  final int concursoId;
  const TramoListCard({super.key, required this.tramo, required this.concursoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numberFormatter = NumberFormat.decimalPattern('es_CL');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          'UF: ${tramo.tramoDesdeUf.toStringAsFixed(2)} - ${tramo.tramoHastaUf.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Paga: \$ ${numberFormatter.format(tramo.montoPago)}',
          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showTramoDialog(context, ref, concursoId: concursoId, tramoAEditar: tramo);
            } else if (value == 'delete') {
              ref.read(tramoListProvider(concursoId).notifier).removeTramo(tramo.id);
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

// --- Diálogo de Tramo (Sin cambios) ---
void _showTramoDialog(BuildContext context, WidgetRef ref, {required int concursoId, AdminTramo? tramoAEditar}) {
  // ... (código idéntico) ...
  final _desdeController = TextEditingController(text: tramoAEditar?.tramoDesdeUf.toStringAsFixed(2) ?? '');
  final _hastaController = TextEditingController(text: tramoAEditar?.tramoHastaUf.toStringAsFixed(2) ?? '');
  final _montoController = TextEditingController(text: tramoAEditar?.montoPago.toStringAsFixed(0) ?? '');
  final bool isEditing = tramoAEditar != null;
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(isEditing ? 'Editar Tramo' : 'Añadir Nuevo Tramo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _desdeController,
                decoration: const InputDecoration(labelText: 'Desde UF'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _hastaController,
                decoration: const InputDecoration(labelText: 'Hasta UF'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(labelText: 'Monto a Pagar \$'),
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
            child: Text(isEditing ? 'Guardar Cambios' : 'Añadir'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final data = {
                  'tramo_desde_uf': double.parse(_desdeController.text),
                  'tramo_hasta_uf': double.parse(_hastaController.text),
                  'monto_pago': double.parse(_montoController.text),
                };
                if (isEditing) {
                  ref.read(tramoListProvider(concursoId).notifier).editTramo(tramoAEditar.id, data);
                } else {
                  ref.read(tramoListProvider(concursoId).notifier).addTramo(data);
                }
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}