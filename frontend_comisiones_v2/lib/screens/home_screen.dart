// lib/screens/home_screen.dart
import 'dart:async'; // Para el Debouncer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // Para Imprimir/PDF
import 'package:pdf/pdf.dart'; // Para Imprimir/PDF
import 'package:pdf/widgets.dart' as pw; // Para Imprimir/PDF

import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../models/admin_data_models.dart';

// --- Providers (sin cambios) ---
final calculationResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final calculationLoadingProvider = StateProvider<bool>((ref) => false);

// --- ¡NUEVO! Provider para cargar TODOS los datos de la UI ---
// Carga la configuración (para fechas) y los concursos (para rankings)
final homeScreenDataProvider = FutureProvider((ref) async {
  // Observamos los providers que necesitamos
  final configData = await ref.watch(configListProvider.future);
  final concursos = await ref.watch(concursoListProvider.future);

  // Procesamos las fechas
  String format(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '??';
    try {
      final parsedDate = DateTime.parse(isoDate);
      return DateFormat('dd/MM').format(parsedDate);
    } catch (e) { return '??'; }
  }
  final Map<String, String> dates = {
    'p1_start': format(configData.firstWhere((c) => c.llave == 'FECHA_INICIO_P1', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p1_end': format(configData.firstWhere((c) => c.llave == 'FECHA_FIN_P1', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p2_start': format(configData.firstWhere((c) => c.llave == 'FECHA_INICIO_P2', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p2_end': format(configData.firstWhere((c) => c.llave == 'FECHA_FIN_P2', orElse: () => AdminConfig(llave: '', valor: '')).valor),
  };

  // Filtramos solo los concursos de ranking activos
  final rankingConcursos = concursos.where(
    (c) => c.estaActiva && c.claveLogica.startsWith('RANK_')
  ).toList();

  return {
    'dates': dates,
    'rankingConcursos': rankingConcursos,
  };
});


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
  
  // Mapa para guardar la selección de CADA grupo de ranking
  final Map<String, int> _selectedRankingPos = {};
  
  late final List<TextEditingController> _controllers;
  final numberFormatter = NumberFormat.decimalPattern('es_CL');
  Timer? _debounce;

  // --- Lógica de Cálculo (Ahora envía el mapa de rankings) ---
  void _triggerCalculation() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _calculateCommissions();
      }
    });
  }

  Future<void> _calculateCommissions() async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) return;
    final token = authState.token;

    if (mounted) ref.read(calculationLoadingProvider.notifier).state = true;

    double safeParseDouble(String text) => double.tryParse(text) ?? 0.0;
    int safeParseInt(String text) => int.tryParse(text) ?? 0;
    
    final body = jsonEncode({
      'uf_p1': safeParseDouble(_ufP1Controller.text),
      'uf_p2': safeParseDouble(_ufP2Controller.text),
      'uf_pyme_t': safeParseDouble(_ufPymeTransferenciaController.text),
      'uf_pyme_m': safeParseDouble(_ufPymeMandatoController.text),
      'ref_p1': safeParseInt(_refP1Controller.text),
      'ref_p2': safeParseInt(_refP2Controller.text),
      'sim_rankings': _selectedRankingPos, // <-- ¡Envía el mapa completo!
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/calcular'), 
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: body, 
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) ref.read(calculationResultProvider.notifier).state = result;
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorBody['message'] ?? 'Error al calcular.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        ref.read(calculationLoadingProvider.notifier).state = false;
      }
    }
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
    ];
    for (final controller in _controllers) {
      controller.addListener(_triggerCalculation);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carga los datos de config y concursos
      ref.read(homeScreenDataProvider.future); 
      // Lanza el primer cálculo
      if (mounted) {
        _calculateCommissions();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); 
    for (final controller in _controllers) {
      controller.removeListener(_triggerCalculation);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationResultProvider);
    final uiDataAsync = ref.watch(homeScreenDataProvider);
    final sueldoBase = result?['sueldo_base'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Comisiones'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printScreen(result, uiDataAsync.valueOrNull?['dates'] ?? {}),
            tooltip: 'Imprimir / Guardar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
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
        // --- ¡NUEVO DISEÑO: UNA SOLA COLUMNA! ---
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200), // Ancho total para PC
            child: ListView( // Todo es scrolleable
              padding: const EdgeInsets.all(24.0),
              children: [
                // 1. Tarjeta de Renta Final (arriba)
                _buildResultDisplay(result),
                const SizedBox(height: 24),
                
                // 2. Fila con las dos columnas (Inputs y Ranking)
                uiDataAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, s) => Center(child: Text('Error al cargar datos: $e')),
                  data: (data) {
                    final dates = data['dates'] as Map<String, String>;
                    final rankingConcursos = data['rankingConcursos'] as List<AdminConcurso>;
                    
                    return Row( // La fila principal que pediste
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda: Inputs
                        Expanded(
                          flex: 2, 
                          child: _buildInputsCard(dates),
                        ),
                        const SizedBox(width: 24),
                        // Columna Derecha: Ranking
                        Expanded(
                          flex: 3, 
                          child: _buildRankingCard(result, rankingConcursos),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 24),

                // 3. Tarjeta de Sueldo Base (abajo)
                _buildSueldoBaseDisplay(sueldoBase),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET PARA LA TARJETA DE INPUTS (Columna Izquierda) ---
  Widget _buildInputsCard(Map<String, String> dates) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Concursos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple.shade800, fontSize: 22)),
            
            // --- ¡NUEVO! Títulos de Fechas (como en tu boceto) ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Período 1: ${dates['p1_start']} al ${dates['p1_end']}  |  Período 2: ${dates['p2_start']} al ${dates['p2_end']}',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const Divider(height: 24),
            
            _buildSectionTitle(context, 'Tramos UF (Seguros)'),
            _buildTextField(_ufP1Controller, 'Ventas Período 1'),
            const SizedBox(height: 16),
            _buildTextField(_ufP2Controller, 'Ventas Período 2'),
            
            const Divider(height: 32),
            _buildSectionTitle(context, 'PYME'),
            _buildTextField(_ufPymeTransferenciaController, 'UF Pago Transferencia'),
            const SizedBox(height: 16),
            _buildTextField(_ufPymeMandatoController, 'UF Pago Mandato'),
            
            const Divider(height: 32),
            _buildSectionTitle(context, 'Referidos (Isapre)'),
              _buildTextField(_refP1Controller, 'N° Contratos Período 1', isDecimal: false),
            const SizedBox(height: 16),
            _buildTextField(_refP2Controller, 'N° Contratos Período 2', isDecimal: false),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PARA LA TARJETA DE RANKING (Columna Derecha) ---
  Widget _buildRankingCard(Map<String, dynamic>? result, List<AdminConcurso> rankingConcursos) {
    // Sacamos las métricas del resultado para la validación
    final Map<String, dynamic> metricas = result?['debug_metricas_usadas'] ?? {};
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ranking', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple.shade800, fontSize: 22)),
            const Divider(height: 24),
            if (rankingConcursos.isEmpty)
              const Text('No hay concursos de ranking activos este mes.'),
            ...rankingConcursos.map((concurso) {
              // ¡Validación! Verificamos si cumple los requisitos
              final String? motivoFallo = _checkRequisitos(concurso, metricas);
              final bool habilitado = (motivoFallo == null);

              return _buildRankingGroup(concurso, habilitado, motivoFallo);
            }).toList(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PARA CADA GRUPO DE RANKING (Seguros, PYME, Isapre) ---
  Widget _buildRankingGroup(AdminConcurso concurso, bool habilitado, String? motivoFallo) {
    // Usamos un Consumer para cargar los tramos (premios) de este concurso
    return Consumer(
      builder: (context, widgetRef, child) {
        final asyncTramos = widgetRef.watch(tramoListProvider(concurso.id));
        
        return Opacity(
          opacity: habilitado ? 1.0 : 0.5, // Se ve "apagado" si está deshabilitado
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, concurso.nombreComponente),
              if (!habilitado)
                Padding(
                  padding: const EdgeInsets.only(left: 10.0, bottom: 8.0),
                  child: Text(
                    'No habilitado: ${motivoFallo ?? "No cumples requisitos"}',
                    style: TextStyle(color: Colors.red.shade700, fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
              asyncTramos.when(
                loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                error: (e,s) => Text('Error al cargar premios: $e'),
                data: (tramos) {
                  // Creamos los RadioListTiles
                  final radios = tramos.map((tramo) {
                    String label = '${tramo.tramoDesdeUf.toInt()}°';
                    if (tramo.tramoHastaUf.toInt() != tramo.tramoDesdeUf.toInt()) {
                      label += ' - ${tramo.tramoHastaUf.toInt()}° Lugar';
                    } else {
                      label += ' Lugar';
                    }
                    label += ': \$${numberFormatter.format(tramo.montoPago)}';
                    
                    final int posValue = tramo.tramoDesdeUf.toInt();

                    return RadioListTile<int>(
                      title: Text(label, style: const TextStyle(fontSize: 13)), // Letra más chica
                      value: posValue,
                      groupValue: _selectedRankingPos[concurso.claveLogica],
                      // --- ¡BUG DE RANKING CORREGIDO! ---
                      onChanged: habilitado ? (int? value) {
                        setState(() {
                          // Ahora SÍ permite seleccionar uno de CADA grupo
                          if (value != null) {
                            _selectedRankingPos[concurso.claveLogica] = value;
                          }
                        });
                        _triggerCalculation(); // Recalcular
                      } : null,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }).toList();
                  
                  // Añadimos la opción "Ninguno"
                  radios.insert(0, RadioListTile<int>(
                    title: const Text('Ninguno', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)), // Letra más chica
                    value: 0, 
                    groupValue: _selectedRankingPos.containsKey(concurso.claveLogica) ? -1 : 0, 
                    onChanged: habilitado ? (int? value) {
                      setState(() {
                        _selectedRankingPos.remove(concurso.claveLogica);
                      });
                      _triggerCalculation();
                    } : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ));
                  
                  return Column(children: radios);
                },
              ),
              const Divider(height: 24),
            ],
          ),
        );
      },
    );
  }

  // --- Lógica de Validación (copiada del backend, para la UI) ---
  String? _checkRequisitos(AdminConcurso regla, Map<String, dynamic> metricas) {
    final minUf = regla.requisitoMinUfTotal;
    final minTasa = regla.requisitoTasaRecaudacion;
    final minContratos = regla.requisitoMinContratos;

    double ufEjecutivo = (metricas['total_uf_general'] as double?) ?? 0.0;
    String ufTipo = "Total General";
    
    if (regla.claveLogica.startsWith('TRAMO_') || regla.claveLogica == 'RANK_SEG') {
      ufEjecutivo = (metricas['total_uf_tramos'] as double?) ?? 0.0;
      ufTipo = "Total Tramos";
    } else if (regla.claveLogica.startsWith('PYME_') || regla.claveLogica == 'RANK_PYME') {
      ufEjecutivo = (metricas['total_uf_pyme'] as double?) ?? 0.0;
      ufTipo = "Total PYME";
    }

    int contratosEjecutivo = (metricas['total_contratos_ref'] as int?) ?? 0;
    final tasaEjecutivo = (metricas['tasa_recaudacion'] as double?) ?? 0.0; 

    if (minUf != null && ufEjecutivo < minUf) {
      return 'Mínimo $minUf UF ($ufTipo)';
    }
    if (minTasa != null && tasaEjecutivo < minTasa) {
      return 'Mínimo $minTasa% Tasa Recaudación';
    }
    if (minContratos != null && contratosEjecutivo < minContratos) {
      return 'Mínimo $minContratos Contratos';
    }
    
    return null; // ¡Pasa todos los requisitos!
  }

  // --- WIDGET PARA LA TARJETA DE RESULTADOS (Arriba) ---
  Widget _buildResultDisplay(Map<String, dynamic>? result) {
    final isLoading = ref.watch(calculationLoadingProvider);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading && result == null)
              const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ))
            else if (result != null)
              ..._buildResultDetails(result) // Mostramos los detalles
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
    );
  }
  
  // --- WIDGET PARA EL SUELDO BASE (Abajo) ---
  Widget _buildSueldoBaseDisplay(num sueldoBase) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListTile(
          leading: Icon(Icons.archive, color: Colors.deepPurple.shade400, size: 28),
          title: const Text('Bono Base (Sueldo Mínimo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Letra más chica
          trailing: Text('\$${numberFormatter.format(sueldoBase)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Letra más chica
        ),
      ),
    );
  }

  // --- Helper para construir los inputs ---
  Widget _buildTextField(TextEditingController controller, String label, {bool isDecimal = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        // --- ¡CAMBIO A "UF$"! ---
        prefixText: label.startsWith('UF') ? 'UF ' : (label.startsWith('N°') ? 'N° ' : null),
        prefixStyle: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold, fontSize: 14), // Letra más chica
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14), // Letra más chica
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Más compacto
      ),
      keyboardType: isDecimal 
          ? const TextInputType.numberWithOptions(decimal: true) 
          : TextInputType.number,
      style: const TextStyle(fontSize: 14), // Letra más chica
    );
  }
  
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.deepPurple.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 16 // Letra más chica
        ),
      ),
    );
  }

  // --- Helper de Desglose (con formato) ---
  List<Widget> _buildResultDetails(Map<String, dynamic> result) {
    
    final bool isLoading = ref.watch(calculationLoadingProvider);
    
    final List<Widget> widgets = [
      Text(
        'Tu Renta Final Simulado:',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.deepPurple.shade800,
          fontSize: 18 // Letra más chica
        ),
        textAlign: TextAlign.center,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '\$${numberFormatter.format(result['renta_final'] ?? 0)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 28 // Letra más chica
                ),
            textAlign: TextAlign.center,
          ),
          if (isLoading)
            const SizedBox(width: 16),
          if (isLoading)
             const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3)),
        ],
      ),
      const SizedBox(height: 16),
      
      // --- Resumen ---
      ListTile(
        title: const Text('Total Bonos'),
        trailing: Text('\$${numberFormatter.format(result['total_bonos'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Letra más chica
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      ListTile(
        title: const Text('Valor UF (usado en cálculo)'),
        trailing: Text('\$${numberFormatter.format(result['valor_uf_usado'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Letra más chica
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          'Desglose del Cálculo:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.deepPurple.shade700, fontSize: 15), // Letra más chica
        ),
      ),
    ];

    // --- Desglose ---
    if (result['desglose'] is List) {
      if ((result['desglose'] as List).isEmpty) {
         widgets.add(
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: Text('- No se generaron bonos este mes.', style: TextStyle(fontSize: 13)), // Letra más chica
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13), // Letra más chica
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }

  // --- ¡NUEVA FUNCIÓN DE IMPRESIÓN/PDF! ---
  Future<void> _printScreen(Map<String, dynamic>? result, Map<String, String> dates) async {
    final doc = pw.Document();
    
    // Captura el estado actual de los controladores
    final inputs = {
      'Tramos P1 (${dates['p1_start']}-${dates['p1_end']})': _ufP1Controller.text,
      'Tramos P2 (${dates['p2_start']}-${dates['p2_end']})': _ufP2Controller.text,
      'PYME Transferencia': _ufPymeTransferenciaController.text,
      'PYME Mandato': _ufPymeMandatoController.text,
      'Referidos P1': _refP1Controller.text,
      'Referidos P2': _refP2Controller.text,
    };
    
    final Map<String, int> rankings = Map.from(_selectedRankingPos);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          
          // --- Helper de Estilos para el PDF ---
          final pw.TextStyle h1 = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple800);
          final pw.TextStyle h2 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700);
          final pw.TextStyle h3 = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700);
          final pw.TextStyle h1Result = pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.green700);
          final pw.TextStyle body = const pw.TextStyle(fontSize: 12);
          final pw.TextStyle bodyBold = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

          // --- Contenido del PDF ---
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Simulación de Renta', style: h1),
              pw.Text('Fecha de Simulación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: body.copyWith(color: PdfColors.grey600)),
              pw.Divider(height: 30),
              
              // --- Sección de Resultados ---
              pw.Text('Renta Final Simulado:', style: h2),
              pw.Text('\$${numberFormatter.format(result?['renta_final'] ?? 0)}', style: h1Result),
              pw.SizedBox(height: 20),
              
              pw.Text('Resumen del Cálculo', style: h3),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Sueldo Base:', style: body),
                pw.Text('\$${numberFormatter.format(result?['sueldo_base'] ?? 0)}', style: bodyBold),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Bonos:', style: body),
                pw.Text('\$${numberFormatter.format(result?['total_bonos'] ?? 0)}', style: bodyBold),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Valor UF usado:', style: body),
                pw.Text('\$${numberFormatter.format(result?['valor_uf_usado'] ?? 0)}', style: bodyBold),
              ]),
              pw.Divider(height: 20),

              // --- Sección de Inputs ---
              pw.Text('Valores Ingresados', style: h3),
              ...inputs.entries.map((entry) => 
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('${entry.key}:', style: body),
                  pw.Text(entry.value.isEmpty ? '0' : entry.value, style: bodyBold),
                ])
              ).toList(),
              
              if (rankings.isNotEmpty)
                ...rankings.entries.map((entry) => 
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Ranking ${entry.key}:', style: body),
                    pw.Text('Posición ${entry.value}', style: bodyBold),
                  ])
                ).toList(),
                
              pw.Divider(height: 20),

              // --- Sección de Desglose ---
              pw.Text('Desglose del Cálculo:', style: h3),
              if (result?['desglose'] is List && (result!['desglose'] as List).isNotEmpty)
                ... (result['desglose'] as List).map((item) => 
                  pw.Text('- $item', style: body)
                ).toList()
              else
                pw.Text('- No se generaron bonos este mes.', style: body),
            ],
          );
        },
      ),
    );
    // Mostrar la pantalla de impresión
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}