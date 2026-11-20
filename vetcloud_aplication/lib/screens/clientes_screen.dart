import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_botton_navigation.dart';
import '../config.dart';

class ClientesScreen extends StatefulWidget {
  final String title;

  const ClientesScreen({super.key, this.title = 'Clientes'});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _searchController = TextEditingController();
  late Future<List<dynamic>> _futureClientes;

  final String _baseUrl = '$kApiUrl/api/clientes';

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() {
    setState(() {
      _futureClientes = _obtenerClientes();
    });
  }

  Future<List> _obtenerClientes() async {
    final res = await http.get(Uri.parse(_baseUrl)).timeout(kApiTimeout);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception('Error al conectar con el servidor');
    }
  }

  Future<void> _guardarNuevoCliente(Map<String, dynamic> clienteData) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(clienteData),
    ).timeout(kApiTimeout);

    if (res.statusCode == 201) {
      _cargarClientes();
      if (mounted) {
        _vcSnack(
          context,
          'Cliente registrado exitosamente',
          type: _VcSnackType.success,
        );
      }
    } else {
      if (mounted) {
        final err = jsonDecode(res.body);
        _vcSnack(
          context,
          err['error'] ?? 'Error al guardar el cliente',
          type: _VcSnackType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalAgregarCliente(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final cedulaCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();

    // Campos detallados de la Mascota
    final nombreMascotaCtrl = TextEditingController();
    final especieMascotaCtrl = TextEditingController(text: 'Perro');
    final razaMascotaCtrl = TextEditingController();
    final edadMascotaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _VcSheetHandle(),
                  const _VcSheetHeader(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Registrar cliente y mascota',
                    subtitle: 'Los campos con * son obligatorios',
                  ),
                  const SizedBox(height: 24),

                  // DATOS DEL CLIENTE
                  const _VcFormLabel(
                    'Datos del propietario',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: cedulaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cédula / ID *',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'La Cédula es obligatoria'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'El Nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico *',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'El Email es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: direccionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de habitación *',
                      prefixIcon: Icon(Icons.home_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'La Dirección es obligatoria'
                        : null,
                  ),

                  const SizedBox(height: 26),

                  // DATOS DETALLADOS DE LA MASCOTA
                  const _VcFormLabel('Información de la mascota'),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: nombreMascotaCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la mascota',
                      prefixIcon: Icon(Icons.pets_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: especieMascotaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especie',
                            hintText: 'Perro / Gato',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: razaMascotaCtrl,
                          decoration: const InputDecoration(labelText: 'Raza'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: edadMascotaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Edad de la mascota',
                      prefixIcon: Icon(Icons.cake_rounded),
                    ),
                  ),

                  const SizedBox(height: 26),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Guardar registro completo'),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(ctx);
                        _guardarNuevoCliente({
                          'cedula': cedulaCtrl.text.trim(),
                          'nombre': nombreCtrl.text.trim(),
                          'telefono': telefonoCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'direccion': direccionCtrl.text.trim(),
                          'mascota': nombreMascotaCtrl.text.trim().isEmpty
                              ? 'Sin Registro'
                              : '${nombreMascotaCtrl.text.trim()} (${especieMascotaCtrl.text.trim()} - ${razaMascotaCtrl.text.trim()})',
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _colorAvatar(String nombre) {
    final colores = [
      _Pal.primary,
      _Pal.coral,
      _Pal.sky,
      _Pal.lilac,
      _Pal.sun,
      _Pal.success,
    ];
    final h = nombre.codeUnits.fold<int>(0, (a, b) => a + b);
    return colores[h % colores.length];
  }

  void _mostrarDetalleCliente(
    BuildContext context,
    Map<String, dynamic> cliente,
  ) {
    final String nombre = (cliente['nombre'] ?? 'Cliente').toString();
    final color = _colorAvatar(nombre);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: color,
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Pal.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const _VcBadge(label: 'Cliente VetCloud', color: _Pal.primary),
              const SizedBox(height: 18),
              _itemDetalle(
                Icons.badge_rounded,
                'Cédula',
                cliente['cedula'] ?? 'N/A',
              ),
              _itemDetalle(
                Icons.phone_rounded,
                'Teléfono',
                cliente['telefono'] ?? 'N/A',
              ),
              _itemDetalle(
                Icons.alternate_email_rounded,
                'Email',
                cliente['email'] ?? 'N/A',
              ),
              _itemDetalle(
                Icons.home_rounded,
                'Dirección',
                cliente['direccion'] ?? 'N/A',
              ),
              _itemDetalle(
                Icons.pets_rounded,
                'Mascota',
                cliente['mascota'] ?? 'Sin Mascota',
                color: _Pal.coral,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemDetalle(
    IconData icon,
    String label,
    String val, {
    Color color = _Pal.primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _VcIconTile(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _Pal.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  val,
                  style: const TextStyle(
                    color: _Pal.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _Tema.light,
      child: Scaffold(
        backgroundColor: _Pal.bg,
        appBar: const _VcAppBar(
          icon: Icons.groups_rounded,
          title: 'Directorio de clientes',
          subtitle: 'Propietarios y sus mascotas',
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirModalAgregarCliente(context),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Nuevo cliente'),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _futureClientes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _VcLoading();
            } else if (snapshot.hasError) {
              return _VcErrorState(
                message: 'No pudimos cargar los clientes.\n${snapshot.error}',
                onRetry: _cargarClientes,
              );
            }

            final clientes = snapshot.data ?? [];
            final query = _searchController.text.trim().toLowerCase();

            final clientesFiltrados = clientes.where((c) {
              final nombre = (c['nombre'] ?? '').toString().toLowerCase();
              final telefono = (c['telefono'] ?? '').toString().toLowerCase();
              final mascota = (c['mascota'] ?? '').toString().toLowerCase();
              final cedula = (c['cedula'] ?? '').toString().toLowerCase();
              return query.isEmpty ||
                  nombre.contains(query) ||
                  telefono.contains(query) ||
                  cedula.contains(query) ||
                  mascota.contains(query);
            }).toList();

            final mascotasReg = clientes
                .where((c) => (c['mascota'] ?? '').toString().isNotEmpty)
                .length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _VcStatStrip(
                    stats: [
                      _VcStat(
                        label: 'Clientes',
                        value: '${clientes.length}',
                        color: _Pal.sky,
                        icon: Icons.people_alt_rounded,
                      ),
                      _VcStat(
                        label: 'Mascotas',
                        value: '$mascotasReg',
                        color: _Pal.coral,
                        icon: Icons.pets_rounded,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _VcSearchField(
                    controller: _searchController,
                    hint: 'Buscar por nombre, cédula, teléfono o mascota',
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                ),

                Expanded(
                  child: clientesFiltrados.isEmpty
                      ? const _VcEmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'No encontramos clientes',
                          message:
                              'Registra un nuevo cliente o cambia tu búsqueda.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: clientesFiltrados.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cliente = clientesFiltrados[index];
                            final nombre = (cliente['nombre'] ?? 'Sin Nombre')
                                .toString();
                            final telefono =
                                cliente['telefono'] ?? 'Sin Teléfono';
                            final mascota = cliente['mascota'] ?? 'Sin Mascota';
                            final color = _colorAvatar(nombre);

                            return _VcCard(
                              onTap: () =>
                                  _mostrarDetalleCliente(context, cliente),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: color,
                                    child: Text(
                                      nombre.isNotEmpty
                                          ? nombre[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 21,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _Pal.ink,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_rounded,
                                              color: _Pal.inkMuted,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '$telefono',
                                              style: const TextStyle(
                                                color: _Pal.inkSoft,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _VcInfoPill(
                                          icon: Icons.pets_rounded,
                                          text: '$mascota',
                                          color: _Pal.coral,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _Pal.inkMuted,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: const CustomBottomNavigation(currentIndex: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estilo visual VetCloud (privado de este archivo)
// ─────────────────────────────────────────────────────────────────────────────
class _Pal {
  _Pal._();

  // Marca
  static const primary = Color(0xFF4D9699); // turquesa (el del login original)
  static const primaryDark = Color(0xFF2F7377);
  static const primaryDeep = Color(0xFF1E4F54);
  static const primarySoft = Color(0xFFE3F1F1);

  // Superficies
  static const bg = Color(0xFFFEFCF3); // marfil
  static const surface = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFEF8E6);
  static const line = Color(0xFFEDE6CF);

  // Texto
  static const ink = Color(0xFF22343A);
  static const inkSoft = Color(0xFF5F6F73);
  static const inkMuted = Color(0xFF9AA5A8);

  // Acentos semánticos
  static const sun = Color(0xFFF2B33D); // pendiente / aviso
  static const success = Color(0xFF3E9E6F); // completado / ok
  static const coral = Color(0xFFF2836B); // acento cálido
  static const danger = Color(0xFFE0564B); // cancelado / error
  static const sky = Color(0xFF5B9BD5); // clientes / info
  static const lilac = Color(0xFF9B87D9); // extra

  static const chart = [primary, sun, coral, sky, lilac, success];

  /// Versión más oscura de un color para usarla como texto sobre su propio tinte.
  static Color onTint(Color c) =>
      HSLColor.fromColor(c).withLightness(0.28).withSaturation(0.6).toColor();
}

class _Sombras {
  _Sombras._();

  static const soft = [
    BoxShadow(color: Color(0x142F7377), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const lifted = [
    BoxShadow(color: Color(0x262F7377), blurRadius: 28, offset: Offset(0, 14)),
  ];
}

class _Tema {
  _Tema._();

  /// Para usar una tipografía propia: declara 'Nunito' (o la que prefieras)
  /// en pubspec.yaml. Si no está declarada, Flutter usa la fuente del sistema.
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: _Pal.ink,
        titleTextStyle: _s(20, FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: _Pal.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _Pal.line),
        ),
      ),
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _Pal.primaryDark,
          textStyle: _s(14, FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _Pal.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        extendedTextStyle: _s(14, FontWeight.w800, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _Pal.surface,
        selectedColor: _Pal.primary,
        side: const BorderSide(color: _Pal.line),
        showCheckmark: false,
        labelStyle: _s(13, FontWeight.w700),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _Pal.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: _s(19, FontWeight.w800),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _Pal.surface,
        modalBackgroundColor: _Pal.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _Pal.ink,
        contentTextStyle: _s(14, FontWeight.w700, color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _Pal.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: const Color(0x332F7377),
        textStyle: _s(14, FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _Pal.primary,
        linearTrackColor: _Pal.primarySoft,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: _Pal.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: _Pal.primary,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: _Pal.surface,
        dialBackgroundColor: _Pal.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      // Si tu CustomBottomNavigation usa NavigationBar / BottomNavigationBar,
      // tomará este estilo automáticamente.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _Pal.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _Pal.primarySoft,
        elevation: 10,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _s(
            12,
            s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? _Pal.primaryDark
                : _Pal.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? _Pal.primaryDark
                : _Pal.inkMuted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _Pal.surface,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _Pal.primaryDark,
        unselectedItemColor: _Pal.inkMuted,
        selectedLabelStyle: _s(12, FontWeight.w800),
        unselectedLabelStyle: _s(12, FontWeight.w600),
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

/// Degradado de marca reutilizable.

const _vcBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_Pal.primaryDeep, _Pal.primaryDark, _Pal.primary],
);

// ─────────────────────────────────────────────────────────────────────────────
// Cabecera de marca (reemplaza al AppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _VcAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> actions;
  final Widget? bottom;
  final double bottomHeight;

  const _VcAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.pets_rounded,
    this.actions = const [],
    this.bottom,
    this.bottomHeight = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(96 + bottomHeight);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          gradient: _vcBrandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          boxShadow: _Sombras.lifted,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          child: CustomPaint(
            painter: const _PawPainter(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 10, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  if (bottom != null) ...[const SizedBox(height: 14), bottom!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular translúcido para la cabecera.

class _VcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool clip;

  const _VcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 22,
    this.clip = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (clip) content = ClipRRect(borderRadius: br, child: content);
    return Container(
      decoration: BoxDecoration(
        color: color ?? _Pal.surface,
        borderRadius: br,
        border: Border.all(color: borderColor ?? _Pal.line),
        boxShadow: _Sombras.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(borderRadius: br, onTap: onTap, child: content),
      ),
    );
  }
}

/// Icono dentro de un cuadrado redondeado teñido.

class _VcIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _VcIconTile({
    super.key,
    required this.icon,
    this.color = _Pal.primary,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: _Pal.onTint(color), size: size * 0.5),
    );
  }
}

/// Etiqueta de estado (píldora con punto).

class _VcBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const _VcBadge({
    super.key,
    required this.label,
    required this.color,
    this.dot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: _Pal.onTint(color),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dato pequeño con icono (fecha, hora, servicio…).

class _VcInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _VcInfoPill({
    super.key,
    required this.icon,
    required this.text,
    this.color = _Pal.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Pal.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Pal.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Franja de estadísticas
// ─────────────────────────────────────────────────────────────────────────────

class _VcStat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _VcStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _VcStatStrip extends StatelessWidget {
  final List<_VcStat> stats;
  const _VcStatStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      if (i > 0) {
        children.add(Container(width: 1, height: 38, color: _Pal.line));
      }
      children.add(
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 18, color: s.color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  s.value,
                  style: TextStyle(
                    color: _Pal.onTint(s.color),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                s.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Pal.inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _VcCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Búsqueda y filtros
// ─────────────────────────────────────────────────────────────────────────────

class _VcSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const _VcSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: _Sombras.soft,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: _Pal.ink, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: _Pal.surface,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isNotEmpty && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _Pal.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _Pal.line),
          ),
        ),
      ),
    );
  }
}

class _VcFormLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _VcFormLabel(this.text, {super.key, this.icon = Icons.pets_rounded});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _Pal.coral),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: _Pal.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estados: vacío / error / cargando
// ─────────────────────────────────────────────────────────────────────────────

class _VcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const _VcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _Pal.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _Pal.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Pal.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Pal.inkSoft,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VcErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const _VcErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _Pal.coral.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _Pal.coral),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ups, algo salió mal',
              style: TextStyle(
                color: _Pal.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Pal.inkSoft,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VcLoading extends StatelessWidget {
  const _VcLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _Pal.primary, strokeWidth: 3.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hojas modales
// ─────────────────────────────────────────────────────────────────────────────

class _VcSheetHandle extends StatelessWidget {
  const _VcSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _Pal.line,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _VcSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _VcSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _VcIconTile(icon: icon, size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _Pal.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _Pal.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mensajes
// ─────────────────────────────────────────────────────────────────────────────

enum _VcSnackType { success, error, warning, info }

void _vcSnack(
  BuildContext context,
  String message, {
  _VcSnackType type = _VcSnackType.info,
  Color? color,
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
    case _VcSnackType.warning:
      c = _Pal.sun;
      icon = Icons.warning_amber_rounded;
    case _VcSnackType.info:
      c = _Pal.primaryDark;
      icon = Icons.info_rounded;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color ?? c,
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
