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
  
  // (Controladores y lógica de initState, dispose, _selectDate, _onSaveConcursoDetails... sin cambios)
  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;
  final _minUfController = TextEditingController();
  final _tasaController = TextEditingController();
  final _minContratosController = TextEditingController();
  final _topeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStartDate = DateTime.parse(widget.concurso.periodoInicio);
    _selectedEndDate = DateTime.parse(widget.concurso.periodoFin);
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
      _onSaveConcursoDetails({
        isStartDate ? 'periodo_inicio' : 'periodo_fin': picked.toIso8601String().split('T').first,
      });
    }
  }

  Future<void> _onSaveConcursoDetails([Map<String, dynamic>? dateData]) async {
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

  @override
  Widget build(BuildContext context) {
    final asyncTramos = ref.watch(tramoListProvider(widget.concurso.id));
    
    // --- ¡INICIO DE LA MODIFICACIÓN! ---
    // Determinamos las etiquetas que usará el diálogo
    final String clave = widget.concurso.claveLogica;
    String tituloDialogo = 'Añadir Nuevo Tramo';
    String labelDesde = 'Desde UF';
    String labelHasta = 'Hasta UF';
    String labelMonto = 'Monto a Pagar \$';
    TextInputType keyboardTipoMonto = TextInputType.number;
    TextInputType keyboardTipoRango = const TextInputType.numberWithOptions(decimal: true);

    if (clave.startsWith('PYME_PCT')) {
      tituloDialogo = 'Añadir Rango de Porcentaje';
      labelDesde = 'Desde UF';
      labelHasta = 'Hasta UF';
      labelMonto = 'Porcentaje (ej: 0.30 para 30%)';
      keyboardTipoMonto = const TextInputType.numberWithOptions(decimal: true);
    } else if (clave.startsWith('REF_')) {
      tituloDialogo = 'Añadir Rango de Contratos';
      labelDesde = 'Desde N° Contratos (ej: 1)';
      labelHasta = 'Hasta N° Contratos (ej: 3)';
      labelMonto = 'Monto a Pagar \$';
      keyboardTipoRango = TextInputType.number;
    } else if (clave.startsWith('RANK_')) {
      tituloDialogo = 'Añadir Premio de Ranking';
      labelDesde = 'Desde Posición (ej: 1)';
      labelHasta = 'Hasta Posición (ej: 3)';
      labelMonto = 'Monto a Pagar \$';
      keyboardTipoRango = TextInputType.number;
    }
    // --- FIN DE LA MODIFICACIÓN ---

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.concurso.nombreComponente} - ${widget.concurso.nombrePerfil}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        // ... (decoración sin cambios) ...
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
              // Mostramos el mensaje de error que viene del provider
              child: Text('Error al cargar tramos: ${err.toString()}'),
            ),
          ),
          data: (tramos) {
            return ListView(
              children: [
                _buildConcursoEditor(context),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Tramos de Pago', // Título genérico, está bien
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.indigo.shade800),
                  ),
                ),

                if (tramos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('Este concurso aún no tiene tramos.')),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), 
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: tramos.length,
                    itemBuilder: (context, index) {
                      final tramo = tramos[index];
                      // --- ¡MODIFICACIÓN! ---
                      // Pasamos las etiquetas al Card y al diálogo de edición
                      return TramoListCard(
                        tramo: tramo, 
                        concursoId: widget.concurso.id,
                        labelDesde: labelDesde,
                        labelHasta: labelHasta,
                        labelMonto: labelMonto,
                        keyboardTipoMonto: keyboardTipoMonto,
                        keyboardTipoRango: keyboardTipoRango,
                        tituloDialogo: tituloDialogo,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // --- ¡MODIFICACIÓN! ---
          // Pasamos las etiquetas al diálogo de creación
          _showTramoDialog(
            context, ref, 
            concursoId: widget.concurso.id,
            labelDesde: labelDesde,
            labelHasta: labelHasta,
            labelMonto: labelMonto,
            keyboardTipoMonto: keyboardTipoMonto,
            keyboardTipoRango: keyboardTipoRango,
            tituloDialogo: tituloDialogo,
          );
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        // ... (botón de eliminar sin cambios) ...
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

  // --- Widget _buildConcursoEditor (Sin cambios) ---
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
            Text(
              'Requisitos (Opcional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.indigo.shade700),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _minUfController, 
              'Requisito Mínimo UF (Ej: 13)', 
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _tasaController, 
              'Requisito Tasa Recaudación (Ej: 85.0)', // Texto de ayuda actualizado
              const TextInputType.numberWithOptions(decimal: true),
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

// --- ¡TARJETA DE TRAMO MODIFICADA! ---
class TramoListCard extends ConsumerWidget {
  final AdminTramo tramo;
  final int concursoId;
  // ¡Nuevos parámetros para las etiquetas!
  final String labelDesde;
  final String labelHasta;
  final String labelMonto;
  final TextInputType keyboardTipoRango;
  final TextInputType keyboardTipoMonto;
  final String tituloDialogo;

  const TramoListCard({
    super.key, 
    required this.tramo, 
    required this.concursoId,
    required this.labelDesde,
    required this.labelHasta,
    required this.labelMonto,
    required this.keyboardTipoRango,
    required this.keyboardTipoMonto,
    required this.tituloDialogo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numberFormatter = NumberFormat.decimalPattern('es_CL');
    
    // Mostramos "UF", "N°" o "Pos" dependiendo del label
    String tituloRango = '${labelDesde.split(' ')[0]} ${tramo.tramoDesdeUf.toStringAsFixed(2)} - ${tramo.tramoHastaUf.toStringAsFixed(2)}';
    
    // Mostramos monto o %
    String subtituloMonto = 'Paga: \$ ${numberFormatter.format(tramo.montoPago)}';
    if (labelMonto.startsWith('Porcentaje')) {
      subtituloMonto = 'Paga: ${(tramo.montoPago * 100).toStringAsFixed(0)}%';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(tituloRango, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtituloMonto,
          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showTramoDialog(
                context, ref, 
                concursoId: concursoId, 
                tramoAEditar: tramo,
                labelDesde: labelDesde,
                labelHasta: labelHasta,
                labelMonto: labelMonto,
                keyboardTipoMonto: keyboardTipoMonto,
                keyboardTipoRango: keyboardTipoRango,
                tituloDialogo: tituloDialogo,
              );
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

// --- ¡DIÁLOGO DE TRAMO MODIFICADO! ---
void _showTramoDialog(
  BuildContext context, 
  WidgetRef ref, {
  required int concursoId, 
  AdminTramo? tramoAEditar,
  // ¡Nuevos parámetros!
  required String tituloDialogo,
  required String labelDesde,
  required String labelHasta,
  required String labelMonto,
  required TextInputType keyboardTipoRango,
  required TextInputType keyboardTipoMonto,
}) {
  
  // Formateamos el monto a pagar
  // Si es un porcentaje (ej: 0.30), lo mostramos como tal.
  // Si es un monto (ej: 50000), lo mostramos como entero.
  String montoInicial = '';
  if (tramoAEditar != null) {
    if (labelMonto.startsWith('Porcentaje')) {
      montoInicial = tramoAEditar.montoPago.toStringAsFixed(2);
    } else {
      montoInicial = tramoAEditar.montoPago.toStringAsFixed(0);
    }
  }
  
  // Formateamos los rangos
  // Si es decimal (UF) lo mostramos con decimales.
  // Si es entero (N° Contratos, Posición) lo mostramos como entero.
  String desdeInicial = '';
  String hastaInicial = '';
  if (tramoAEditar != null) {
    if (keyboardTipoRango == TextInputType.number) {
      desdeInicial = tramoAEditar.tramoDesdeUf.toStringAsFixed(0);
      hastaInicial = tramoAEditar.tramoHastaUf.toStringAsFixed(0);
    } else {
      desdeInicial = tramoAEditar.tramoDesdeUf.toStringAsFixed(2);
      hastaInicial = tramoAEditar.tramoHastaUf.toStringAsFixed(2);
    }
  }

  final _desdeController = TextEditingController(text: desdeInicial);
  final _hastaController = TextEditingController(text: hastaInicial);
  final _montoController = TextEditingController(text: montoInicial);
  
  final bool isEditing = tramoAEditar != null;
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(isEditing ? 'Editar Tramo' : tituloDialogo),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _desdeController,
                decoration: InputDecoration(labelText: labelDesde),
                keyboardType: keyboardTipoRango, 
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _hastaController,
                decoration: InputDecoration(labelText: labelHasta),
                keyboardType: keyboardTipoRango, 
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _montoController,
                decoration: InputDecoration(labelText: labelMonto),
                keyboardType: keyboardTipoMonto,
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
            onPressed: () async { // <-- ¡Convertido a async!
              if (formKey.currentState?.validate() ?? false) {
                final data = {
                  'tramo_desde_uf': double.parse(_desdeController.text),
                  'tramo_hasta_uf': double.parse(_hastaController.text),
                  'monto_pago': double.parse(_montoController.text),
                };

                try {
                  if (isEditing) {
                    await ref.read(tramoListProvider(concursoId).notifier).editTramo(tramoAEditar!.id, data);
                  } else {
                    await ref.read(tramoListProvider(concursoId).notifier).addTramo(data);
                  }
                  if(context.mounted) Navigator.of(context).pop();
                
                } catch (e) {
                  // Si el provider falla (ej: "Campos Faltantes"), muestra el error
                   if(context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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