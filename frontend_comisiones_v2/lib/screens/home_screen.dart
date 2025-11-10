// lib/screens/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  // --- ¡INICIO DE LA MODIFICACIÓN! ---
  
  // Controladores para todos los inputs
  final _ufP1Controller = TextEditingController();
  final _ufP2Controller = TextEditingController();
  final _ufPymeTransferenciaController = TextEditingController();
  final _ufPymeMandatoController = TextEditingController();
  final _refP1Controller = TextEditingController();
  final _refP2Controller = TextEditingController();

  // Lista de controladores para manejarlos fácilmente
  late final List<TextEditingController> _controllers;

  // Variable para el ranking
  String? _selectedRanking;
  
  // --- FIN DE LA MODIFICACIÓN ---

  // Función para llamar a tu API de cálculo
  Future<void> _calculateCommissions() async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      return;
    }
    final token = authState.token;

    ref.read(calculationLoadingProvider.notifier).state = true;
    ref.read(calculationResultProvider.notifier).state = null;

    // --- ¡INICIO DE LA MODIFICACIÓN! ---
    // Helper para parsear de forma segura
    double safeParseDouble(String text) => double.tryParse(text) ?? 0.0;
    int safeParseInt(String text) => int.tryParse(text) ?? 0;

    // 3. Preparar los datos y la llamada HTTP
    final body = jsonEncode({
      // Concurso de Tramos (Ej: 1 al 17 y 18 al 30)
      'uf_p1': safeParseDouble(_ufP1Controller.text),
      'uf_p2': safeParseDouble(_ufP2Controller.text),
      
      // Concurso PYME (Transferencia y Mandato)
      'uf_pyme_t': safeParseDouble(_ufPymeTransferenciaController.text),
      'uf_pyme_m': safeParseDouble(_ufPymeMandatoController.text),
      
      // Concurso Referidos (N° Contratos)
      'ref_p1': safeParseInt(_refP1Controller.text),
      'ref_p2': safeParseInt(_refP2Controller.text),
      
      // Simulación de Ranking
      'sim_ranking': _selectedRanking, // Puede ser null
    });
    // --- FIN DE LA MODIFICACIÓN ---

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/calcular'), // Tu URL del backend
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body, // Enviamos el nuevo body
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

  // --- ¡MODIFICADO! ---
  // Función para habilitar el botón
  void _onTextFieldChanged() {
    setState(() {
      // Solo forzamos el redibujo. La lógica está en el botón.
    });
  }

  // Helper para saber si el botón debe estar activo
  bool _canCalculate() {
    // El botón se activa si CUALQUIER campo tiene texto
    return _controllers.any((controller) => controller.text.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    // --- ¡MODIFICADO! ---
    _controllers = [
      _ufP1Controller,
      _ufP2Controller,
      _ufPymeTransferenciaController,
      _ufPymeMandatoController,
      _refP1Controller,
      _refP2Controller,
    ];
    
    // Añadimos el listener a todos los controllers
    for (final controller in _controllers) {
      controller.addListener(_onTextFieldChanged);
    }
  }

  @override
  void dispose() {
    // --- ¡MODIFICADO! ---
    // Limpiamos y disponemos todos los controllers
    for (final controller in _controllers) {
      controller.removeListener(_onTextFieldChanged);
      controller.dispose();
    }
    super.dispose();
  }
  // --- FIN DE LA MODIFICACIÓN ---

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
            constraints: const BoxConstraints(maxWidth: 600), // Más ancho
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

                    // --- ¡INICIO DEL NUEVO FORMULARIO! ---
                    // Usamos un LiseView para scrolling
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4, // Alto limitado
                      child: ListView(
                        children: [
                          _buildSectionTitle(context, 'Concurso Tramos (Seguros)'),
                          _buildTextField(
                            _ufP1Controller, 
                            'UF Ventas Período 1 (Ej: 1-17 Nov)', 
                            Icons.currency_bitcoin
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _ufP2Controller, 
                            'UF Ventas Período 2 (Ej: 18-30 Nov)', 
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
                            'N° Contratos Período 1 (Ej: 1-16 Oct)', 
                            Icons.assignment,
                            isDecimal: false
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _refP2Controller, 
                            'N° Contratos Período 2 (Ej: 17-30 Oct)', 
                            Icons.assignment,
                            isDecimal: false
                          ),
                          
                          const Divider(height: 32),
                          _buildSectionTitle(context, 'Simulación Ranking (Opcional)'),
                          _buildDropdown(),

                        ],
                      ),
                    ),
                    // --- FIN DEL NUEVO FORMULARIO! ---
                    
                    const SizedBox(height: 24),
                    
                    isCalculating
                        ? const CircularProgressIndicator(color: Colors.deepPurple)
                        : ElevatedButton.icon(
                            // --- ¡LÓGICA DE ACTIVACIÓN MODIFICADA! ---
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

                    // --- Sección de Resultados (Sin cambios, ¡reutilizable!) ---
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

  // --- NUEVOS HELPERS PARA EL FORMULARIO ---

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

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRanking,
      decoration: InputDecoration(
        labelText: 'Simular Posición en Ranking',
        prefixIcon: Icon(Icons.emoji_events, color: Colors.deepPurple.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
      ),
      items: [
        // Opciones basadas en el doc
        const DropdownMenuItem(
          value: null,
          child: Text('No simular ranking', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        const DropdownMenuItem(value: 'RANK_SEG_1', child: Text('Ranking Seguros (1° Lugar)')),
        const DropdownMenuItem(value: 'RANK_SEG_2_3', child: Text('Ranking Seguros (2° - 3° Lugar)')),
        const DropdownMenuItem(value: 'RANK_SEG_4_5', child: Text('Ranking Seguros (4° - 5° Lugar)')),
        const DropdownMenuItem(value: 'RANK_PYME_1', child: Text('Ranking PYME (1° Lugar)')),
        const DropdownMenuItem(value: 'RANK_PYME_2_3', child: Text('Ranking PYME (2° - 3° Lugar)')),
        const DropdownMenuItem(value: 'RANK_ISAPRE_1', child: Text('Ranking Isapre (1° Lugar)')),
        const DropdownMenuItem(value: 'RANK_ISAPRE_2_3', child: Text('Ranking Isapre (2° - 3° Lugar)')),
      ],
      onChanged: (String? newValue) {
        setState(() {
          _selectedRanking = newValue;
        });
      },
    );
  }
  
  // --- FIN DE NUEVOS HELPERS ---

  // --- Widget de Resultados (Extraído) ---
  Widget _buildResultDisplay(Map<String, dynamic> result, BuildContext context) {
    // Usamos el NumberFormat que ya teníamos en admin
    // final numberFormatter = NumberFormat.decimalPattern('es_CL');

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
          '\$${result['renta_final']?.toStringAsFixed(0) ?? '0'}',
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

  // Helper para construir los detalles del desglose (Sin cambios)
  List<Widget> _buildResultDetails(Map<String, dynamic> result, BuildContext context) {
    final List<Widget> widgets = [
      ListTile(
        leading: const Icon(Icons.attach_money, color: Colors.deepPurple),
        title: const Text('Sueldo Base'),
        trailing: Text('\$${result['sueldo_base']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      ListTile(
        leading: const Icon(Icons.star, color: Colors.deepPurple),
        title: const Text('Total Bonos'),
        trailing: Text('\$${result['total_bonos']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
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