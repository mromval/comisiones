// lib/screens/admin/manage_concursos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/admin_provider.dart';
import 'package:frontend_comisiones_v2/screens/admin/create_concurso_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/edit_tramos_screen.dart';
import 'package:frontend_comisiones_v2/screens/admin/edit_generic_rule_screen.dart';

// Lo convertimos a StatefulWidget para poder usar el TabController
class ManageConcursosScreen extends ConsumerStatefulWidget {
  const ManageConcursosScreen({super.key});

  @override
  ConsumerState<ManageConcursosScreen> createState() => _ManageConcursosScreenState();
}

class _ManageConcursosScreenState extends ConsumerState<ManageConcursosScreen>
    with SingleTickerProviderStateMixin {
      
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Dos pestañas
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenedor de Concursos'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.indigo.shade200,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ACTIVOS', icon: Icon(Icons.check_circle)),
            Tab(text: 'INACTIVOS', icon: Icon(Icons.pause_circle)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Concursos Activos
          _ConcursoListView(isActive: true),
          // Pestaña 2: Concursos Inactivos
          _ConcursoListView(isActive: false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.invalidate(profileListProvider);
          ref.invalidate(componentListProvider);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateConcursoScreen(),
            ),
          );
        },
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Widget reutilizable para mostrar la lista filtrada ---
class _ConcursoListView extends ConsumerWidget {
  final bool isActive;
  const _ConcursoListView({required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConcursos = ref.watch(concursoListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        return ref.refresh(concursoListProvider.future);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: asyncConcursos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error al cargar concursos: $err'),
            ),
          ),
          data: (concursos) {
            final filteredList = concursos
                .where((c) => c.estaActiva == isActive)
                .toList();

            if (filteredList.isEmpty) {
              return Center(child: Text('No se encontraron concursos ${isActive ? "activos" : "inactivos"}.'));
            }
            
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final concurso = filteredList[index];
                        return ConcursoListCard(concurso: concurso);
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


// --- Tarjeta de Concurso (CON LA NAVEGACIÓN MODIFICADA) ---
class ConcursoListCard extends ConsumerWidget {
  const ConcursoListCard({super.key, required this.concurso});
  final AdminConcurso concurso;

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = '${_formatDate(concurso.periodoInicio)} - ${_formatDate(concurso.periodoFin)}';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // --- ¡INICIO DE LA MODIFICACIÓN! ---
        onTap: () {
          // "Router Inteligente"
          switch (concurso.claveLogica) {
            case 'TRAMO_UF':
              Navigator.of(context).push(
                MaterialPageRoute(
                  // 1. Ahora pasamos el objeto 'concurso' completo
                  builder: (context) => EditTramosScreen(
                    concurso: concurso, 
                  ),
                ),
              );
              break;
            case 'FACTOR_FUGA':
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditGenericRuleScreen(concurso: concurso),
                ),
              );
              break;
            default:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('El mantenedor para "${concurso.nombreComponente}" no está implementado aún.'),
                  backgroundColor: Colors.orange,
                ),
              );
          }
        },
        // --- FIN DE LA MODIFICACIÓN ---
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${concurso.nombreComponente} - ${concurso.nombrePerfil}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: concurso.estaActiva,
                    activeColor: Colors.green,
                    onChanged: (bool nuevoValor) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Actualizando estado...'), duration: Duration(seconds: 1)),
                      );
                      ref.read(concursoListProvider.notifier).updateConcurso(
                        concurso.id,
                        {'esta_activa': nuevoValor},
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Periodo: $periodo',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}