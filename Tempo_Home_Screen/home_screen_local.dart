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

// --- Provider de Datos de UI (sin cambios) ---
final homeScreenDataProvider = FutureProvider((ref) async {
  final authState = ref.watch(authProvider);
  String? userProfileName;
  
  if (authState is Authenticated) {
    userProfileName = authState.usuario.nombrePerfil;
  }

  final configData = await ref.watch(configListProvider.future);
  final concursos = await ref.watch(concursoListProvider.future);

  String format(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '??';
    try {
      final parsedDate = DateTime.parse(isoDate);
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) { return '??'; }
  }
  final Map<String, String> dates = {
    'p1_start': format(configData.firstWhere((c) => c.llave == 'FECHA_INICIO_P1', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p1_end': format(configData.firstWhere((c) => c.llave == 'FECHA_FIN_P1', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p2_start': format(configData.firstWhere((c) => c.llave == 'FECHA_INICIO_P2', orElse: () => AdminConfig(llave: '', valor: '')).valor),
    'p2_end': format(configData.firstWhere((c) => c.llave == 'FECHA_FIN_P2', orElse: () => AdminConfig(llave: '', valor: '')).valor),
  };

  final rankingConcursos = concursos.where(
    (c) => 
      c.estaActiva && 
      c.claveLogica.startsWith('RANK_') &&
      c.nombrePerfil == userProfileName
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
  // Controladores
  final _ufP1Controller = TextEditingController();
  final _ufP2Controller = TextEditingController();
  final _ufPymeTransferenciaController = TextEditingController();
  final _ufPymeMandatoController = TextEditingController();
  final _refP1Controller = TextEditingController();
  final _refP2Controller = TextEditingController();
  
  final Map<String, int> _selectedRankingPos = {};
  
  late final List<TextEditingController> _controllers;
  final numberFormatter = NumberFormat.decimalPattern('es_CL');
  Timer? _debounce;

  // --- (Lógica de Cálculo sin cambios) ---
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
      'sim_rankings': _selectedRankingPos, 
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

  // --- (initState y dispose sin cambios) ---
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
      ref.read(homeScreenDataProvider.future); 
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
  // --- (Fin de initState/dispose) ---

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationResultProvider);
    final uiDataAsync = ref.watch(homeScreenDataProvider);
    
    final authState = ref.watch(authProvider);
    final String executiveName = (authState is Authenticated) ? authState.usuario.nombreCompleto : 'Usuario';
    final String? userProfileName = (authState is Authenticated) ? authState.usuario.nombrePerfil : null;

    return Scaffold(
      appBar: AppBar(
        // --- INICIO REQUERIMIENTO 1 (AppBar) ---
        leadingWidth: 250, // Damos más espacio al 'leading'
        leading: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              "Simulador de Renta Variable", // Título a la izquierda
              style: TextStyle(fontSize: 16, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        title: Text('Bienvenido, $executiveName'), // Bienvenida centrada
        centerTitle: true,
        // --- FIN REQUERIMIENTO 1 ---
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printScreen(result, (uiDataAsync.valueOrNull?['dates'] as Map<String, String>?) ?? {}, executiveName),
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
        
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- COLUMNA IZQUIERDA (Inputs + Valor UF + Disclaimer) ---
                  Expanded(
                    flex: 1, 
                    child: Column(
                      children: [
                        uiDataAsync.when(
                          loading: () => const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          )),
                          error: (e, s) => Center(child: Text('Error al cargar datos: $e')),
                          data: (data) {
                            final dates = data['dates'] as Map<String, String>;
                            return _buildInputsCard(dates); 
                          }
                        ),
                        const SizedBox(height: 24),
                        _buildFooterInfo(result),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),

                  // --- COLUMNA DERECHA (Resultados y Ranking) ---
                  Expanded(
                    flex: 2, 
                    child: Column( 
                      children: [
                        _buildResultDisplay(result),
                        const SizedBox(height: 24),
                        uiDataAsync.when(
                          loading: () => const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          )),
                          error: (e, s) => Center(child: Text('Error al cargar datos: $e')),
                          data: (data) {
                            final rankingConcursos = data['rankingConcursos'] as List<AdminConcurso>;
                            
                            // --- INICIO REQUERIMIENTO 2 (Tab Order) ---
                            // Envolvemos el ranking en su propio grupo de foco
                            return FocusTraversalGroup(
                              child: _buildRankingCard(result, rankingConcursos, userProfileName),
                            );
                            // --- FIN REQUERIMIENTO 2 ---
                          }
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget _buildInputsCard (MODIFICADO) ---
  Widget _buildInputsCard(Map<String, String> dates) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        // --- INICIO REQUERIMIENTO 2 (Tab Order) ---
        // Envolvemos la columna de inputs en un grupo de foco
        // para asegurar que se complete antes de saltar.
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Período 1: ${dates['p1_start']} al ${dates['p1_end']}',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'Período 2: ${dates['p2_start']} al ${dates['p2_end']}',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              
              Text('Concursos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple.shade800, fontSize: 22)),
              const Divider(height: 24),
              
              _buildSectionTitle(context, 'Tramos UF (Venta Seguros y convenios individuales)'),
              _buildTextField(_ufP1Controller, 'Ventas Período 1'),
              const SizedBox(height: 16),
              _buildTextField(_ufP2Controller, 'Ventas Período 2'),
              
              const Divider(height: 32),
              _buildSectionTitle(context, 'PYME (Convenios tipo pago primera prima)'),
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
        // --- FIN REQUERIMIENTO 2 ---
      ),
    );
  }

  // --- (Widget _buildRankingCard sin cambios) ---
  Widget _buildRankingCard(Map<String, dynamic>? result, List<AdminConcurso> rankingConcursos, String? userProfileName) {
    final Map<String, dynamic> metricas = result?['debug_metricas_usadas'] ?? {};
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ranking (simula tu puesto)', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple.shade800, fontSize: 22)),
            const Divider(height: 24),
            
            if (rankingConcursos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('No se encontraron concursos de Ranking activos para tu perfil (${userProfileName ?? "No definido"}).'),
              ),
              
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...['RANK_SEG', 'RANK_PYME', 'RANK_ISAPRE'].map((claveLogica) {
                  
                  AdminConcurso? concurso;
                  try {
                    concurso = rankingConcursos.firstWhere(
                      (c) => c.claveLogica == claveLogica && c.nombrePerfil == userProfileName
                    );
                  } catch (e) {
                    concurso = null;
                  }

                  if (concurso == null) {
                    return Expanded(flex: 1, child: const SizedBox());
                  }

                  final String? motivoFallo = _checkRequisitos(concurso, metricas);
                  final bool habilitado = (motivoFallo == null);

                  return Expanded(
                    flex: 1, 
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildRankingGroup(concurso, habilitado, motivoFallo),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- (Widget _buildRankingGroup sin cambios) ---
  Widget _buildRankingGroup(AdminConcurso concurso, bool habilitado, String? motivoFallo) {
    return Consumer(
      builder: (context, widgetRef, child) {
        final asyncTramos = widgetRef.watch(tramoListProvider(concurso.id));
        
        return Opacity(
          opacity: habilitado ? 1.0 : 0.5,
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
                  final radios = tramos.map((tramo) {
                    String label = '${tramo.tramoDesdeUf.toInt()}°';
                    if (tramo.tramoHastaUf.toInt() != tramo.tramoDesdeUf.toInt()) {
                      label += ' - ${tramo.tramoHastaUf.toInt()}° Lugar';
                    } else {
                      label += ' Lugar';
                    }
                    label += ': \$${numberFormatter.format(tramo.montoPago)}.-';
                    
                    final int posValue = tramo.tramoDesdeUf.toInt();

                    return RadioListTile<int>(
                      title: Text(label, style: const TextStyle(fontSize: 13)),
                      value: posValue,
                      groupValue: _selectedRankingPos[concurso.claveLogica],
                      onChanged: habilitado ? (int? value) {
                        setState(() {
                          if (value != null) {
                            _selectedRankingPos[concurso.claveLogica] = value;
                          }
                        });
                        _triggerCalculation();
                      } : null,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }).toList();
                  
                  radios.insert(0, RadioListTile<int>(
                    title: const Text('Ninguno', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
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
            ],
          ),
        );
      },
    );
  }

  // --- (Widget _checkRequisitos sin cambios) ---
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
    
    return null;
  }

  // --- (Widget _buildResultDisplay sin cambios) ---
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
              ..._buildResultDetails(result)
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

  // --- (Widget _buildFooterInfo sin cambios) ---
  Widget _buildFooterInfo(Map<String, dynamic>? result) {
    final valorUf = (result?['valor_uf_usado'] as num?) ?? 0;
    const String disclaimer = 'Este es un simulador. Los valores son referenciales y no implican obligación de pago ni liquidación final de renta.';

    return Column(
      children: [
        if (result != null) // Solo muestra la UF si hay un resultado
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Valor UF del Día (usado en cálculo): \$${numberFormatter.format(valorUf)}.-',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          disclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  // --- (Helpers _buildTextField y _buildSectionTitle sin cambios) ---
  Widget _buildTextField(TextEditingController controller, String label, {bool isDecimal = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixText: label.startsWith('UF') ? 'UF ' : (label.startsWith('N°') ? 'N° ' : null),
        prefixStyle: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold, fontSize: 14),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: isDecimal 
          ? const TextInputType.numberWithOptions(decimal: true) 
          : TextInputType.number,
      style: const TextStyle(fontSize: 14),
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
          fontSize: 16
        ),
      ),
    );
  }
  // --- (Fin de Helpers) ---


  // --- (Helper _buildResultDetails sin cambios, ya tenía el "Total Bonos" quitado) ---
  List<Widget> _buildResultDetails(Map<String, dynamic> result) { 
    
    final bool isLoading = ref.watch(calculationLoadingProvider);
    
    final List<Widget> widgets = [
      Text(
        'Tu Renta Variable Simulada:',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.deepPurple.shade800,
          fontSize: 18
        ),
        textAlign: TextAlign.center,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '\$${numberFormatter.format(result['renta_final'] ?? 0)}.-', 
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 28
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
      
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          'Desglose del Cálculo:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.deepPurple.shade700, fontSize: 15),
        ),
      ),
    ];

    if (result['desglose'] is List) {
      if ((result['desglose'] as List).isEmpty) {
         widgets.add(
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: Text('- No se generaron bonos este mes.', style: TextStyle(fontSize: 13)),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }

  // --- (Función de Impresión/PDF sin cambios) ---
  Future<void> _printScreen(Map<String, dynamic>? result, Map<String, String> dates, String executiveName) async {
    final doc = pw.Document();
    
    final inputs = {
      'Tramos P1 (${dates['p1_start']}-${dates['p1_end']})': _ufP1Controller.text,
      'Tramos P2 (${dates['p2_start']}-${dates['p2_end']})': _ufP2Controller.text,
      'PYME Transferencia': _ufPymeTransferenciaController.text,
      'PYME Mandato': _ufPymeMandatoController.text,
      'Referidos P1': _refP1Controller.text,
      'Referidos P2': _refP2Controller.text,
    };
    
    final Map<String, int> rankings = Map.from(_selectedRankingPos);
    
    const String disclaimer = 'Este es un simulador. Los valores son referenciales y no implican obligación de pago ni liquidación final de renta.';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          
          final pw.TextStyle h1 = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple800);
          final pw.TextStyle h2 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700);
          final pw.TextStyle h3 = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700);
          final pw.TextStyle h1Result = pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.green700);
          final pw.TextStyle body = const pw.TextStyle(fontSize: 12);
          final pw.TextStyle bodyBold = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Simulación de Renta Variable', style: h1),
              pw.Text('Fecha de Simulación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: body.copyWith(color: PdfColors.grey600)),
              pw.Text('Ejecutivo: $executiveName', style: body.copyWith(color: PdfColors.grey600)),
              pw.Divider(height: 30),
              
              pw.Text('Total Renta Variable Simulada:', style: h2),
              pw.Text('\$${numberFormatter.format(result?['renta_final'] ?? 0)}.-', style: h1Result),
              pw.SizedBox(height: 20),
              
              pw.Text('Resumen del Cálculo', style: h3),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Bonos:', style: body),
                pw.Text('\$${numberFormatter.format(result?['total_bonos'] ?? 0)}.-', style: bodyBold),
              ]),
              pw.Divider(height: 20),

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

              pw.Text('Desglose del Cálculo:', style: h3),
              if (result?['desglose'] is List && (result!['desglose'] as List).isNotEmpty)
                ... (result['desglose'] as List).map((item) {
                  String itemText = item as String;
                  final matches = RegExp(r'\$([\d\.]+)').allMatches(itemText);
                  for (final m in matches.toList().reversed) {
                    final numString = m.group(1)!.replaceAll('.', '');
                    final numValue = int.tryParse(numString) ?? 0;
                    final formattedNum = '\$${numberFormatter.format(numValue)}.-';
                    itemText = itemText.replaceRange(m.start, m.end, formattedNum);
                  }
                  return pw.Text('- $itemText', style: body.copyWith(fontWeight: pw.FontWeight.bold));
                }).toList()
              else
                pw.Text('- No se generaron bonos este mes.', style: body),
                
              pw.Spacer(),
              pw.Divider(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Valor UF del Día (usado en cálculo):', style: body),
                pw.Text('\$${numberFormatter.format(result?['valor_uf_usado'] ?? 0)}.-', style: bodyBold),
              ]),
              pw.SizedBox(height: 8),
              pw.Text(
                disclaimer,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}