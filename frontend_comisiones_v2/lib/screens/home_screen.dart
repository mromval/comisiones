import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

// --- NUEVOS PROVIDERS PARA EL CÁLCULO ---

// Estado del resultado del cálculo
final calculationResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// Estado de carga del cálculo
final calculationLoadingProvider = StateProvider<bool>((ref) => false);


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _ufVendidasController = TextEditingController();

  // Función para llamar a tu API de cálculo
  Future<void> _calculateCommissions() async {
    // 1. Obtener el token del AuthProvider
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      // Si no está autenticado (debería ser imposible aquí), salimos.
      return;
    }
    final token = authState.token;

    // 2. Marcar como cargando
    ref.read(calculationLoadingProvider.notifier).state = true;
    ref.read(calculationResultProvider.notifier).state = null; // Limpiar resultado anterior

    try {
      // 3. Preparar los datos y la llamada HTTP
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/calcular'), // Tu URL del backend
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ¡ENVIAMOS EL TOKEN!
        },
        body: jsonEncode({'uf_vendidas': int.parse(_ufVendidasController.text)}),
      );

      // 4. Manejar la respuesta
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
      // 5. Dejar de cargar
      ref.read(calculationLoadingProvider.notifier).state = false;
    }
  }

  // --- INICIO DE LA CORRECCIÓN (1/3) ---
  // Esta función se llama cada vez que el texto cambia
  void _onTextFieldChanged() {
    setState(() {
      // Esto fuerza a la pantalla a "redibujarse"
      // y re-evaluar si el botón debe estar activo.
    });
  }

  @override
  void initState() {
    super.initState();
    // 2. Le decimos al controlador que "escuche" los cambios
    // y llame a nuestra función de arriba
    _ufVendidasController.addListener(_onTextFieldChanged);
  }
  // --- FIN DE LA CORRECCIÓN (1/3) ---

  @override
  void dispose() {
    // --- INICIO DE LA CORRECCIÓN (2/3) ---
    // 3. Limpiamos el "listener" antes de destruir el controlador
    _ufVendidasController.removeListener(_onTextFieldChanged);
    // --- FIN DE LA CORRECCIÓN (2/3) ---
    _ufVendidasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observamos el estado de la calculadora
    final isCalculating = ref.watch(calculationLoadingProvider);
    final result = ref.watch(calculationResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Comisiones'),
        backgroundColor: Colors.deepPurple.shade700, // Color AppBar
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
          // Fondo degradado
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                      'Bienvenido a tu Panel',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.deepPurple.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ufVendidasController,
                      decoration: InputDecoration(
                        labelText: 'UF Vendidas',
                        hintText: 'Ej: 250',
                        prefixIcon: const Icon(Icons.currency_bitcoin, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    isCalculating
                        ? const CircularProgressIndicator(color: Colors.deepPurple)
                        : ElevatedButton.icon(
                            // --- INICIO DE LA CORRECCIÓN (3/3) ---
                            // Ahora, esta condición se revisa CADA VEZ que escribes,
                            // gracias al setState() de nuestra nueva función
                            onPressed: _ufVendidasController.text.isEmpty ? null : _calculateCommissions,
                            // --- FIN DE LA CORRECCIÓN (3/3) ---
                            icon: const Icon(Icons.calculate),
                            label: const Text('Calcular Comisión'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade600, // Color botón
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tu Renta Final: \$${result['renta_final']?.toStringAsFixed(0) ?? '0'}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ..._buildResultDetails(result, context),
                        ],
                      )
                    else
                      Text(
                        'Ingresa tus UF vendidas para calcular tu comisión.',
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

  // Helper para construir los detalles del desglose
  List<Widget> _buildResultDetails(Map<String, dynamic> result, BuildContext context) {
    final List<Widget> widgets = [
      ListTile(
        leading: const Icon(Icons.attach_money, color: Colors.deepPurple),
        title: const Text('Bonos Base'),
        trailing: Text('\$${result['bonos_base']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      ListTile(
        leading: const Icon(Icons.percent, color: Colors.deepPurple),
        title: const Text('Factor Aplicado'),
        trailing: Text('x${result['factor_aplicado']?.toStringAsFixed(2) ?? '1.00'}', style: const TextStyle(fontWeight: FontWeight.bold)),
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