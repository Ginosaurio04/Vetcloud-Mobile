import 'package:flutter/material.dart';

import '../data/veterinaria_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identificadorController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identificadorController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final exito = VeterinariaDatabase.instance.autenticar(
      _identificadorController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      final usuario = VeterinariaDatabase.instance.usuarioActual!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido a VetCloud, ${usuario.nombreCompleto}!'),
          backgroundColor: const Color(0xFF0DCF7E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo o cédula no válidos, o contraseña incorrecta. Demo: usa 123456.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _seleccionarUsuarioRapido(String identificador) {
    setState(() {
      _identificadorController.text = identificador;
      _passwordController.text = VeterinariaDatabase.demoPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0DCF7E);
    const darkBg = Color(0xFF14191F);
    final clientes = VeterinariaDatabase.instance.clientes;

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.15),
                        border: Border.all(color: primaryColor, width: 2),
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'VetCloud',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Veterinaria Unimar Móvil',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identificadorController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      label: 'Correo o cédula',
                      hint: 'ej. gino.cova@email.com o V-12345678',
                      icon: Icons.person_outline,
                      color: primaryColor,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa tu correo o cédula'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _iniciarSesion(),
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration(
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                          color: primaryColor,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Ingresa tu contraseña'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _iniciarSesion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2429),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.storage, size: 16, color: primaryColor),
                            SizedBox(width: 6),
                            Text(
                              'Cuentas locales de demostración',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'El SQL no contiene contraseñas. Usa 123456; '
                          'este acceso es solo local y de prueba.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: clientes.map((cliente) {
                            final identificador = cliente.email.isNotEmpty
                                ? cliente.email
                                : cliente.cedula;
                            return ActionChip(
                              avatar: const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.black,
                              ),
                              label: Text(cliente.nombreCompleto),
                              backgroundColor: primaryColor.withValues(
                                alpha: 0.8,
                              ),
                              labelStyle: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              onPressed: () =>
                                  _seleccionarUsuarioRapido(identificador),
                            );
                          }).toList(),
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    required Color color,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: const Color(0xFF1E2429),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    );
  }
}
