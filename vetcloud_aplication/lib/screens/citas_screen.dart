import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../widgets/custom_botton_navigation.dart';

class CitasScreen extends StatefulWidget {
  final String title;

  const CitasScreen({super.key, this.title = 'Citas Medicas'});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final _searchController = TextEditingController();
  late Future<List<dynamic>> _futureCitas;
  List<dynamic> _clientesMascotas = [];
  String _filtroEstado = 'Todos';

  // URLs de los endpoints de Node.js
  final String _baseUrl = 'http://localhost:3000/api/citas';
  final String _baseUrlClientesMascotas =
      'http://localhost:3000/api/clientes-mascotas-citas';

  // Estado del Calendario
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _mostrarCalendario = false;

  final List<String> _servicios = [
    'Consulta General',
    'Vacunación',
    'Desparasitación',
    'Peluquería / Baño',
    'Cirugía / Esterilización',
    'Exámenes de Laboratorio',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarCitas();
    _cargarClientes();
  }

  void _cargarCitas() {
    setState(() {
      _futureCitas = _obtenerCitas();
    });
  }

  Future<void> _cargarClientes() async {
    try {
      final res = await http.get(Uri.parse(_baseUrlClientesMascotas));
      if (res.statusCode == 200) {
        final List<dynamic> body = jsonDecode(res.body);
        setState(() {
          _clientesMascotas = body;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar opciones de citas: $e');
    }
  }

  Future<List<dynamic>> _obtenerCitas() async {
    final res = await http.get(Uri.parse(_baseUrl));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Error al cargar la agenda de citas');
    }
  }

  Future<void> _guardarNuevaCita(Map<String, dynamic> citaData) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(citaData),
    );

    if (res.statusCode == 201) {
      _cargarCitas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita agendada exitosamente en MySQL'),
            backgroundColor: Color(0xFF0DCF7E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la cita'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cambiarEstadoCita(int id, String nuevoEstado) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/$id/estado'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'estado': nuevoEstado}),
    );

    if (res.statusCode == 200) {
      _cargarCitas();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalAgendarCita(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    int? idMascotaSeleccionada;
    final notasCtrl = TextEditingController();

    String servicioSeleccionado = _servicios.first;
    DateTime fechaSeleccionada = DateTime.now();
    TimeOfDay horaSeleccionada = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2429),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month, color: Color(0xFF0DCF7E)),
                          SizedBox(width: 8),
                          Text(
                            'Agendar Nueva Cita',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1. DESPLEGABLE DE CLIENTE Y MASCOTA
                      DropdownButtonFormField<int>(
                        value: idMascotaSeleccionada,
                        dropdownColor: const Color(0xFF1E2429),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Cliente y Mascota *',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(
                            Icons.person,
                            color: Color(0xFF0DCF7E),
                          ),
                        ),
                        items: _clientesMascotas.map((c) {
                          final idMascota = c['id_mascota'] as int?;
                          final nombreCliente = c['nombre'] ?? 'Cliente';
                          final nombreMascota =
                              c['nombre_mascota'] ?? 'Sin Mascota';
                          final especie = c['especie'] ?? '';

                          return DropdownMenuItem<int>(
                            value: idMascota,
                            child: Text(
                              '$nombreCliente - $nombreMascota ($especie)',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => idMascotaSeleccionada = val);
                        },
                        validator: (v) => v == null
                            ? 'Selecciona un cliente y su mascota'
                            : null,
                      ),
                      const SizedBox(height: 10),

                      // 2. SELECCIÓN DE SERVICIO VETERINARIO
                      DropdownButtonFormField<String>(
                        value: servicioSeleccionado,
                        dropdownColor: const Color(0xFF1E2429),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Servicio Veterinario',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(
                            Icons.medical_services,
                            color: Color(0xFF0DCF7E),
                          ),
                        ),
                        items: _servicios
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => servicioSeleccionado = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3. SELECTORES DE FECHA Y HORA
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.event,
                                color: Color(0xFF0DCF7E),
                                size: 18,
                              ),
                              label: Text(
                                '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: fechaSeleccionada,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(
                                    () => fechaSeleccionada = picked,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.access_time,
                                color: Color(0xFF0DCF7E),
                                size: 18,
                              ),
                              label: Text(
                                horaSeleccionada.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: horaSeleccionada,
                                );
                                if (picked != null) {
                                  setModalState(
                                    () => horaSeleccionada = picked,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: notasCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Notas / Observaciones',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(
                            Icons.notes,
                            color: Color(0xFF0DCF7E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. BOTÓN Y VALIDACIÓN DE FECHA
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0DCF7E),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final ahora = DateTime.now();
                            final citaDateTime = DateTime(
                              fechaSeleccionada.year,
                              fechaSeleccionada.month,
                              fechaSeleccionada.day,
                              horaSeleccionada.hour,
                              horaSeleccionada.minute,
                            );

                            if (citaDateTime.isBefore(ahora)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se puede agendar una cita en un horario que ya pasó',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);

                            final fechaFormatted =
                                "${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}";
                            final horaFormatted =
                                "${horaSeleccionada.hour.toString().padLeft(2, '0')}:${horaSeleccionada.minute.toString().padLeft(2, '0')}:00";

                            _guardarNuevaCita({
                              'id_mascota': idMascotaSeleccionada,
                              'servicio': servicioSeleccionado,
                              'fecha': fechaFormatted,
                              'hora': horaFormatted,
                              'notas': notasCtrl.text.trim().isEmpty
                                  ? 'Sin observaciones'
                                  : notasCtrl.text.trim(),
                            });
                          }
                        },
                        child: const Text(
                          'Confirmar Cita',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
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
    const primaryColor = Color(0xFF0DCF7E);
    const darkBg = Color(0xFF14191F);
    const cardBg = Color(0xFF1E2429);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: const Text(
          'Agenda de Citas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _mostrarCalendario ? Icons.list_alt : Icons.calendar_month,
              color: primaryColor,
            ),
            tooltip: _mostrarCalendario ? 'Ver Lista' : 'Ver Calendario',
            onPressed: () {
              setState(() {
                _mostrarCalendario = !_mostrarCalendario;
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _abrirModalAgendarCita(context),
        child: const Icon(Icons.add_task, color: Colors.black),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureCitas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error al conectar con la BD:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarCitas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          }

          final citas = snapshot.data ?? [];
          final query = _searchController.text.trim().toLowerCase();

          // 1. Filtrado de lista general con estado seguro
          final citasFiltradas = citas.where((c) {
            final cliente = (c['cliente'] ?? '').toString().toLowerCase();
            final mascota = (c['mascota'] ?? '').toString().toLowerCase();
            final servicio = (c['servicio'] ?? '').toString().toLowerCase();

            final rawEst = c['estado']?.toString().trim();
            final estado = (rawEst == null || rawEst.isEmpty)
                ? 'Pendiente'
                : rawEst;
            final fecha = (c['fecha'] ?? '').toString();

            final coincideBusqueda =
                query.isEmpty ||
                cliente.contains(query) ||
                mascota.contains(query) ||
                servicio.contains(query);
            final coincideEstado =
                _filtroEstado == 'Todos' || estado == _filtroEstado;

            bool coincideFecha = true;
            if (_mostrarCalendario && _selectedDay != null) {
              final fechaSelFormatted =
                  "${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}";
              coincideFecha = fecha == fechaSelFormatted;
            }

            return coincideBusqueda && coincideEstado && coincideFecha;
          }).toList();

          // 2. Métricas del banner superior con evaluación segura
          final pendientes = citas.where((c) {
            final rawEst = c['estado']?.toString().trim();
            final st = (rawEst == null || rawEst.isEmpty)
                ? 'Pendiente'
                : rawEst;
            return st == 'Pendiente';
          }).length;

          final completadas = citas
              .where((c) => c['estado']?.toString().trim() == 'Completada')
              .length;

          return Column(
            children: [
              // Banner métrico
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: cardBg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatMini(
                      label: 'Total Citas',
                      valor: '${citas.length}',
                      color: primaryColor,
                    ),
                    Container(height: 24, width: 1, color: Colors.white12),
                    _StatMini(
                      label: 'Pendientes',
                      valor: '$pendientes',
                      color: Colors.orangeAccent,
                    ),
                    Container(height: 24, width: 1, color: Colors.white12),
                    _StatMini(
                      label: 'Completadas',
                      valor: '$completadas',
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ),

              // Vista de Calendario
              if (_mostrarCalendario) ...[
                TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    defaultTextStyle: TextStyle(color: Colors.white),
                    weekendTextStyle: TextStyle(color: Colors.white54),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonTextStyle: TextStyle(color: Colors.white),
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
              ],

              // Buscador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente, mascota o servicio...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: primaryColor),
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Filtros por Estado
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['Todos', 'Pendiente', 'Completada', 'Cancelada']
                      .map((estado) {
                        final sel = estado == _filtroEstado;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(estado),
                            selected: sel,
                            selectedColor: primaryColor,
                            backgroundColor: cardBg,
                            labelStyle: TextStyle(
                              color: sel ? Colors.black : Colors.white70,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setState(() => _filtroEstado = estado),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Lista de Citas
              Expanded(
                child: citasFiltradas.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay citas registradas para este filtro.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: citasFiltradas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cita = citasFiltradas[index];
                          final id = cita['id'];
                          final cliente =
                              cita['cliente'] ?? 'Cliente Desconocido';
                          final mascota = cita['mascota'] ?? 'Mascota';
                          final servicio = cita['servicio'] ?? 'Consulta';
                          final fecha = cita['fecha'] ?? '';
                          final hora = cita['hora'] ?? '';

                          // Asignación ultra protegida del estado
                          final rawEstado = cita['estado']?.toString().trim();
                          final estado =
                              (rawEstado == null || rawEstado.isEmpty)
                              ? 'Pendiente'
                              : rawEstado;

                          Color badgeColor = Colors.orangeAccent;
                          if (estado == 'Completada') badgeColor = primaryColor;
                          if (estado == 'Cancelada') {
                            badgeColor = Colors.redAccent;
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pets,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$mascota ($cliente)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: badgeColor,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        estado,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  servicio,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      color: Colors.white38,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      fecha,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.white38,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hora,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),

                                    if (estado == 'Pendiente') ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: primaryColor,
                                          size: 22,
                                        ),
                                        tooltip: 'Marcar Completada',
                                        onPressed: () => _cambiarEstadoCita(
                                          id,
                                          'Completada',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.cancel,
                                          color: Colors.redAccent,
                                          size: 22,
                                        ),
                                        tooltip: 'Cancelar Cita',
                                        onPressed: () =>
                                            _cambiarEstadoCita(id, 'Cancelada'),
                                      ),
                                    ],
                                  ],
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
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 3),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _StatMini({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
