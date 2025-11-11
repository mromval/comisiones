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
class AdminApiClient {
  final String _token;
  AdminApiClient(this._token);

  // --- Usuarios ---
  Future<List<AdminUser>> getUsuarios() async {
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
  
  // --- Configuracion ---
  Future<List<AdminConfig>> getConfiguracion() async {
    final response = await http.get(
      Uri.parse('$_apiUrl/api/configuracion'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => AdminConfig.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar configuración');
    }
  }
  Future<void> updateConfiguracion(String llave, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_apiUrl/api/configuracion/$llave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar configuración: ${response.body}');
    }
  }
  
  // --- Componentes ---
  Future<List<AdminComponent>> getComponentes() async {
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

  // --- ¡NUEVA FUNCIÓN PARA MÉTRICAS! ---
  Future<void> saveMetrica(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/api/metricas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al guardar métrica: ${response.body}');
    }
  }
}

// --- PROVIDERS ---

final adminApiClientProvider = Provider<AdminApiClient>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return AdminApiClient(authState.token);
  }
  throw UnimplementedError('Cliente API no disponible');
});

// --- Providers de Lectura Simple (FutureProvider) ---

final userListProvider = FutureProvider<List<AdminUser>>((ref) {
  final apiClient = ref.watch(adminApiClientProvider);
  return apiClient.getUsuarios();
});

final componentListProvider = FutureProvider<List<AdminComponent>>((ref) {
  final apiClient = ref.watch(adminApiClientProvider);
  return apiClient.getComponentes();
});

// --- Providers de Notificadores (CRUD Completo) ---
// (UserUpdateNotifier, ConcursoCreateNotifier, TramoListNotifier, ConcursoListNotifier, TeamListNotifier, ProfileListNotifier... sin cambios)

final userUpdateProvider = StateNotifierProvider<UserUpdateNotifier, AsyncValue<void>>((ref) {
  return UserUpdateNotifier(ref);
});
class UserUpdateNotifier extends StateNotifier<AsyncValue<void>> {
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
  return ConcursoCreateNotifier(ref);
});
class ConcursoCreateNotifier extends StateNotifier<AsyncValue<void>> {
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
          // Lógica de merge optimista (requiere .toJson() en el modelo)
          return AdminConcurso.fromJson({
             ...c.toJson(), 
             ...data 
          });
        }
        return c;
      }).toList(),
    );
    try {
      await apiClient.updateConcurso(concursoId, data);
      // Como el merge es complejo, mejor invalidamos
      ref.invalidateSelf();
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

final profileListProvider = AsyncNotifierProvider<ProfileListNotifier, List<AdminProfile>>(
  () => ProfileListNotifier(),
);
class ProfileListNotifier extends AsyncNotifier<List<AdminProfile>> {
  @override
  Future<List<AdminProfile>> build() async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getPerfiles();
  }
  Future<void> addProfile(Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading(); 
    try {
      await apiClient.createProfile(data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> updateProfile(int profileId, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.updateProfile(profileId, data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
  Future<void> removeProfile(int profileId) async {
    final apiClient = ref.read(adminApiClientProvider);
    state = const AsyncLoading();
    try {
      await apiClient.deleteProfile(profileId);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final configListProvider = AsyncNotifierProvider<ConfigListNotifier, List<AdminConfig>>(
  () => ConfigListNotifier(),
);
class ConfigListNotifier extends AsyncNotifier<List<AdminConfig>> {
  @override
  Future<List<AdminConfig>> build() async {
    final apiClient = ref.read(adminApiClientProvider);
    return apiClient.getConfiguracion();
  }
  Future<void> updateConfig(String llave, Map<String, dynamic> data) async {
    final apiClient = ref.read(adminApiClientProvider);
    final previousState = state;
    state = const AsyncLoading();
    try {
      await apiClient.updateConfiguracion(llave, data);
      ref.invalidateSelf(); 
    } catch (e, s) {
      state = AsyncError(e, s);
      state = previousState; 
    }
  }
}

// --- ¡NUEVO PROVIDER PARA LA PANTALLA DE MÉTRICAS! ---
// Usamos un StateProvider simple para manejar el estado de guardado
// (para mostrar un spinner en el botón "Guardar")
final metricSaveLoadingProvider = StateProvider<bool>((ref) => false);