import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../widgets/custom_botton_navigation.dart';
import '../config.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogueado;

  const HomeScreen({super.key, this.usuarioLogueado});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future _futureDatosHome;

  final String _baseUrlCitas = '$kApiUrl/api/citas';
  final String _baseUrlClientes = '$kApiUrl/api/clientes';

  @override
  void initState() {
    super.initState();
    _refrescarDashboard();
  }

  void _refrescarDashboard() {
    setState(() {
      _futureDatosHome = _cargarDatosMetrics();
    });
  }

  String _obtenerIniciales(String nombre) {
    if (nombre.trim().isEmpty) return "U";
    final partes = nombre.trim().split(' ');
    if (partes.length > 1 && partes[1].isNotEmpty) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _fechaHoy() {
    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final n = DateTime.now();
    return '${dias[n.weekday - 1]} ${n.day} de ${meses[n.month - 1]}';
  }

  // Normaliza los valores reales del ENUM de MySQL ('En Espera', 'Finalizado', 'Cancelado')
  String _normalizarEstado(dynamic raw) {
    final e = (raw ?? '').toString().trim().toLowerCase();
    switch (e) {
      case '':
      case 'pendiente':
      case 'en espera':
      case 'en consulta':
      case 'en peluquería':
        return 'Pendiente';
      case 'completada':
      case 'completado':
      case 'finalizada':
      case 'finalizado':
        return 'Completada';
      case 'cancelada':
      case 'cancelado':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }

  Future _cargarDatosMetrics() async {
    final resCitas = await http.get(Uri.parse(_baseUrlCitas)).timeout(kApiTimeout);
    final resClientes = await http.get(Uri.parse(_baseUrlClientes)).timeout(kApiTimeout);

    if (resCitas.statusCode == 200 && resClientes.statusCode == 200) {
      final List<dynamic> citas = jsonDecode(resCitas.body);
      final List<dynamic> clientes = jsonDecode(resClientes.body);

      int pendientes = 0;
      int completadas = 0;
      int canceladas = 0;
      Map<String, int> serviciosMap = {};

      for (var c in citas) {
        final String st = _normalizarEstado(c['estado']);

        if (st == 'Pendiente') {
          pendientes++;
        } else if (st == 'Completada') {
          completadas++;
        } else if (st == 'Cancelada') {
          canceladas++;
        }

        final String servicioRaw = c['servicio']?.toString() ?? '';
        final String srv = servicioRaw.trim().isEmpty
            ? 'Consulta General'
            : servicioRaw.trim();
        serviciosMap[srv] = (serviciosMap[srv] ?? 0) + 1;
      }

      return {
        'totalCitas': citas.length,
        'totalClientes': clientes.length,
        'pendientes': pendientes,
        'completadas': completadas,
        'canceladas': canceladas,
        'serviciosMap': serviciosMap,
      };
    } else {
      throw Exception('Error al obtener datos del servidor');
    }
  }

  void _cerrarSesion() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final String nombreUsuario =
        widget.usuarioLogueado?['nombre_completo'] ?? 'Usuario VetCloud';
    final String emailUsuario =
        widget.usuarioLogueado?['email'] ?? 'usuario@vetcloud.com';
    final String primerNombre = nombreUsuario.trim().split(' ').first;

    return Theme(
      data: _Tema.light,
      child: Scaffold(
        backgroundColor: _Pal.bg,
        appBar: _VcAppBar(
          icon: Icons.pets_rounded,
          title: '${_saludo()}, $primerNombre',
          subtitle: _fechaHoy(),
          actions: [
            PopupMenuButton<String>(
              offset: const Offset(0, 52),
              onSelected: (value) {
                if (value == 'logout') {
                  _cerrarSesion();
                } else if (value == 'refresh') {
                  _refrescarDashboard();
                }
              },
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
                child: Text(
                  _obtenerIniciales(nombreUsuario),
                  style: const TextStyle(
                    color: _Pal.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreUsuario,
                        style: const TextStyle(
                          color: _Pal.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        emailUsuario,
                        style: const TextStyle(
                          color: _Pal.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 8),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: _Pal.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Actualizar dashboard'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: _Pal.danger, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Cerrar sesión',
                        style: TextStyle(color: _Pal.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: FutureBuilder(
          future: _futureDatosHome,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _VcLoading();
            } else if (snapshot.hasError) {
              return _VcErrorState(
                message: 'No pudimos cargar el dashboard.\n${snapshot.error}',
                onRetry: _refrescarDashboard,
              );
            }

            final data = snapshot.data!;
            final int pendientes = data['pendientes'];
            final int completadas = data['completadas'];
            final int canceladas = data['canceladas'];
            final Map<String, int> servicios = data['serviciosMap'];
            final int maxBarra =
                [
                  pendientes,
                  completadas,
                  canceladas,
                  5,
                ].reduce((a, b) => a > b ? a : b) +
                2;

            return RefreshIndicator(
              color: _Pal.primary,
              backgroundColor: Colors.white,
              onRefresh: () async => _refrescarDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Clientes',
                            value: '${data['totalClientes']}',
                            icon: Icons.people_alt_rounded,
                            color: _Pal.sky,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            title: 'Total de citas',
                            value: '${data['totalCitas']}',
                            icon: Icons.event_available_rounded,
                            color: _Pal.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    const _VcSectionTitle('Estado de la agenda'),
                    const SizedBox(height: 14),
                    _VcCard(
                      padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
                      child: SizedBox(
                        height: 210,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxBarra.toDouble(),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        '${rod.toY.toInt()} citas',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    switch (value.toInt()) {
                                      case 0:
                                        return Text(
                                          'Pendiente ($pendientes)',
                                          style: TextStyle(
                                            color: _Pal.onTint(_Pal.sun),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        );
                                      case 1:
                                        return Text(
                                          'Completada ($completadas)',
                                          style: TextStyle(
                                            color: _Pal.onTint(_Pal.success),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        );
                                      case 2:
                                        return Text(
                                          'Cancelada ($canceladas)',
                                          style: TextStyle(
                                            color: _Pal.onTint(_Pal.danger),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        );
                                      default:
                                        return const Text('');
                                    }
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              _barra(0, pendientes, _Pal.sun, maxBarra),
                              _barra(1, completadas, _Pal.success, maxBarra),
                              _barra(2, canceladas, _Pal.danger, maxBarra),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    const _VcSectionTitle('Servicios más solicitados'),
                    const SizedBox(height: 14),
                    _VcCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 52,
                                    sections: _generarSeccionesPie(servicios),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${data['totalCitas']}',
                                      style: const TextStyle(
                                        color: _Pal.ink,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Text(
                                      'citas',
                                      style: TextStyle(
                                        color: _Pal.inkSoft,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          ..._generarLeyendaPie(servicios),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: const CustomBottomNavigation(currentIndex: 0),
      ),
    );
  }

  BarChartGroupData _barra(int x, int valor, Color color, int maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: valor.toDouble(),
          color: color,
          width: 34,
          borderRadius: BorderRadius.circular(12),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY.toDouble(),
            color: _Pal.cream,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _generarSeccionesPie(Map<String, int> servicios) {
    if (servicios.isEmpty) {
      return [
        PieChartSectionData(
          color: _Pal.line,
          value: 1,
          title: 'Sin datos',
          radius: 30,
          titleStyle: const TextStyle(
            color: _Pal.inkSoft,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ];
    }

    int i = 0;
    return servicios.entries.map((e) {
      final color = _Pal.chart[i % _Pal.chart.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: e.value.toDouble(),
        title: '${e.value}',
        radius: 30,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  List<Widget> _generarLeyendaPie(Map<String, int> servicios) {
    final maximo = servicios.values.isEmpty
        ? 1
        : servicios.values.reduce((a, b) => a > b ? a : b);

    int i = 0;
    return servicios.entries.map((e) {
      final color = _Pal.chart[i % _Pal.chart.length];
      i++;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.key,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _Pal.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${e.value}',
                  style: TextStyle(
                    color: _Pal.onTint(color),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: e.value / maximo,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _VcCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -16,
            child: Icon(icon, size: 86, color: color.withValues(alpha: 0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VcIconTile(icon: icon, color: color, size: 42),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(
                    color: _Pal.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: _Pal.inkSoft,
                    fontSize: 13,
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

class _VcSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _VcSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          decoration: BoxDecoration(
            color: _Pal.coral,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _Pal.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Etiqueta de sección dentro de formularios.

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
