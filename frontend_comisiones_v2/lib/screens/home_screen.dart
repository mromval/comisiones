// lib/screens/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ¡Importar para formatear números!
import '../providers/auth_provider.dart';

// --- Providers (sin cambios) ---
final calculationResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final calculationLoadingProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Controladores para todos los inputs
  final _ufP1Controller = TextEditingController();
  final _ufP2Controller = TextEditingController();
  final _ufPymeTransferenciaController = TextEditingController();
  final _ufPymeMandatoController = TextEditingController();
  final _refP1Controller = TextEditingController();
  final _refP2Controller = TextEditingController();
  
  // Controles para Ranking
  final _rankingPosController = TextEditingController(); 
  String? _selectedRankingTipo; 
  
  late final List<TextEditingController> _controllers;

  // --- ¡NUEVO! Formateador de números ---
  final numberFormatter = NumberFormat.decimalPattern('es_CL');

  // Función para llamar a tu API de cálculo
  Future<void> _calculateCommissions() async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      return;
    }
    final token = authState.token;

    ref.read(calculationLoadingProvider.notifier).state = true;
    ref.read(calculationResultProvider.notifier).state = null;

    double safeParseDouble(String text) => double.tryParse(text) ?? 0.0;
    int safeParseInt(String text) => int.tryParse(text) ?? 0;

    final body = jsonEncode({
      'uf_p1': safeParseDouble(_ufP1Controller.text),
      'uf_p2': safeParseDouble(_ufP2Controller.text),
      'uf_pyme_t': safeParseDouble(_ufPymeTransferenciaController.text),
      'uf_pyme_m': safeParseDouble(_ufPymeMandatoController.text),
      'ref_p1': safeParseInt(_refP1Controller.text),
      'ref_p2': safeParseInt(_refP2Controller.text),
      'sim_ranking_tipo': _selectedRankingTipo, 
      'sim_ranking_pos': safeParseInt(_rankingPosController.text), 
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/calcular'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body, 
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        ref.read(calculationResultProvider.notifier).state = result;
      } else {
        final errorBody = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorBody['message'] ?? 'Error al calcular comisiones.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al calcular: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(calculationLoadingProvider.notifier).state = false;
    }
  }

  void _onTextFieldChanged() {
    setState(() {
      // Solo forzamos el redibujo
    });
  }

  bool _canCalculate() {
    if (_controllers.any((controller) => controller.text.isNotEmpty)) {
      return true;
    }
    if (_selectedRankingTipo != null && _rankingPosController.text.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controllers = [
      _ufP1Controller,
      _ufP2Controller,
      _ufPymeTransferenciaController,
      _ufPymeMandatoController,
      _refP1Controller,
      _refP2Controller,
      _rankingPosController, 
    ];
    for (final controller in _controllers) {
      controller.addListener(_onTextFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onTextFieldChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCalculating = ref.watch(calculationLoadingProvider);
    final result = ref.watch(calculationResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Comisiones'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), 
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ingresa tus Ventas del Mes',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.deepPurple.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // --- Formulario ---
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4, 
                      child: ListView(
                        children: [
                          _buildSectionTitle(context, 'Concurso Tramos (Seguros)'),
                          _buildTextField(
                            _ufP1Controller, 
                            'UF Ventas Período 1', 
                            Icons.currency_bitcoin
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _ufP2Controller, 
                            'UF Ventas Período 2', 
                            Icons.currency_bitcoin
                          ),
                          
                          const Divider(height: 32),
                          _buildSectionTitle(context, 'Concurso PYME'),
                          _buildTextField(
                            _ufPymeTransferenciaController, 
                            'UF PYME (Pago Transferencia)', 
                            Icons.business_center
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _ufPymeMandatoController, 
                            'UF PYME (Pago Mandato)', 
                            Icons.business_center
                          ),
                          
                          const Divider(height: 32),
                          _buildSectionTitle(context, 'Concurso Referidos (Isapre)'),
                           _buildTextField(
                            _refP1Controller, 
                            'N° Contratos Período 1', 
                            Icons.assignment,
                            isDecimal: false
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _refP2Controller, 
                            'N° Contratos Período 2', 
                            Icons.assignment,
                            isDecimal: false
                          ),
                          
                          const Divider(height: 32),
                          _buildSectionTitle(context, 'Simulación Ranking (Opcional)'),
                          _buildRankingDropdown(),
                          const SizedBox(height: 16),
                          
                          if (_selectedRankingTipo != null)
                            _buildTextField(
                              _rankingPosController, 
                              'Ingresa tu Posición (Ej: 1)', 
                              Icons.emoji_events,
                              isDecimal: false
                            ),

                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    isCalculating
                        ? const CircularProgressIndicator(color: Colors.deepPurple)
                        : ElevatedButton.icon(
                            onPressed: _canCalculate() ? _calculateCommissions : null,
                            icon: const Icon(Icons.calculate),
                            label: const Text('Calcular Comisión'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          
                    const SizedBox(height: 32),

                    // --- Sección de Resultados ---
                    if (result != null)
                      _buildResultDisplay(result, context)
                    else
                      Text(
                        'Ingresa tus ventas para simular tu renta.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPERS PARA EL FORMULARIO ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.deepPurple.shade700,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isDecimal = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
      ),
      keyboardType: isDecimal 
          ? const TextInputType.numberWithOptions(decimal: true) 
          : TextInputType.number,
    );
  }

  Widget _buildRankingDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRankingTipo,
      decoration: InputDecoration(
        labelText: 'Selecciona Tipo de Ranking',
        prefixIcon: Icon(Icons.bar_chart, color: Colors.deepPurple.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
      ),
      items: const [
        DropdownMenuItem(
          value: null,
          child: Text('No simular ranking', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        DropdownMenuItem(value: 'RANK_SEG', child: Text('Ranking Seguros')),
        DropdownMenuItem(value: 'RANK_PYME', child: Text('Ranking PYME')),
        DropdownMenuItem(value: 'RANK_ISAPRE', child: Text('Ranking Isapre')),
      ],
      onChanged: (String? newValue) {
        setState(() {
          _selectedRankingTipo = newValue;
          if (newValue == null) {
            _rankingPosController.clear();
          }
        });
      },
    );
  }
  
  // --- Widget de Resultados (Extraído) ---
  Widget _buildResultDisplay(Map<String, dynamic> result, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu Renta Final Simulado:',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.deepPurple.shade800,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          '\$${numberFormatter.format(result['renta_final'] ?? 0)}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._buildResultDetails(result, context),
      ],
    );
  }

  // --- ¡FUNCIÓN MODIFICADA PARA MOSTRAR LA UF! ---
  List<Widget> _buildResultDetails(Map<String, dynamic> result, BuildContext context) {
    final List<Widget> widgets = [
      ListTile(
        leading: const Icon(Icons.attach_money, color: Colors.deepPurple),
        title: const Text('Sueldo Base'),
        trailing: Text('\$${numberFormatter.format(result['sueldo_base'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      ListTile(
        leading: const Icon(Icons.star, color: Colors.deepPurple),
        title: const Text('Total Bonos'),
        trailing: Text('\$${numberFormatter.format(result['total_bonos'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      // --- ¡WIDGET AÑADIDO PARA LA UF! ---
      ListTile(
        leading: const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
        title: const Text('Valor UF (usado en cálculo)'),
        trailing: Text('\$${numberFormatter.format(result['valor_uf_usado'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      // --- FIN DEL WIDGET AÑADIDO ---
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          'Desglose del Cálculo:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.deepPurple.shade700),
        ),
      ),
    ];

    if (result['desglose'] is List) {
      if (result['desglose'].isEmpty) {
         widgets.add(
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: Text('- No se generaron bonos este mes.'),
            ),
          );
      }
      for (final item in result['desglose']) {
        if (item is String) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: Text(
                '- $item',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }
}