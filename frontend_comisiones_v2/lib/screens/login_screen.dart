import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// Usamos "ConsumerStatefulWidget" para manejar los campos de texto
// y poder usar Riverpod ("Consumer")
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // 1. Llama a la función 'login' de nuestro provider
    ref.read(authProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // 2. "Escuchamos" el estado de nuestro provider
    final authState = ref.watch(authProvider);

    // 3. "Escuchamos" para mostrar errores en un SnackBar
    ref.listen(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Iniciar Sesión',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 24),

                  // 4. Mostramos el botón o un spinner si está cargando
                  if (authState is AuthLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Ingresar'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}