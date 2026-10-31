import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../widgets/custom_botton_navigation.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogueado;

  const HomeScreen({super.key, this.usuarioLogueado});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future _futureDatosHome;

  final String _baseUrlCitas = 'http://localhost:3000/api/citas';
  final String _baseUrlClientes = 'http://localhost:3000/api/clientes';

  @override
  void initState() {
    super.initState();
    _futureDatosHome = _cargarDatosMetrics();
  }

  String _obtenerIniciales(String nombre) {
    if (nombre.trim().isEmpty) return "U";
    final partes = nombre.trim().split(' ');
    if (partes.length > 1 && partes[1].isNotEmpty) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  Future _cargarDatosMetrics() async {
    final resCitas = await http.get(Uri.parse(_baseUrlCitas));
    final resClientes = await http.get(Uri.parse(_baseUrlClientes));

    if (resCitas.statusCode == 200 && resClientes.statusCode == 200) {
      final List<dynamic> citas = jsonDecode(resCitas.body);
      final List<dynamic> clientes = jsonDecode(resClientes.body);

      int pendientes = 0;
      int completadas = 0;
      int canceladas = 0;
      Map<String, int> serviciosMap = {};

      for (var c in citas) {
        final String estadoRaw = c['estado']?.toString() ?? '';
        final String st = estadoRaw.trim().isEmpty
            ? 'Pendiente'
            : estadoRaw.trim();

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
    const primaryColor = Color(0xFF0DCF7E);
    const darkBg = Color(0xFF14191F);
    const cardBg = Color(0xFF1E2429);

    final String nombreUsuario =
        widget.usuarioLogueado?['nombre_completo'] ?? 'Usuario VetCloud';
    final String emailUsuario =
        widget.usuarioLogueado?['email'] ?? 'usuario@vetcloud.com';

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        automaticallyImplyLeading:
            false, // 👈 Quita la flecha automática "Back"
        leading: const Padding(
          padding: EdgeInsets.only(left: 12.0),
          child: Icon(
            Icons.pets, // 👈 Icono de la pata de la mascota
            color: primaryColor,
            size: 26,
          ),
        ),
        title: const Text(
          'VetCloud Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: PopupMenuButton<String>(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              offset: const Offset(0, 45),
              onSelected: (value) {
                if (value == 'logout') {
                  _cerrarSesion();
                } else if (value == 'refresh') {
                  setState(() {
                    _futureDatosHome = _cargarDatosMetrics();
                  });
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor,
                child: Text(
                  _obtenerIniciales(nombreUsuario),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        emailUsuario,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 16),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: primaryColor, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Actualizar Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _futureDatosHome,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar dashboard:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final data = snapshot.data!;
          final int pendientes = data['pendientes'];
          final int completadas = data['completadas'];
          final int canceladas = data['canceladas'];
          final Map<String, int> servicios = data['serviciosMap'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Clientes',
                        value: '${data['totalClientes']}',
                        icon: Icons.people,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Citas',
                        value: '${data['totalCitas']}',
                        icon: Icons.calendar_month,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  'Estado de la Agenda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          ([
                                    pendientes,
                                    completadas,
                                    canceladas,
                                    5,
                                  ].reduce((a, b) => a > b ? a : b) +
                                  2)
                              .toDouble(),
                      barTouchData: const BarTouchData(enabled: false),
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
                                  return const Text(
                                    'Pendiente',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 11,
                                    ),
                                  );
                                case 1:
                                  return const Text(
                                    'Completada',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 11,
                                    ),
                                  );
                                case 2:
                                  return const Text(
                                    'Cancelada',
                                    style: TextStyle(
                                      color: Colors.redAccent,
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
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: pendientes.toDouble(),
                              color: Colors.orangeAccent,
                              width: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: completadas.toDouble(),
                              color: primaryColor,
                              width: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 2,
                          barRods: [
                            BarChartRodData(
                              toY: canceladas.toDouble(),
                              color: Colors.redAccent,
                              width: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Servicios Más Solicitados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: _generarSeccionesPie(servicios),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: _generarLeyendaPie(servicios),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 0),
    );
  }

  List<PieChartSectionData> _generarSeccionesPie(Map<String, int> servicios) {
    if (servicios.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 1,
          title: 'Sin datos',
          radius: 35,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ];
    }

    final colores = [
      const Color(0xFF0DCF7E),
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
    ];

    int i = 0;
    return servicios.entries.map((e) {
      final color = colores[i % colores.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: e.value.toDouble(),
        title: '${e.value}',
        radius: 35,
        titleStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  List<Widget> _generarLeyendaPie(Map<String, int> servicios) {
    final colores = [
      const Color(0xFF0DCF7E),
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
    ];

    int i = 0;
    return servicios.entries.map((e) {
      final color = colores[i % colores.length];
      i++;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            e.key,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2429),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
