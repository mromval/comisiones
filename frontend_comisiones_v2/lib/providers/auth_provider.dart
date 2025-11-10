// lib/providers/auth_provider.dart
import 'dart:convert';
//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- Constantes ---
const String _apiUrl = 'http://localhost:8080';

// --- 0. Modelo de Usuario ---
class Usuario {
  final String id;
  final String nombreCompleto;
  final String email;
  final String rol;

  Usuario({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre_completo': nombreCompleto,
    'email': email,
    'rol': rol,
  };

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'].toString(),
    nombreCompleto: json['nombre_completo'] as String,
    email: json['email'] as String,
    rol: json['rol'] as String,
  );
}


// --- 1. Definición del Estado de Autenticación ---
sealed class AuthState {}
class AuthLoading extends AuthState {}
class AuthError extends AuthState {
  final String error;
  AuthError(this.error);
}
class Authenticated extends AuthState {
  final String token;
  final Usuario usuario;
  Authenticated({required this.token, required this.usuario});
}
class Unauthenticated extends AuthState {}


// --- 2. El "Notificador" (El Cerebro) ---
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthLoading()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    // --- ¡INICIO DE LA CORRECCIÓN! ---
    // Envolvemos todo en un try/catch por si SharedPreferences falla
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final usuarioJson = prefs.getString('authUser'); 

      if (token == null || usuarioJson == null) {
        state = Unauthenticated();
      } else {
        final usuario = Usuario.fromJson(jsonDecode(usuarioJson));
        state = Authenticated(token: token, usuario: usuario);
      }
    } catch (e) {
      // Si algo falla al cargar, simplemente lo mandamos al Login
      print('Error en _tryAutoLogin: $e');
      state = Unauthenticated();
    }
    // --- FIN DE LA CORRECCIÓN ---
  }

  Future<void> login(String email, String password) async {
    try {
      state = AuthLoading();

      final response = await http.post(
        Uri.parse('$_apiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['token'] as String;
        final usuario = Usuario.fromJson(body['usuario'] as Map<String, dynamic>);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        await prefs.setString('authUser', jsonEncode(usuario.toJson()));

        state = Authenticated(token: token, usuario: usuario);
      } else {
        final body = jsonDecode(response.body);
        state = AuthError(body['message'] ?? 'Error al iniciar sesión');
      }
    } catch (e) {
      state = AuthError('Error de red: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('authUser'); 
    state = Unauthenticated();
  }
}


// --- 3. El "Proveedor" (Provider) ---
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});