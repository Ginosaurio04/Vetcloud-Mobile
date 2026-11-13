import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/producto.dart';
import '../widgets/custom_botton_navigation.dart';

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
  final String _urlProductos = 'http://localhost:3000/api/productos';
  final String _urlVentas = 'http://localhost:3000/api/ventas';
  final String _urlCitas = 'http://localhost:3000/api/citas';

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
      final res = await http.get(Uri.parse(_urlProductos));
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
    final res = await http.get(Uri.parse(_urlCitas));
    if (res.statusCode == 200) {
      final List<dynamic> todas = jsonDecode(res.body);
      return todas.where((c) {
        final st = _normalizarEstado(c['estado']);
        return st !=
            'Cancelada'; // vigentes: en espera, en consulta, peluquería o finalizadas
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto válido mayor a 0'),
          backgroundColor: Colors.redAccent,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar la factura: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto agotado en inventario'),
          backgroundColor: Colors.orangeAccent,
        ),
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

  // 📄 GENERAR Y DESCARGAR PDF (CORREGIDO SIN CONST Y CON CHILD:)
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
                            color: PdfColors.teal,
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
                    headerDecoration: pw.BoxDecoration(color: PdfColors.teal),
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
                    headerDecoration: pw.BoxDecoration(color: PdfColors.teal),
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
                                color: PdfColors.teal,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
    );

    if (res.statusCode == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta facturada exitosamente'),
            backgroundColor: Color(0xFF0DCF7E),
          ),
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
      backgroundColor: const Color(0xFF1E2429),
      builder: (ctx) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Seleccionar Producto',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _productosDisponibles.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12),
                itemBuilder: (ctx, index) {
                  final p = _productosDisponibles[index];
                  return ListTile(
                    title: Text(
                      p.nombre,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Stock: ${p.stock} | \$${p.precio.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: const Icon(
                      Icons.add_shopping_cart,
                      color: Color(0xFF0DCF7E),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _agregarAlCarrito(p);
                    },
                  );
                },
              ),
            ),
          ],
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Facturación VetCloud',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Facturar Citas'),
            Tab(icon: Icon(Icons.point_of_sale), text: 'Venta Directa'),
          ],
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
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se pudieron cargar las citas:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _recargarCitasVigentes,
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
                  ),
                );
              }

              final citas = snapshot.data ?? [];
              final Map<String, dynamic>? citaSel = _buscarCita(citas);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Seleccionar Cita Vigente a Facturar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: primaryColor),
                          tooltip: 'Actualizar citas',
                          onPressed: _recargarCitasVigentes,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        // El valor es el ID (int): los Map de Dart no se comparan
                        // por contenido y eso rompía el Dropdown al reconstruirse.
                        child: DropdownButton<int>(
                          dropdownColor: cardBg,
                          isExpanded: true,
                          hint: Text(
                            citas.isEmpty
                                ? 'No hay citas vigentes para facturar'
                                : 'Selecciona una cita...',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          value: citaSel == null
                              ? null
                              : int.tryParse(citaSel['id'].toString()),
                          items: citas
                              .where(
                                (c) => int.tryParse(c['id'].toString()) != null,
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
                                      color: Colors.white,
                                      fontSize: 13,
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
                    const SizedBox(height: 20),
                    if (citaSel != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen de Cita #${citaSel['id']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(color: Colors.white12, height: 20),
                            Text(
                              'Cliente: ${citaSel['cliente'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Mascota: ${citaSel['mascota'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Servicio: ${citaSel['servicio'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _montoCitaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Monto a Cobrar (\$)',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.attach_money,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _metodoPago,
                              dropdownColor: cardBg,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Método de Pago',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.payment,
                                  color: primaryColor,
                                ),
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.black,
                                ),
                                label: const Text(
                                  'Facturar y Descargar PDF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () => _facturarCita(citaSel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // PESTAÑA 2: VENTA DIRECTA (POS)
          _cargandoProductos
              ? const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: cardBg,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _clienteController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Cliente',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.add_shopping_cart,
                              color: primaryColor,
                            ),
                            onPressed: _abrirSelectorProductos,
                            tooltip: 'Agregar Producto',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _itemsCarrito.isEmpty
                          ? const Center(
                              child: Text(
                                'Carrito vacío. Agrega productos con el botón "+".',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _itemsCarrito.length,
                              itemBuilder: (ctx, index) {
                                final item = _itemsCarrito[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.producto.nombre,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '\$${item.producto.precio.toStringAsFixed(2)} x ${item.cantidad}',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
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
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL A PAGAR:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '\$${_montoTotal.toStringAsFixed(2)} USD',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _procesarFacturaVenta,
                            child: const Text(
                              'PROCESAR Y DESCARGAR PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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
    );
  }
}
