// lib/providers/admin_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_comisiones_v2/models/admin_data_models.dart';
import 'package:frontend_comisiones_v2/providers/auth_provider.dart';

// --- Constantes ---
const String _apiUrl = 'http://localhost:8080'; // O tu puerto

// --- API Client Interno ---
// (Un helper para todas las llamadas de admin)

class AdminApiClient {
  final String _token;
  AdminApiClient(this._token);

  // --- Usuarios ---
  Future<List<AdminUser>> getUsuarios() async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/usuarios'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminUser.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar usuarios');
    }
  }
  Future<void> updateUser(int userId, Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.put(
      Uri.parse('$_apiUrl/api/usuarios/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al guardar cambios: ${response.body}');
    }
  }
  Future<void> createUser(Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.post(
      Uri.parse('$_apiUrl/api/usuarios'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Error al crear usuario: ${response.body}');
    }
  }

  // --- Equipos ---
  Future<List<AdminTeam>> getEquipos() async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/equipos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminTeam.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar equipos');
    }
  }
  Future<void> createTeam(Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.post(
      Uri.parse('$_apiUrl/api/equipos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Error al crear equipo: ${response.body}');
    }
  }
  Future<void> updateTeam(int teamId, Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.put(
      Uri.parse('$_apiUrl/api/equipos/$teamId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar equipo: ${response.body}');
    }
  }
  Future<void> deleteTeam(int teamId) async {
    // ... (función sin cambios)
    final response = await http.delete(
      Uri.parse('$_apiUrl/api/equipos/$teamId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar equipo: ${response.body}');
    }
  }

  // --- Perfiles ---
  Future<List<AdminProfile>> getPerfiles() async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/perfiles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminProfile.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar perfiles');
    }
  }

  // --- ¡INICIO DE LA MODIFICACIÓN! ---
  // POST /api/perfiles
  Future<void> createProfile(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/api/perfiles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Error al crear perfil: ${response.body}');
    }
  }

  // PUT /api/perfiles/{id}
  Future<void> updateProfile(int profileId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_apiUrl/api/perfiles/$profileId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar perfil: ${response.body}');
    }
  }

  // DELETE /api/perfiles/{id}
  Future<void> deleteProfile(int profileId) async {
    final response = await http.delete(
      Uri.parse('$_apiUrl/api/perfiles/$profileId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar perfil: ${response.body}');
    }
  }
  // --- FIN DE LA MODIFICACIÓN ---

  // --- Componentes ---
  Future<List<AdminComponent>> getComponentes() async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/componentes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminComponent.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar componentes');
    }
  }

  // --- Concursos ---
  Future<List<AdminConcurso>> getConcursos() async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/concursos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminConcurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar concursos');
    }
  }
  Future<void> createConcurso(Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.post(
      Uri.parse('$_apiUrl/api/concursos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Error al crear concurso: ${response.body}');
    }
  }
  Future<void> updateConcurso(int concursoId, Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.put(
      Uri.parse('$_apiUrl/api/concursos/$concursoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar concurso: ${response.body}');
    }
  }
  Future<void> deleteConcurso(int concursoId) async {
    // ... (función sin cambios)
    final response = await http.delete(
      Uri.parse('$_apiUrl/api/concursos/$concursoId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar concurso: ${response.body}');
    }
  }

  // --- Tramos ---
  Future<List<AdminTramo>> getTramos(int concursoId) async {
    // ... (función sin cambios)
    final response = await http.get(
      Uri.parse('$_apiUrl/api/concursos/$concursoId/tramos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminTramo.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar tramos');
    }
  }
  Future<void> createTramo(int concursoId, Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.post(
      Uri.parse('$_apiUrl/api/concursos/$concursoId/tramos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Error al crear tramo: ${response.body}');
    }
  }
  Future<void> updateTramo(int tramoId, Map<String, dynamic> data) async {
    // ... (función sin cambios)
    final response = await http.put(
      Uri.parse('$_apiUrl/api/tramos/$tramoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar tramo: ${response.body}');
    }
  }
  Future<void> deleteTramo(int tramoId) async {
    // ... (función sin cambios)
    final response = await http.delete(
      Uri.parse('$_apiUrl/api/tramos/$tramoId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar tramo: ${response.body}');
    }
  }
}

// --- PROVIDERS ---

final adminApiClientProvider = Provider<AdminApiClient>((ref) {
  // ... (provider sin cambios)
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return AdminApiClient(authState.token);
  }
  throw UnimplementedError('Cliente API no disponible');
});

// --- Providers de Lectura Simple (FutureProvider) ---

final userListProvider = FutureProvider<List<AdminUser>>((ref) {
  // ... (provider sin cambios)
  final apiClient = ref.watch(adminApiClientProvider);
  return apiClient.getUsuarios();
});

final componentListProvider = FutureProvider<List<AdminComponent>>((ref) {
  // ... (provider sin cambios)
  final apiClient = ref.watch(adminApiClientProvider);
  return apiClient.getComponentes();
});

// --- Providers de Notificadores (CRUD Completo) ---

final userUpdateProvider = StateNotifierProvider<UserUpdateNotifier, AsyncValue<void>>((ref) {
  // ... (provider sin cambios)
  return UserUpdateNotifier(ref);
});
class UserUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  // ... (clase sin cambios)
  final Ref _ref;
  UserUpdateNotifier(this._ref) : super(const AsyncData(null)); 
  Future<void> saveChanges(int userId, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      final apiClient = _ref.read(adminApiClientProvider);
      await apiClient.updateUser(userId, data);
      state = const AsyncData(null);
      _ref.invalidate(userListProvider); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final concursoCreateProvider = StateNotifierProvider<ConcursoCreateNotifier, AsyncValue<void>>((ref) {
  // ... (provider sin cambios)
  return ConcursoCreateNotifier(ref);
});
class ConcursoCreateNotifier extends StateNotifier<AsyncValue<void>> {
  // ... (clase sin cambios)
  final Ref _ref;
  ConcursoCreateNotifier(this._ref) : super(const AsyncData(null)); 
  Future<void> saveConcurso(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      final apiClient = _ref.read(adminApiClientProvider);
      await apiClient.createConcurso(data);
      state = const AsyncData(null); 
      _ref.invalidate(concursoListProvider); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final tramoListProvider = AsyncNotifierProvider.family<TramoListNotifier, List<AdminTramo>, int>(
  () => TramoListNotifier(),
);
class TramoListNotifier extends FamilyAsyncNotifier<List<AdminTramo>, int> {
  // ... (clase sin cambios)
  @override
  Future<List<AdminTramo>> build(int concursoId) async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getTramos(concursoId);
  }
  Future<void> addTramo(Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    final concursoId = arg; 
    state = const AsyncLoading();
    try {
      await apiClient.createTramo(concursoId, data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> editTramo(int tramoId, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.updateTramo(tramoId, data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> removeTramo(int tramoId) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.deleteTramo(tramoId);
      ref.invalidateSelf();
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final concursoListProvider = AsyncNotifierProvider<ConcursoListNotifier, List<AdminConcurso>>(
  () => ConcursoListNotifier(),
);
class ConcursoListNotifier extends AsyncNotifier<List<AdminConcurso>> {
  // ... (clase sin cambios)
  @override
  Future<List<AdminConcurso>> build() async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getConcursos();
  }
  Future<void> updateConcurso(int concursoId, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    final previousState = state;
    state = AsyncData(
      state.value!.map((c) {
        if (c.id == concursoId) {
          return AdminConcurso(
            id: c.id,
            periodoInicio: data['periodo_inicio'] ?? c.periodoInicio,
            periodoFin: data['periodo_fin'] ?? c.periodoFin,
            estaActiva: data['esta_activa'] ?? c.estaActiva, 
            nombrePerfil: c.nombrePerfil, 
            nombreComponente: c.nombreComponente,
            claveLogica: c.claveLogica,
            requisitoMinUfTotal: data['requisito_min_uf_total'] ?? c.requisitoMinUfTotal,
            requisitoTasaRecaudacion: data['requisito_tasa_recaudacion'] ?? c.requisitoTasaRecaudacion,
            requisitoMinContratos: data['requisito_min_contratos'] ?? c.requisitoMinContratos,
            topeMonto: data['tope_monto'] ?? c.topeMonto,
          );
        }
        return c;
      }).toList(),
    );
    try {
      await apiClient.updateConcurso(concursoId, data);
    } catch (e) {
      state = previousState;
      throw Exception('Error al actualizar: $e');
    }
  }
  Future<void> toggleStatus(AdminConcurso concurso) async {
    final bool nuevoEstado = !concurso.estaActiva;
    try {
      await updateConcurso(concurso.id, {'esta_activa': nuevoEstado});
    } catch (e) {
      print('Error al cambiar estado: $e');
    }
  }
  Future<void> deleteConcurso(int concursoId) async {
    final apiClient = ref.read(adminApiClientProvider);
    final previousState = state;
    state = AsyncData(
      state.value!.where((c) => c.id != concursoId).toList()
    );
    try {
      await apiClient.deleteConcurso(concursoId);
    } catch (e) {
      state = previousState;
      print('Error al eliminar: $e');
    }
  }
}

final teamListProvider = AsyncNotifierProvider<TeamListNotifier, List<AdminTeam>>(
  () => TeamListNotifier(),
);
class TeamListNotifier extends AsyncNotifier<List<AdminTeam>> {
  // ... (clase sin cambios)
  @override
  Future<List<AdminTeam>> build() async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getEquipos();
  }
  Future<void> addTeam(Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading(); 
    try {
      await apiClient.createTeam(data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> updateTeam(int teamId, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.updateTeam(teamId, data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> removeTeam(int teamId) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.deleteTeam(teamId);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}


// --- ¡INICIO DE LA MODIFICACIÓN! ---
// 1. REEMPLAZAMOS el FutureProvider de Perfiles
// 2. por un AsyncNotifierProvider que SÍ puede hacer CRUD.
final profileListProvider = AsyncNotifierProvider<ProfileListNotifier, List<AdminProfile>>(
  () => ProfileListNotifier(),
);

class ProfileListNotifier extends AsyncNotifier<List<AdminProfile>> {
  
  // El 'build' carga la lista inicial
  @override
  Future<List<AdminProfile>> build() async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getPerfiles();
  }

  // --- Funciones CRUD ---

  Future<void> addProfile(Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading(); // Poner en "cargando"
    try {
      await apiClient.createProfile(data);
      ref.invalidateSelf(); // Recargar la lista
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> updateProfile(int profileId, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.updateProfile(profileId, data);
      ref.invalidateSelf(); // Recargar la lista
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> removeProfile(int profileId) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.deleteProfile(profileId);
      ref.invalidateSelf(); // Recargar la lista
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}
// --- FIN DE LA MODIFICACIÓN ---