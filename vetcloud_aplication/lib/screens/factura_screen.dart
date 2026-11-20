import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/producto.dart';
import '../widgets/custom_botton_navigation.dart';
import '../config.dart';

class FacturaItem {
  final Producto producto;
  int cantidad;

  FacturaItem({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}

class FacturaScreen extends StatefulWidget {
  final String title;

  const FacturaScreen({super.key, this.title = 'Facturación VetCloud'});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen>
    with SingleTickerProviderStateMixin {
  // Color de marca (turquesa VetCloud) para la factura en PDF
  static const _pdfBrand = PdfColor(0.302, 0.588, 0.600);

  late TabController _tabController;

  // Controllers y Carrito
  final _clienteController = TextEditingController(text: 'Cliente General');
  final List<FacturaItem> _itemsCarrito = [];
  List<Producto> _productosDisponibles = [];
  bool _cargandoProductos = true;
  String _metodoPago = 'Efectivo';
  final List<String> _metodosPago = [
    'Efectivo',
    'Pago Móvil',
    'Transferencia',
    'Tarjeta / POS',
  ];

  // Citas Vigentes
  late Future<List<dynamic>> _futureCitasVigentes;
  int? _citaSeleccionadaId;
  final TextEditingController _montoCitaCtrl = TextEditingController(
    text: '25.00',
  );

  // Endpoints API
  final String _urlProductos = '$kApiUrl/api/productos';
  final String _urlVentas = '$kApiUrl/api/ventas';
  final String _urlCitas = '$kApiUrl/api/citas';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarProductos();
    _futureCitasVigentes = _cargarCitasVigentes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clienteController.dispose();
    _montoCitaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    try {
      final res = await http.get(Uri.parse(_urlProductos)).timeout(kApiTimeout);
      if (res.statusCode == 200) {
        final List<dynamic> body = jsonDecode(res.body);
        setState(() {
          _productosDisponibles = body
              .map((item) => Producto.fromMap(item))
              .toList();
          _cargandoProductos = false;
        });
      }
    } catch (_) {
      setState(() => _cargandoProductos = false);
    }
  }

  String _normalizarEstado(dynamic raw) {
    final e = (raw ?? '').toString().trim().toLowerCase();
    if (e.isEmpty || e == 'pendiente' || e == 'en espera') return 'Pendiente';
    if (e == 'completada' ||
        e == 'completado' ||
        e == 'finalizada' ||
        e == 'finalizado') {
      return 'Completada';
    }
    if (e == 'cancelada' || e == 'cancelado') return 'Cancelada';
    return e;
  }

  Future<List<dynamic>> _cargarCitasVigentes() async {
    final res = await http.get(Uri.parse(_urlCitas)).timeout(kApiTimeout);
    if (res.statusCode == 200) {
      final List<dynamic> todas = jsonDecode(res.body);
      return todas.where((c) {
        final st = _normalizarEstado(c['estado']);
        return st != 'Cancelada';
      }).toList();
    } else {
      throw Exception('Error al obtener citas para facturar');
    }
  }

  void _recargarCitasVigentes() {
    setState(() {
      _citaSeleccionadaId = null;
      _futureCitasVigentes = _cargarCitasVigentes();
    });
  }

  Map<String, dynamic>? _buscarCita(List<dynamic> citas) {
    if (_citaSeleccionadaId == null) return null;
    for (final c in citas) {
      if (int.tryParse(c['id'].toString()) == _citaSeleccionadaId) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  Future<void> _facturarCita(Map<String, dynamic> cita) async {
    final monto =
        double.tryParse(_montoCitaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    if (monto <= 0) {
      _vcSnack(
        context,
        'Ingresa un monto válido mayor a 0',
        type: _VcSnackType.error,
      );
      return;
    }

    try {
      await _generarYDescargarPDF(
        cliente: (cita['cliente'] ?? 'Cliente').toString(),
        concepto:
            'Servicio: ${cita['servicio'] ?? 'Consulta'} (${cita['fecha'] ?? ''})',
        subtotal: monto,
        total: monto,
        metodoPago: _metodoPago,
      );
    } catch (e) {
      debugPrint('Error al facturar cita: $e');
      if (mounted) {
        _vcSnack(
          context,
          'No se pudo generar la factura: $e',
          type: _VcSnackType.error,
        );
      }
    }
  }

  double get _subtotalTotal =>
      _itemsCarrito.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _ivaTotal => _subtotalTotal * 0.16;
  double get _montoTotal => _subtotalTotal + _ivaTotal;

  void _agregarAlCarrito(Producto p) {
    if (p.stock <= 0) {
      _vcSnack(
        context,
        'Producto agotado en inventario',
        type: _VcSnackType.warning,
      );
      return;
    }

    setState(() {
      final idx = _itemsCarrito.indexWhere((i) => i.producto.id == p.id);
      if (idx != -1) {
        if (_itemsCarrito[idx].cantidad < p.stock) {
          _itemsCarrito[idx].cantidad++;
        }
      } else {
        _itemsCarrito.add(FacturaItem(producto: p));
      }
    });
  }

  // 📄 GENERAR Y DESCARGAR PDF
  Future<void> _generarYDescargarPDF({
    required String cliente,
    required String concepto,
    required double subtotal,
    required double total,
    required String metodoPago,
    List<dynamic>? detalles,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VetCloud Veterinary Clinic',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfBrand,
                          ),
                        ),
                        pw.Text('RIF: J-12345678-9 | Tel: +58 412-0000000'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'FACTURA DE VENTA',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'N° FACT: #${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                        ),
                        pw.Text(
                          'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(height: 20),
                pw.Text(
                  'Cliente: $cliente',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Método de Pago: $metodoPago'),
                pw.SizedBox(height: 16),

                if (detalles != null && detalles.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Producto/Servicio',
                      'Cant.',
                      'Precio',
                      'Subtotal',
                    ],
                    data: detalles
                        .map(
                          (d) => [
                            d['nombre'],
                            '${d['cantidad']}',
                            '\$${d['precio'].toStringAsFixed(2)}',
                            '\$${d['subtotal'].toStringAsFixed(2)}',
                          ],
                        )
                        .toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(color: _pdfBrand),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headers: ['Descripción del Servicio', 'Total \$'],
                    data: [
                      [concepto, '\$${total.toStringAsFixed(2)}'],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(color: _pdfBrand),
                  ),

                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:'),
                            pw.Text('\$${subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL A PAGAR:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: _pdfBrand,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    '¡Gracias por confiar en VetCloud!',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Factura_VetCloud_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _procesarFacturaVenta() async {
    if (_itemsCarrito.isEmpty) {
      _vcSnack(context, 'El carrito está vacío', type: _VcSnackType.error);
      return;
    }

    final String cliente = _clienteController.text.trim().isEmpty
        ? 'Cliente General'
        : _clienteController.text.trim();

    final itemsPayload = _itemsCarrito
        .map(
          (i) => {
            'producto_id': i.producto.id,
            'nombre': i.producto.nombre,
            'cantidad': i.cantidad,
            'precio': i.producto.precio,
            'subtotal': i.subtotal,
          },
        )
        .toList();

    final payload = {
      'cliente': cliente,
      'subtotal': _subtotalTotal,
      'iva': _ivaTotal,
      'total': _montoTotal,
      'metodo_pago': _metodoPago,
      'items': itemsPayload,
    };

    final res = await http.post(
      Uri.parse(_urlVentas),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(kApiTimeout);

    if (res.statusCode == 201) {
      if (mounted) {
        _vcSnack(
          context,
          'Venta facturada exitosamente',
          type: _VcSnackType.success,
        );
      }

      await _generarYDescargarPDF(
        cliente: cliente,
        concepto: 'Venta de Productos POS',
        subtotal: _subtotalTotal,
        total: _montoTotal,
        metodoPago: _metodoPago,
        detalles: itemsPayload,
      );

      setState(() => _itemsCarrito.clear());
      _cargarProductos();
    }
  }

  void _abrirSelectorProductos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              const _VcSheetHandle(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: _VcSheetHeader(
                  icon: Icons.add_shopping_cart_rounded,
                  title: 'Seleccionar producto',
                  subtitle: 'Toca un producto para añadirlo al carrito',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _productosDisponibles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: _VcEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Sin productos disponibles',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _productosDisponibles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final p = _productosDisponibles[index];
                          final agotado = p.stock <= 0;
                          return _VcCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _agregarAlCarrito(p);
                            },
                            child: Row(
                              children: [
                                _VcIconTile(
                                  icon: Icons.medication_rounded,
                                  color: agotado ? _Pal.inkMuted : _Pal.primary,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _Pal.ink,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      Text(
                                        agotado
                                            ? 'Agotado'
                                            : 'Stock: ${p.stock}',
                                        style: TextStyle(
                                          color: agotado
                                              ? _Pal.danger
                                              : _Pal.inkSoft,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${p.precio.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: _Pal.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.add_circle_rounded,
                                  color: agotado ? _Pal.line : _Pal.primary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filaResumen(String label, String valor, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: total ? _Pal.ink : _Pal.inkSoft,
              fontWeight: total ? FontWeight.w900 : FontWeight.w700,
              fontSize: total ? 16 : 13.5,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: total ? _Pal.primaryDark : _Pal.ink,
              fontWeight: FontWeight.w900,
              fontSize: total ? 22 : 14,
              letterSpacing: total ? -0.4 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoCita(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _VcIconTile(icon: icon, size: 36),
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
                  valor,
                  style: const TextStyle(
                    color: _Pal.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
        appBar: _VcAppBar(
          icon: Icons.receipt_long_rounded,
          title: 'Facturación',
          subtitle: 'Cobra citas y ventas en segundos',
          bottomHeight: 56,
          bottom: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              labelColor: _Pal.primaryDeep,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              splashBorderRadius: BorderRadius.circular(16),
              tabs: const [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Citas'),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Venta directa'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // PESTAÑA 1: FACTURAR CITAS
            FutureBuilder<List<dynamic>>(
              future: _futureCitasVigentes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _VcLoading();
                }

                if (snapshot.hasError) {
                  return _VcErrorState(
                    message:
                        'No se pudieron cargar las citas.\n${snapshot.error}',
                    onRetry: _recargarCitasVigentes,
                  );
                }

                final citas = snapshot.data ?? [];
                final Map<String, dynamic>? citaSel = _buscarCita(citas);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VcSectionTitle(
                        'Cita a facturar',
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: _Pal.primary,
                          ),
                          tooltip: 'Actualizar citas',
                          onPressed: _recargarCitasVigentes,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _VcCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(18),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _Pal.primary,
                            ),
                            hint: Text(
                              citas.isEmpty
                                  ? 'No hay citas vigentes para facturar'
                                  : 'Selecciona una cita…',
                              style: const TextStyle(
                                color: _Pal.inkMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            value: citaSel == null
                                ? null
                                : int.tryParse(citaSel['id'].toString()),
                            items: citas
                                .where(
                                  (c) =>
                                      int.tryParse(c['id'].toString()) != null,
                                )
                                .map<DropdownMenuItem<int>>((c) {
                                  final cliente = c['cliente'] ?? 'Cliente';
                                  final mascota = c['mascota'] ?? 'Mascota';
                                  final servicio = c['servicio'] ?? 'Consulta';
                                  final fecha = c['fecha'] ?? '';

                                  return DropdownMenuItem<int>(
                                    value: int.parse(c['id'].toString()),
                                    child: Text(
                                      '$cliente | $mascota - $servicio ($fecha)',
                                      style: const TextStyle(
                                        color: _Pal.ink,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (val) {
                              setState(() => _citaSeleccionadaId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (citaSel == null)
                        const _VcCard(
                          color: _Pal.primarySoft,
                          borderColor: Colors.transparent,
                          child: Row(
                            children: [
                              Icon(Icons.info_rounded, color: _Pal.primaryDark),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Elige una cita para ver su resumen y generar la factura en PDF.',
                                  style: TextStyle(
                                    color: _Pal.primaryDeep,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (citaSel != null)
                        _VcCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Resumen de la cita',
                                      style: TextStyle(
                                        color: _Pal.ink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  _VcBadge(
                                    label: '#${citaSel['id']}',
                                    color: _Pal.primary,
                                    dot: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _datoCita(
                                Icons.person_rounded,
                                'Cliente',
                                '${citaSel['cliente'] ?? 'N/A'}',
                              ),
                              _datoCita(
                                Icons.pets_rounded,
                                'Mascota',
                                '${citaSel['mascota'] ?? 'N/A'}',
                              ),
                              _datoCita(
                                Icons.medical_services_rounded,
                                'Servicio',
                                '${citaSel['servicio'] ?? 'N/A'}',
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _montoCitaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Monto a cobrar (\$)',
                                  prefixIcon: Icon(Icons.attach_money_rounded),
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _metodoPago,
                                isExpanded: true,
                                borderRadius: BorderRadius.circular(18),
                                decoration: const InputDecoration(
                                  labelText: 'Método de pago',
                                  prefixIcon: Icon(Icons.payments_rounded),
                                ),
                                items: _metodosPago
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _metodoPago = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                  ),
                                  label: const Text('Facturar y descargar PDF'),
                                  onPressed: () => _facturarCita(citaSel),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // PESTAÑA 2: VENTA DIRECTA (POS)
            _cargandoProductos
                ? const _VcLoading()
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _clienteController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del cliente',
                                  prefixIcon: Icon(Icons.person_rounded),
                                  fillColor: _Pal.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 54),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 20,
                                ),
                                label: const Text('Agregar'),
                                onPressed: _abrirSelectorProductos,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _itemsCarrito.isEmpty
                            ? const _VcEmptyState(
                                icon: Icons.shopping_cart_outlined,
                                title: 'Tu carrito está vacío',
                                message:
                                    'Toca "Agregar" para añadir productos a la venta.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  12,
                                ),
                                itemCount: _itemsCarrito.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, index) {
                                  final item = _itemsCarrito[index];
                                  return _VcCard(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      6,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        const _VcIconTile(
                                          icon: Icons.medication_rounded,
                                          size: 44,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.producto.nombre,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _Pal.ink,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                              Text(
                                                '\$${item.producto.precio.toStringAsFixed(2)} × ${item.cantidad}',
                                                style: const TextStyle(
                                                  color: _Pal.inkSoft,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '\$${item.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: _Pal.primaryDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: _Pal.danger,
                                          ),
                                          tooltip: 'Quitar',
                                          onPressed: () => setState(
                                            () => _itemsCarrito.removeAt(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        decoration: const BoxDecoration(
                          color: _Pal.surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                          boxShadow: _Sombras.lifted,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _filaResumen(
                              'Subtotal',
                              '\$${_subtotalTotal.toStringAsFixed(2)}',
                            ),
                            _filaResumen(
                              'IVA (16%)',
                              '\$${_ivaTotal.toStringAsFixed(2)}',
                            ),
                            const Divider(height: 18),
                            _filaResumen(
                              'Total a pagar',
                              '\$${_montoTotal.toStringAsFixed(2)} USD',
                              total: true,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('Procesar y descargar PDF'),
                                onPressed: _procesarFacturaVenta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
        bottomNavigationBar: const CustomBottomNavigation(currentIndex: 4),
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
  static const primary = Color(0xFF4D9699);
  static const primaryDark = Color(0xFF2F7377);
  static const primaryDeep = Color(0xFF1E4F54);
  static const primarySoft = Color(0xFFE3F1F1);

  // Superficies
  static const bg = Color(0xFFFEFCF3);
  static const surface = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFEF8E6);
  static const line = Color(0xFFEDE6CF);

  // Texto
  static const ink = Color(0xFF22343A);
  static const inkSoft = Color(0xFF5F6F73);
  static const inkMuted = Color(0xFF9AA5A8);

  // Acentos semánticos
  static const sun = Color(0xFFF2B33D);
  static const success = Color(0xFF3E9E6F);
  static const coral = Color(0xFFF2836B);
  static const danger = Color(0xFFE0564B);

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
  final Widget? bottom;
  final double bottomHeight;

  const _VcAppBar({
    required this.title,
    this.subtitle,
    this.icon = Icons.pets_rounded,
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

class _VcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const _VcCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
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
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _VcIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _VcIconTile({
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

class _VcBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const _VcBadge({required this.label, required this.color, this.dot = true});

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

class _VcSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _VcSectionTitle(this.title, {this.trailing});

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

class _VcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const _VcEmptyState({required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: _Pal.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: _Pal.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Pal.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Pal.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
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

  const _VcErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _Pal.coral.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: _Pal.coral,
              ),
            ),
            const SizedBox(height: 16),
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
  const _VcLoading();

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
  const _VcSheetHandle();

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

enum _VcSnackType { success, error, warning }

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
    case _VcSnackType.warning:
      c = _Pal.sun;
      icon = Icons.warning_amber_rounded;
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
