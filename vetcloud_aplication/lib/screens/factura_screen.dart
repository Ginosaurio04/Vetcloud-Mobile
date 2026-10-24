import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  const FacturaScreen({super.key, this.title = 'Facturación'});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  final _clienteController = TextEditingController(text: 'Cliente General');
  final List<FacturaItem> _itemsCarrito = [];
  List<Producto> _productosDisponibles = [];
  bool _cargandoProductos = true;
  String _metodoPago = 'Efectivo';

  final String _urlProductos = 'http://localhost:3000/api/productos';
  final String _urlVentas = 'http://localhost:3000/api/ventas';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final res = await http.get(Uri.parse(_urlProductos));
      if (res.statusCode == 200) {
        List<dynamic> body = jsonDecode(res.body);
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

  double get _subtotalTotal =>
      _itemsCarrito.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _ivaTotal => _subtotalTotal * 0.16; // 16% IVA
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

  Future<void> _procesarFactura() async {
    if (_itemsCarrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final payload = {
      'cliente': _clienteController.text.trim().isEmpty
          ? 'Cliente General'
          : _clienteController.text.trim(),
      'subtotal': _subtotalTotal,
      'iva': _ivaTotal,
      'total': _montoTotal,
      'metodo_pago': _metodoPago,
      'items': _itemsCarrito
          .map(
            (i) => {
              'producto_id': i.producto.id,
              'nombre': i.producto.nombre,
              'cantidad': i.cantidad,
              'precio': i.producto.precio,
              'subtotal': i.subtotal,
            },
          )
          .toList(),
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
            content: Text('Venta procesada y facturada correctamente'),
            backgroundColor: Color(0xFF0DCF7E),
          ),
        );
      }
      setState(() {
        _itemsCarrito.clear();
      });
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
        title: const Text(
          'Facturación / Punto de Venta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _cargandoProductos
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // Datos del cliente
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
                            prefixIcon: Icon(Icons.person, color: primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.add_a_photo,
                          color: primaryColor,
                        ),
                        onPressed: _abrirSelectorProductos,
                        tooltip: 'Agregar Producto',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Detalle del Carrito
                Expanded(
                  child: _itemsCarrito.isEmpty
                      ? const Center(
                          child: Text(
                            'Carrito vacío. Haz clic en "+" para agregar productos.',
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
                                    onPressed: () {
                                      setState(
                                        () => _itemsCarrito.removeAt(index),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Resumen de Totales y Cobro
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
                            'Subtotal:',
                            style: TextStyle(color: Colors.white60),
                          ),
                          Text(
                            '\$${_subtotalTotal.toStringAsFixed(2)} USD',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IVA (16%):',
                            style: TextStyle(color: Colors.white60),
                          ),
                          Text(
                            '\$${_ivaTotal.toStringAsFixed(2)} USD',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
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
                        onPressed: _procesarFactura,
                        child: const Text(
                          'PROCESAR Y FACTURAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 4),
    );
  }
}
