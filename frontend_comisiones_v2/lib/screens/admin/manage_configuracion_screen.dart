// lib/screens/admin/manage_configuracion_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha

class ManageConfiguracionScreen extends ConsumerWidget {
  const ManageConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConfig = ref.watch(configListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variables Globales'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresca el provider
          return ref.refresh(configListProvider.notifier);
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
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          Text(
                            'Variables Globales del Simulador',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.indigo.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 32),
                          // --- Sueldo Base ---
                          _buildConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'SUELDO_BASE',
                              orElse: () => AdminConfig(llave: 'SUELDO_BASE', valor: '529000'),
                            ),
                            'Sueldo Base',
                            'Monto base para el cálculo de renta.',
                            prefixIcon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                          ),
                          // --- UF Fallback ---
                          _buildConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'FALLBACK_VALOR_UF',
                              orElse: () => AdminConfig(llave: 'FALLBACK_VALOR_UF', valor: '40000'),
                            ),
                            'Valor UF de Fallback',
                            'Valor de la UF si la API externa falla.',
                            prefixIcon: Icons.currency_bitcoin,
                            keyboardType: TextInputType.number,
                          ),
                          
                          const Divider(height: 32),
                          Text(
                            'Fechas de Períodos (para UI Ejecutivo)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.indigo.shade800,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // --- FECHAS P1 ---
                          _buildDateConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'FECHA_INICIO_P1',
                              orElse: () => AdminConfig(llave: 'FECHA_INICIO_P1', valor: null),
                            ),
                            'Fecha Inicio Período 1',
                            'Inicio del primer período de Tramos UF',
                          ),
                          _buildDateConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'FECHA_FIN_P1',
                              orElse: () => AdminConfig(llave: 'FECHA_FIN_P1', valor: null),
                            ),
                            'Fecha Fin Período 1',
                            'Fin del primer período de Tramos UF',
                          ),
                          const SizedBox(height: 16),

                          // --- FECHAS P2 ---
                           _buildDateConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'FECHA_INICIO_P2',
                              orElse: () => AdminConfig(llave: 'FECHA_INICIO_P2', valor: null),
                            ),
                            'Fecha Inicio Período 2',
                            'Inicio del segundo período de Tramos UF',
                          ),
                          _buildDateConfigItem(
                            context, ref,
                            configs.firstWhere(
                              (c) => c.llave == 'FECHA_FIN_P2',
                              orElse: () => AdminConfig(llave: 'FECHA_FIN_P2', valor: null),
                            ),
                            'Fecha Fin Período 2',
                            'Fin del segundo período de Tramos UF',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Helper para items de texto/número ---
  Widget _buildConfigItem(
    BuildContext context,
    WidgetRef ref,
    AdminConfig config,
    String label,
    String description, {
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    final TextEditingController controller = TextEditingController(text: config.valor);
    final focusNode = FocusNode();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.indigo.shade400) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                color: Colors.indigo.shade600,
                tooltip: 'Guardar',
                onPressed: () {
                  if (controller.text != config.valor) {
                    ref.read(configListProvider.notifier).updateConfig(config.llave, controller.text).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"${config.llave}" actualizada.'), backgroundColor: Colors.green),
                      );
                      focusNode.unfocus();
                    }).catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    });
                  } else {
                    focusNode.unfocus();
                  }
                },
              ),
            ),
            keyboardType: keyboardType,
            onFieldSubmitted: (value) {
              if (value != config.valor) {
                 ref.read(configListProvider.notifier).updateConfig(config.llave, value).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  });
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 12.0),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // --- ¡HELPER DE FECHA CORREGIDO! ---
  Widget _buildDateConfigItem(
    BuildContext context,
    WidgetRef ref,
    AdminConfig config,
    String label,
    String description,
  ) {
    DateTime? initialDate;
    // --- ¡INICIO DE LA CORRECCIÓN! ---
    // Verificamos si config.valor NO es nulo Y NO está vacío antes de parsear
    if (config.valor != null && config.valor!.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(config.valor!);
      } catch (_) {
        initialDate = null; // Si está mal formateado, lo dejamos nulo
      }
    }
    // --- FIN DE LA CORRECCIÓN ---

    final TextEditingController controller = TextEditingController(
      // Si initialDate sigue siendo nulo, mostramos "No definida"
      text: initialDate != null ? DateFormat('dd/MM/yyyy').format(initialDate) : 'No definida',
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(Icons.calendar_today, color: Colors.indigo.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onTap: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: initialDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null && pickedDate != initialDate) {
                
                controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                
                // Guardamos en la BD (el provider lo formatea a YYYY-MM-DD)
                ref.read(configListProvider.notifier).updateConfig(config.llave, pickedDate).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${config.llave}" actualizada a ${controller.text}.'), backgroundColor: Colors.green),
                  );
                }).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                });
              }
            },
          ),
           Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 12.0),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}