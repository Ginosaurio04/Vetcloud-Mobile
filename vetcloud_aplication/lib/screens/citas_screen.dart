import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import '../widgets/custom_botton_navigation.dart';
import '../services/notification_service.dart';
import '../config.dart';

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

  final String _baseUrl = '$kApiUrl/api/citas';
  final String _baseUrlClientesMascotas =
      '$kApiUrl/api/clientes-mascotas-citas';

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
      final res = await http.get(Uri.parse(_baseUrlClientesMascotas)).timeout(kApiTimeout);
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
    final res = await http.get(Uri.parse(_baseUrl)).timeout(kApiTimeout);
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
    ).timeout(kApiTimeout);

    if (res.statusCode == 201) {
      final body = jsonDecode(res.body);
      final int citaId =
          body['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      _cargarCitas();

      // 🔔 NOTIFICACIÓN: Confirmación al agendar
      await _notificar(
        id: citaId,
        titulo: '📅 Cita Agendada Exitosamente',
        cuerpo:
            'Se ha registrado la cita para el servicio de ${citaData['servicio']}.',
      );

      if (mounted) {
        _vcSnack(
          context,
          'Cita agendada exitosamente',
          type: _VcSnackType.success,
        );
      }
    } else {
      if (mounted) {
        _vcSnack(
          context,
          'Error al registrar la cita',
          type: _VcSnackType.error,
        );
      }
    }
  }

  // Normaliza el estado que viene de MySQL (acepta Completado/Completada, etc.
  // y trata vacío/NULL como Pendiente).
  String _normalizarEstado(dynamic raw) {
    final e = (raw ?? '').toString().trim();
    switch (e.toLowerCase()) {
      case '':
      case 'pendiente':
      case 'en espera':
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
        return e;
    }
  }

  void _mostrarSnack(String mensaje, Color color, {int segundos = 3}) {
    if (!mounted) return;
    _vcSnack(
      context,
      mensaje,
      type: color == _Pal.danger ? _VcSnackType.error : _VcSnackType.success,
      seconds: segundos,
    );
  }

  // Las notificaciones nunca deben romper el flujo de la pantalla
  Future<void> _notificar({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      await NotificationService.mostrarNotificacionInmediata(
        id: id,
        titulo: titulo,
        cuerpo: cuerpo,
      );
    } catch (e) {
      debugPrint('Notificación no disponible: $e');
    }
  }

  Future<bool> _enviarEstado(int id, String estado) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/$id/estado'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'estado': estado}),
    ).timeout(kApiTimeout);
    return res.statusCode == 200 || res.statusCode == 204;
  }

  // Lee de la BD el estado real de una cita (para confirmar que se guardó)
  Future<String?> _leerEstadoCita(int id, {bool crudo = false}) async {
    final citas = await _obtenerCitas();
    for (final c in citas) {
      if (c['id'].toString() == id.toString()) {
        return crudo
            ? (c['estado'] ?? '').toString().trim()
            : _normalizarEstado(c['estado']);
      }
    }
    return null;
  }

  Future<void> _cambiarEstadoCita(dynamic idRaw, String nuevoEstado) async {
    final int? id = int.tryParse(idRaw.toString());
    if (id == null) {
      _mostrarSnack('ID de cita inválido', _Pal.danger);
      return;
    }

    // El ENUM de citas.estado en MySQL es: 'En Espera', 'En Consulta',
    // 'En Peluquería', 'Finalizado', ... Un valor que no esté en el ENUM se
    // guarda como '' sin error, así que se verifica lo guardado y se prueba
    // con la siguiente variante.
    final variantes = nuevoEstado == 'Completada'
        ? ['Finalizado', 'Finalizada', 'Completado', 'Completada']
        : ['Cancelado', 'Cancelada'];

    try {
      bool guardado = false;
      final previo = await _leerEstadoCita(id, crudo: true);

      for (final valor in variantes) {
        final ok = await _enviarEstado(id, valor);
        if (!ok) {
          _mostrarSnack(
            'Error al actualizar la cita en el servidor',
            _Pal.danger,
          );
          return;
        }
        final actual = await _leerEstadoCita(id);
        if (actual == nuevoEstado) {
          guardado = true;
          break;
        }
      }

      if (!guardado) {
        // Los intentos fallidos dejan el estado en blanco: se restaura el anterior
        final restaurar =
            (previo == null || previo.isEmpty || previo == 'Pendiente')
            ? 'En Espera'
            : previo;
        await _enviarEstado(id, restaurar);
      }

      if (!mounted) return;
      _cargarCitas(); // refresca la lista con lo que realmente hay en la BD

      if (!guardado) {
        _mostrarSnack(
          'No se pudo guardar: el ENUM de citas.estado no tiene un valor para "$nuevoEstado"',
          _Pal.danger,
          segundos: 5,
        );
        return;
      }

      if (nuevoEstado == 'Completada') {
        await _notificar(
          id: id,
          titulo: '✅ Cita Finalizada',
          cuerpo: 'La cita #$id fue marcada como Completada.',
        );
      } else {
        await _notificar(
          id: id,
          titulo: '❌ Cita Cancelada',
          cuerpo: 'La cita #$id ha sido cancelada.',
        );
        try {
          await NotificationService.cancelarNotificacion(id);
        } catch (e) {
          debugPrint('No se pudo cancelar la notificación: $e');
        }
      }

      _mostrarSnack(
        'Cita marcada como $nuevoEstado',
        nuevoEstado == 'Completada' ? _Pal.success : _Pal.danger,
        segundos: 2,
      );
    } catch (e) {
      debugPrint('Error en _cambiarEstadoCita: $e');
      _mostrarSnack('Error de conexión con el servidor: $e', _Pal.danger);
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        icon: Icons.event_available_rounded,
                        title: 'Agendar nueva cita',
                        subtitle: 'Completa los datos para reservar',
                      ),
                      const SizedBox(height: 22),

                      DropdownButtonFormField<int>(
                        value: idMascotaSeleccionada,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(18),
                        decoration: const InputDecoration(
                          labelText: 'Cliente y mascota *',
                          prefixIcon: Icon(Icons.person_rounded),
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
                              style: const TextStyle(fontSize: 13.5),
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
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: servicioSeleccionado,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(18),
                        decoration: const InputDecoration(
                          labelText: 'Servicio veterinario',
                          prefixIcon: Icon(Icons.medical_services_rounded),
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
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                backgroundColor: _Pal.cream,
                              ),
                              icon: const Icon(
                                Icons.event_rounded,
                                color: _Pal.primary,
                                size: 20,
                              ),
                              label: Text(
                                '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}',
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                backgroundColor: _Pal.cream,
                              ),
                              icon: const Icon(
                                Icons.schedule_rounded,
                                color: _Pal.primary,
                                size: 20,
                              ),
                              label: Text(horaSeleccionada.format(context)),
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
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: notasCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas / observaciones',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Confirmar cita'),
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
                              _vcSnack(
                                context,
                                'No se puede agendar una cita en un horario que ya pasó',
                                type: _VcSnackType.error,
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

  Color _colorEstado(String estado) {
    if (estado == 'Completada') return _Pal.success;
    if (estado == 'Cancelada') return _Pal.danger;
    return _Pal.sun;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _Tema.light,
      child: Scaffold(
        backgroundColor: _Pal.bg,
        appBar: _VcAppBar(
          icon: Icons.event_note_rounded,
          title: 'Agenda de citas',
          subtitle: _mostrarCalendario
              ? 'Vista de calendario'
              : 'Consultas, vacunas y más',
          actions: [
            _VcHeaderAction(
              icon: _mostrarCalendario
                  ? Icons.view_agenda_rounded
                  : Icons.calendar_month_rounded,
              tooltip: _mostrarCalendario ? 'Ver lista' : 'Ver calendario',
              onPressed: () {
                setState(() {
                  _mostrarCalendario = !_mostrarCalendario;
                });
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirModalAgendarCita(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva cita'),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _futureCitas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _VcLoading();
            } else if (snapshot.hasError) {
              return _VcErrorState(
                message:
                    'No pudimos conectar con la base de datos.\n${snapshot.error}',
                onRetry: _cargarCitas,
              );
            }

            final citas = snapshot.data ?? [];
            final query = _searchController.text.trim().toLowerCase();

            final citasFiltradas = citas.where((c) {
              final cliente = (c['cliente'] ?? '').toString().toLowerCase();
              final mascota = (c['mascota'] ?? '').toString().toLowerCase();
              final servicio = (c['servicio'] ?? '').toString().toLowerCase();

              final estado = _normalizarEstado(c['estado']);
              final fecha = (c['fecha'] ?? '').toString();

              final coincideBusqueda =
                  query.isEmpty ||
                  cliente.contains(query) ||
                  mascota.contains(query) ||
                  servicio.contains(query);
              final esActiva = estado != 'Completada' && estado != 'Cancelada';
              final coincideEstado =
                  _filtroEstado == 'Todos' ||
                  (_filtroEstado == 'Pendiente'
                      ? esActiva
                      : estado == _filtroEstado);

              bool coincideFecha = true;
              if (_mostrarCalendario && _selectedDay != null) {
                final fechaSelFormatted =
                    "${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}";
                coincideFecha = fecha == fechaSelFormatted;
              }

              return coincideBusqueda && coincideEstado && coincideFecha;
            }).toList();

            final pendientes = citas.where((c) {
              final st = _normalizarEstado(c['estado']);
              return st != 'Completada' && st != 'Cancelada';
            }).length;

            final completadas = citas
                .where((c) => _normalizarEstado(c['estado']) == 'Completada')
                .length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _VcStatStrip(
                    stats: [
                      _VcStat(
                        label: 'Total',
                        value: '${citas.length}',
                        color: _Pal.primary,
                        icon: Icons.event_note_rounded,
                      ),
                      _VcStat(
                        label: 'Pendientes',
                        value: '$pendientes',
                        color: _Pal.sun,
                        icon: Icons.hourglass_top_rounded,
                      ),
                      _VcStat(
                        label: 'Completadas',
                        value: '$completadas',
                        color: _Pal.success,
                        icon: Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                ),

                if (_mostrarCalendario) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _VcCard(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
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
                            color: _Pal.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: _Pal.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: _Pal.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          defaultTextStyle: TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendTextStyle: TextStyle(
                            color: _Pal.coral,
                            fontWeight: FontWeight.w600,
                          ),
                          outsideTextStyle: TextStyle(color: _Pal.inkMuted),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: _Pal.inkSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          weekendStyle: TextStyle(
                            color: _Pal.coral,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonDecoration: BoxDecoration(
                            border: Border.all(color: _Pal.primary),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          formatButtonTextStyle: const TextStyle(
                            color: _Pal.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          titleTextStyle: const TextStyle(
                            color: _Pal.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          leftChevronIcon: const Icon(
                            Icons.chevron_left_rounded,
                            color: _Pal.primary,
                          ),
                          rightChevronIcon: const Icon(
                            Icons.chevron_right_rounded,
                            color: _Pal.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _VcSearchField(
                    controller: _searchController,
                    hint: 'Buscar por cliente, mascota o servicio',
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                ),

                _VcChoiceChips(
                  options: const [
                    'Todos',
                    'Pendiente',
                    'Completada',
                    'Cancelada',
                  ],
                  selected: _filtroEstado,
                  onSelected: (estado) =>
                      setState(() => _filtroEstado = estado),
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: citasFiltradas.isEmpty
                      ? const _VcEmptyState(
                          icon: Icons.event_busy_rounded,
                          title: 'Sin citas por aquí',
                          message:
                              'No hay citas para este filtro. Prueba con otra búsqueda o agenda una nueva.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: citasFiltradas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final cita = citasFiltradas[index];
                            final id = cita['id'];
                            final cliente =
                                cita['cliente'] ?? 'Cliente Desconocido';
                            final mascota = cita['mascota'] ?? 'Mascota';
                            final servicio = cita['servicio'] ?? 'Consulta';
                            final fecha = cita['fecha'] ?? '';
                            final hora = cita['hora'] ?? '';

                            final estado = _normalizarEstado(cita['estado']);
                            final badgeColor = _colorEstado(estado);
                            final esActiva =
                                estado != 'Completada' && estado != 'Cancelada';

                            return _VcCard(
                              padding: EdgeInsets.zero,
                              clip: true,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(width: 6, color: badgeColor),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const _VcIconTile(
                                                  icon: Icons.pets_rounded,
                                                  size: 46,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '$mascota',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: _Pal.ink,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Dueño: $cliente',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: _Pal.inkSoft,
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                _VcBadge(
                                                  label: estado,
                                                  color: badgeColor,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _VcInfoPill(
                                                  icon: Icons
                                                      .medical_services_rounded,
                                                  text: '$servicio',
                                                ),
                                                _VcInfoPill(
                                                  icon: Icons.event_rounded,
                                                  text: '$fecha',
                                                  color: _Pal.coral,
                                                ),
                                                _VcInfoPill(
                                                  icon: Icons.schedule_rounded,
                                                  text: '$hora',
                                                  color: _Pal.sky,
                                                ),
                                              ],
                                            ),
                                            if (esActiva) ...[
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      style:
                                                          OutlinedButton.styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                  0,
                                                                  42,
                                                                ),
                                                            foregroundColor:
                                                                _Pal.danger,
                                                            side: BorderSide(
                                                              color: _Pal.danger
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                            ),
                                                          ),
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Cancelar',
                                                      ),
                                                      onPressed: () =>
                                                          _cambiarEstadoCita(
                                                            id,
                                                            'Cancelada',
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                  0,
                                                                  42,
                                                                ),
                                                            backgroundColor:
                                                                _Pal.success,
                                                            textStyle:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                      icon: const Icon(
                                                        Icons.check_rounded,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Completar',
                                                      ),
                                                      onPressed: () =>
                                                          _cambiarEstadoCita(
                                                            id,
                                                            'Completada',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

class _VcHeaderAction extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _VcHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta base
// ─────────────────────────────────────────────────────────────────────────────

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

class _VcChoiceChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _VcChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final sel = o == selected;
          return GestureDetector(
            onTap: () => onSelected(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? _Pal.primary : _Pal.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: sel ? _Pal.primary : _Pal.line,
                  width: 1.4,
                ),
                boxShadow: sel
                    ? const [
                        BoxShadow(
                          color: Color(0x404D9699),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                o,
                style: TextStyle(
                  color: sel ? Colors.white : _Pal.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Títulos y secciones
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
