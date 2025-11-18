// lib/screens/admin/import_users_screen.dart
import 'dart:convert'; // Para utf8
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Para el botón de descarga

// Convertimos a StatefulWidget para manejar el estado de carga
class ImportUsersScreen extends ConsumerStatefulWidget {
  const ImportUsersScreen({super.key});

  @override
  ConsumerState<ImportUsersScreen> createState() => _ImportUsersScreenState();
}

class _ImportUsersScreenState extends ConsumerState<ImportUsersScreen> {
  bool _isLoading = false;
  String? _fileName;

  // Lógica para seleccionar y procesar el archivo
  Future<void> _pickAndProcessFile() async {
    // 1. Limpiamos resultados anteriores
    ref.read(importResultProvider.notifier).state = null;
    setState(() {
      _isLoading = true;
      _fileName = null;
    });

    try {
      // 2. Abrir el diálogo de selección de archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // ¡Crucial para web!
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        setState(() {
          _fileName = file.name;
        });

        // 3. Convertir los bytes del archivo a un String UTF-8
        final String csvData = utf8.decode(file.bytes!);

        // 4. Llamar al provider de la API
        final apiClient = ref.read(adminApiClientProvider);
        final importResult = await apiClient.importarUsuariosCSV(csvData);

        // 5. Guardar el resumen (éxito o error) en el provider
        ref.read(importResultProvider.notifier).state = importResult;
      } else {
        // Usuario canceló la selección
        setState(() {
          _fileName = null;
        });
      }
    } catch (e) {
      // Si la API o la lectura del archivo falla, lo mostramos
      ref.read(importResultProvider.notifier).state = {
        'usuariosCreados': 0,
        'erroresEncontrados': 1,
        'detalleErrores': ['Error: ${e.toString()}'],
      };
    } finally {
      // 6. Quitar el spinner
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- ¡NUEVA FUNCIÓN PARA DESCARGAR LA PLANTILLA! ---
  Future<void> _launchTemplateURL() async {
    // La ruta debe coincidir con la definida en pubspec.yaml
    final Uri url = Uri.parse('assets/assets/plantilla_importacion.csv');
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar la plantilla: No se pudo abrir $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cargamos los providers de ayuda
    final asyncProfiles = ref.watch(profileListProvider);
    final asyncTeams = ref.watch(teamListProvider);
    // Escuchamos el resultado de la importación
    final importResult = ref.watch(importResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Usuarios (Masivo)'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 6,
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListView(
                padding: const EdgeInsets.all(32.0),
                children: [
                  Text(
                    'Importación Masiva de Usuarios',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.indigo.shade800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // --- ¡TEXTO ACTUALIZADO! ---
                  const Text(
                    'Sube un archivo .CSV (separado por coma ",") con las siguientes columnas en este orden:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // --- ¡TEXTO ACTUALIZADO! ---
                  const Chip(
                    label: Text('nombre_completo,email,password,rol,nombre_perfil,nombre_equipo'),
                    backgroundColor: Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  
                  // --- ¡NUEVO BOTÓN DE DESCARGA! ---
                  TextButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Descargar plantilla .CSV'),
                    onPressed: _launchTemplateURL,
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Botón de Subida ---
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.file_upload),
                          label: Text(_fileName ?? 'Seleccionar Archivo .CSV'),
                          onPressed: _pickAndProcessFile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(20),
                          ),
                        ),
                  
                  // --- Sección de Resumen de Resultados ---
                  if (importResult != null)
                    _buildResultSummary(context, importResult),

                  const Divider(height: 48, thickness: 1),

                  // --- Sección de Ayuda ---
                  Text(
                    '📋 Ayuda: Nombres Válidos (Puedes seleccionar y copiar el texto)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.indigo.shade800),
                  ),
                  
                  // --- ¡NUEVA AYUDA DE ROL! ---
                  const SizedBox(height: 24),
                  Text(
                    'Roles Disponibles:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _buildHelpList(const ['ejecutivo', 'supervisor', 'admin']),

                  const SizedBox(height: 24),
                  Text(
                    'Perfiles Disponibles:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  asyncProfiles.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, s) => Text('Error al cargar perfiles: $e', style: const TextStyle(color: Colors.red)),
                    data: (profiles) => _buildHelpList(profiles.map((p) => p.nombrePerfil).toList()),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Equipos Disponibles (opcional):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  asyncTeams.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, s) => Text('Error al cargar equipos: $e', style: const TextStyle(color: Colors.red)),
                    data: (teams) => _buildHelpList(teams.map((t) => t.nombreEquipo).toList()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- ¡HELPER MODIFICADO! ---
  // Ahora usa SelectableText para que se pueda copiar.
  Widget _buildHelpList(List<String> items) {
    if (items.isEmpty) {
      return const Text(' (Ninguno encontrado)', style: TextStyle(fontStyle: FontStyle.italic));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        items.join('  |  '), // Los separamos con ' | '
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
      ),
    );
  }

  // Widget helper para mostrar el resumen de la importación
  Widget _buildResultSummary(BuildContext context, Map<String, dynamic> result) {
    final int creados = result['usuariosCreados'] ?? 0;
    final int errores = result['erroresEncontrados'] ?? 0;
    final List<dynamic> detalles = result['detalleErrores'] ?? [];

    final bool hasErrors = errores > 0;
    final Color color = hasErrors ? Colors.red.shade700 : Colors.green.shade700;

    return Container(
      margin: const EdgeInsets.only(top: 24.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: hasErrors ? Colors.red.shade50 : Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasErrors ? 'Importación completada con errores' : 'Importación Exitosa',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 16),
          Text(
            '✔️ Usuarios Creados: $creados',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            '❌ Errores Encontrados: $errores',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: hasErrors ? color : Colors.black,
            ),
          ),
          if (hasErrors)
            const Divider(height: 24),
          if (hasErrors)
            Text(
              'Detalle de Errores:',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          if (hasErrors)
            ...detalles.map((error) => Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0),
              child: SelectableText( // Lo hacemos seleccionable también
                '- $error',
                style: TextStyle(color: Colors.red.shade900),
              ),
            )),
        ],
      ),
    );
  }
}