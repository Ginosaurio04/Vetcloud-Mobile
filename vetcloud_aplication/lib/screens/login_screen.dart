import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/cliente.dart';
import '../config.dart';

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

    final url = Uri.parse('$kApiUrl/api/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _identificadorController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      ).timeout(kApiTimeout);

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          (data['exito'] == true || data['cliente'] != null)) {
        final cliente = Cliente.fromMap(data['cliente']);

        _vcSnack(
          context,
          '¡Bienvenido a VetCloud, ${cliente.nombreCompleto}!',
          type: _VcSnackType.success,
        );

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _vcSnack(
          context,
          data['mensaje'] ?? 'Usuario o contraseña incorrectos',
          type: _VcSnackType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _vcSnack(
        context,
        'Error de conexión con el servidor: $e',
        type: _VcSnackType.error,
        seconds: 4,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _abrirModalRegistro() {
    final regFormKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscureRegPass = true;
    bool isRegistering = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _Pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> registrarUsuario() async {
              if (!regFormKey.currentState!.validate()) return;

              setModalState(() => isRegistering = true);

              final url = Uri.parse('$kApiUrl/api/register');

              try {
                final response = await http.post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'username': usernameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                  }),
                ).timeout(kApiTimeout);

                final data = jsonDecode(response.body);

                if (!ctx.mounted) return;

                if (response.statusCode == 201 && data['exito'] == true) {
                  Navigator.pop(ctx);
                  _identificadorController.text = usernameCtrl.text.trim();
                  _passwordController.clear();
                  _vcSnack(
                    this.context,
                    '¡Usuario registrado! Ya puedes iniciar sesión.',
                    type: _VcSnackType.success,
                  );
                } else {
                  _vcSnack(
                    this.context,
                    data['mensaje'] ?? 'No se pudo registrar el usuario',
                    type: _VcSnackType.error,
                  );
                }
              } catch (e) {
                if (this.context.mounted) {
                  _vcSnack(
                    this.context,
                    'Error de conexión: $e',
                    type: _VcSnackType.error,
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setModalState(() => isRegistering = false);
                }
              }
            }

            return Theme(
              data: _Tema.light,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 22,
                  right: 22,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: regFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: _Pal.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _Pal.primarySoft,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: _Pal.primaryDark,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nuevo Usuario',
                                    style: TextStyle(
                                      color: _Pal.ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Crea una cuenta de acceso al sistema',
                                    style: TextStyle(
                                      color: _Pal.inkSoft,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: usernameCtrl,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Usuario o Cédula',
                            hintText: 'ej. admin_vet o V-12345678',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Ingresa un nombre de usuario'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            hintText: 'ej. doctor@vetcloud.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa un correo electrónico';
                            }
                            if (!v.contains('@')) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: obscureRegPass,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => registrarUsuario(),
                          style: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: 'Mínimo 4 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureRegPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setModalState(
                                () => obscureRegPass = !obscureRegPass,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Ingresa una contraseña';
                            }
                            if (v.length < 4) {
                              return 'Debe tener al menos 4 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: isRegistering ? null : registrarUsuario,
                          icon: isRegistering
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            isRegistering
                                ? 'Registrando...'
                                : 'Registrar usuario',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _Tema.light,
      child: Scaffold(
        backgroundColor: _Pal.bg,
        body: SingleChildScrollView(
          child: Stack(
            children: [
              // ── Cabecera de marca ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 330,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: _vcBrandGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(44),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(44),
                    ),
                    child: CustomPaint(
                      painter: const _PawPainter(),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 24,
                                        offset: Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.pets_rounded,
                                    size: 46,
                                    color: _Pal.primary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'VetCloud',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Veterinaria Unimar Móvil',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tarjeta del formulario ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 248, 20, 28),
                child: Form(
                  key: _formKey,
                  child: _VcCard(
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Bienvenido de nuevo',
                          style: TextStyle(
                            color: _Pal.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ingresa para gestionar citas, clientes y más.',
                          style: TextStyle(
                            color: _Pal.inkSoft,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _identificadorController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Correo o cédula',
                            hintText: 'ej. gino.cova@email.com o V-12345678',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Ingresa tu correo o cédula'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _iniciarSesion(),
                          style: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa tu contraseña'
                              : null,
                        ),
                        const SizedBox(height: 26),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _iniciarSesion,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Iniciar sesión'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _abrirModalRegistro,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 19,
                            color: _Pal.primaryDark,
                          ),
                          label: const Text(
                            'Crear nuevo usuario',
                            style: TextStyle(color: _Pal.primaryDark),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: _Pal.coral,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cuidamos de ellos, como tú',
                              style: TextStyle(
                                color: _Pal.inkMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estilo visual VetCloud
// ─────────────────────────────────────────────────────────────────────────────
class _Pal {
  _Pal._();

  static const primary = Color(0xFF4D9699);
  static const primaryDark = Color(0xFF2F7377);
  static const primaryDeep = Color(0xFF1E4F54);
  static const primarySoft = Color(0xFFE3F1F1);

  static const bg = Color(0xFFFEFCF3);
  static const surface = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFEF8E6);
  static const line = Color(0xFFEDE6CF);

  static const ink = Color(0xFF22343A);
  static const inkSoft = Color(0xFF5F6F73);
  static const inkMuted = Color(0xFF9AA5A8);

  static const success = Color(0xFF3E9E6F);
  static const coral = Color(0xFFF2836B);
  static const danger = Color(0xFFE0564B);
}

class _Sombras {
  _Sombras._();

  static const soft = [
    BoxShadow(color: Color(0x142F7377), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

class _Tema {
  _Tema._();

  static const fontFamily = 'Nunito';

  static TextStyle _s(
    double size,
    FontWeight w, {
    Color color = _Pal.ink,
    double? ls,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
    height: height,
  );

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _Pal.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _Pal.primary,
          onPrimary: Colors.white,
          primaryContainer: _Pal.primarySoft,
          onPrimaryContainer: _Pal.primaryDeep,
          secondary: _Pal.coral,
          surface: _Pal.surface,
          onSurface: _Pal.ink,
          error: _Pal.danger,
          outline: _Pal.line,
        );

    final text = TextTheme(
      displaySmall: _s(34, FontWeight.w900, ls: -0.5),
      headlineMedium: _s(26, FontWeight.w800, ls: -0.3),
      headlineSmall: _s(22, FontWeight.w800, ls: -0.2),
      titleLarge: _s(19, FontWeight.w800, ls: -0.2),
      titleMedium: _s(16, FontWeight.w700),
      titleSmall: _s(14, FontWeight.w700),
      bodyLarge: _s(16, FontWeight.w500, height: 1.35),
      bodyMedium: _s(14, FontWeight.w500, height: 1.35),
      bodySmall: _s(12, FontWeight.w500, color: _Pal.inkSoft),
      labelLarge: _s(15, FontWeight.w800),
      labelMedium: _s(12, FontWeight.w700),
      labelSmall: _s(11, FontWeight.w700, color: _Pal.inkSoft),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: _Pal.bg,
      canvasColor: _Pal.surface,
      dividerColor: _Pal.line,
      dividerTheme: const DividerThemeData(
        color: _Pal.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: _Pal.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _Pal.cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: _s(14, FontWeight.w600, color: _Pal.inkSoft),
        floatingLabelStyle: _s(14, FontWeight.w800, color: _Pal.primaryDark),
        hintStyle: _s(14, FontWeight.w500, color: _Pal.inkMuted),
        errorStyle: _s(12, FontWeight.w700, color: _Pal.danger),
        prefixIconColor: _Pal.primary,
        suffixIconColor: _Pal.inkMuted,
        border: border(_Pal.line),
        enabledBorder: border(_Pal.line),
        focusedBorder: border(_Pal.primary, 1.8),
        errorBorder: border(_Pal.danger),
        focusedErrorBorder: border(_Pal.danger, 1.8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _Pal.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _Pal.line,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: _s(15, FontWeight.w800, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _Pal.ink,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: _Pal.line, width: 1.4),
          textStyle: _s(14, FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _Pal.ink,
        contentTextStyle: _s(14, FontWeight.w700, color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _PawPainter extends CustomPainter {
  final Color color;
  const _PawPainter({this.color = const Color(0x14FFFFFF)});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;

    void paw(Offset c, double s, double rot) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 7 * s),
          width: 22 * s,
          height: 17 * s,
        ),
        p,
      );
      for (final o in [
        Offset(-12 * s, -5 * s),
        Offset(-4.5 * s, -13 * s),
        Offset(4.5 * s, -13 * s),
        Offset(12 * s, -5 * s),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: o, width: 8 * s, height: 11 * s),
          p,
        );
      }
      canvas.restore();
    }

    paw(Offset(size.width * 0.86, size.height * 0.32), 1.7, 0.45);
    paw(Offset(size.width * 0.60, size.height * 0.80), 1.0, -0.35);
    paw(Offset(size.width * 0.95, size.height * 0.88), 1.2, 0.2);
    paw(Offset(size.width * 0.40, size.height * 0.20), 0.8, -0.5);
    paw(Offset(size.width * 0.08, size.height * 0.75), 1.1, 0.35);
  }

  @override
  bool shouldRepaint(covariant _PawPainter oldDelegate) =>
      oldDelegate.color != color;
}

const _vcBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_Pal.primaryDeep, _Pal.primaryDark, _Pal.primary],
);

class _VcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _VcCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: _Pal.surface,
        borderRadius: br,
        border: Border.all(color: _Pal.line),
        boxShadow: _Sombras.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum _VcSnackType { success, error }

void _vcSnack(
  BuildContext context,
  String message, {
  required _VcSnackType type,
  int seconds = 3,
}) {
  final Color c;
  final IconData icon;
  switch (type) {
    case _VcSnackType.success:
      c = _Pal.success;
      icon = Icons.check_circle_rounded;
    case _VcSnackType.error:
      c = _Pal.danger;
      icon = Icons.error_rounded;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: c,
        duration: Duration(seconds: seconds),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
