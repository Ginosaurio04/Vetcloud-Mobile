import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/producto.dart';
import '../widgets/custom_botton_navigation.dart';

class InventarioScreen extends StatefulWidget {
  final String title;

  const InventarioScreen({super.key, this.title = 'Inventario'});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _searchController = TextEditingController();
  String _categoriaSeleccionada = 'Todos';
  late Future<List<Producto>> _futureProductos;

  final List<String> _categorias = [
    'Todos',
    'Vacunas',
    'Antiparasitarios',
    'Medicamentos',
    'Alimentos',
    'Insumos',
  ];

  // NOTA DE IP: 'http://localhost:3000' para Chrome / Web.
  // Para emulador Android usa 'http://10.0.2.2:3000'.
  final String _baseUrl = 'http://localhost:3000/api/productos';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  void _cargarProductos() {
    setState(() {
      _futureProductos = _obtenerProductos();
    });
  }

  Future<List<Producto>> _obtenerProductos() async {
    final res = await http.get(Uri.parse(_baseUrl));
    if (res.statusCode == 200) {
      List<dynamic> body = jsonDecode(res.body);
      return body.map((item) => Producto.fromMap(item)).toList();
    } else {
      throw Exception('Error al cargar inventario');
    }
  }

  Future<void> _modificarStock(int id, int cantidad) async {
    final url = Uri.parse('$_baseUrl/$id/stock');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cantidad': cantidad}),
    );
    if (res.statusCode == 200) {
      _cargarProductos();
    }
  }

  Future<void> _guardarNuevoProducto(Map<String, dynamic> productoData) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(productoData),
    );

    if (res.statusCode == 201) {
      _cargarProductos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto guardado en la Base de Datos'),
            backgroundColor: Color(0xFF0DCF7E),
          ),
        );
      }
    } else {
      final err = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['mensaje'] ?? 'Error al guardar'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalAgregarProducto(
    BuildContext context,
    List<Producto> listaActual,
  ) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final stockMinCtrl = TextEditingController(text: '5');
    final precioCtrl = TextEditingController(text: '10.0');
    final unidadCtrl = TextEditingController(text: 'Unidad');
    String categoria = 'Medicamentos';

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
                          Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF0DCF7E),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Nuevo Producto en BD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nombreCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Producto',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(
                            Icons.medication,
                            color: Color(0xFF0DCF7E),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo requerido'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codigoCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Código / SKU',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              validator: (v) {
                                final cod = v?.trim().toUpperCase() ?? '';
                                if (cod.isEmpty) return 'Requerido';
                                final existe = listaActual.any(
                                  (p) => p.codigo.toUpperCase() == cod,
                                );
                                return existe ? 'Código ya existe' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: categoria,
                              dropdownColor: const Color(0xFF1E2429),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              items: _categorias
                                  .where((c) => c != 'Todos')
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setModalState(() => categoria = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Stock Inicial',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              validator: (v) {
                                final s = int.tryParse(v ?? '');
                                return s == null || s < 0 ? 'Mínimo 0' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stockMinCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Stock Mínimo',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              validator: (v) {
                                final sm = int.tryParse(v ?? '');
                                return sm == null || sm < 0 ? 'Mínimo 0' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: precioCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Precio (\$ USD)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              validator: (v) {
                                final p = double.tryParse(v ?? '');
                                return p == null || p < 0 ? 'Inválido' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: unidadCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Unidad (ej. Frasco)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Requerido'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                            Navigator.pop(ctx);
                            _guardarNuevoProducto({
                              'codigo': codigoCtrl.text.trim().toUpperCase(),
                              'nombre': nombreCtrl.text.trim(),
                              'categoria': categoria,
                              'stock': int.parse(stockCtrl.text),
                              'stock_minimo': int.parse(stockMinCtrl.text),
                              'precio': double.parse(precioCtrl.text),
                              'unidad': unidadCtrl.text.trim(),
                              'descripcion': 'Registrado vía app VetCloud',
                            });
                          }
                        },
                        child: const Text(
                          'Guardar en BD',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

  IconData _obtenerIconoCategoria(String cat) {
    switch (cat.toLowerCase()) {
      case 'vacunas':
        return Icons.vaccines;
      case 'antiparasitarios':
        return Icons.bug_report_outlined;
      case 'medicamentos':
        return Icons.medical_services_outlined;
      case 'alimentos':
        return Icons.pets;
      default:
        return Icons.healing;
    }
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
          'Inventario MySQL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Producto>>(
        future: _futureProductos,
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
                    onPressed: _cargarProductos,
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

          final productos = snapshot.data ?? [];

          final totalProductos = productos.length;
          final totalStockBajo = productos.where((p) => p.esBajoStock).length;
          final valorTotal = productos.fold(
            0.0,
            (sum, item) => sum + (item.precio * item.stock),
          );

          final query = _searchController.text.trim().toLowerCase();
          final productosFiltrados = productos.where((p) {
            final coincideCat =
                _categoriaSeleccionada == 'Todos' ||
                p.categoria.toLowerCase() ==
                    _categoriaSeleccionada.toLowerCase();
            final coincideQuery =
                query.isEmpty ||
                p.nombre.toLowerCase().contains(query) ||
                p.codigo.toLowerCase().contains(query);
            return coincideCat && coincideQuery;
          }).toList();

          return Scaffold(
            backgroundColor: darkBg,
            floatingActionButton: FloatingActionButton(
              backgroundColor: primaryColor,
              onPressed: () => _abrirModalAgregarProducto(context, productos),
              child: const Icon(Icons.add, color: Colors.black),
            ),
            body: Column(
              children: [
                // Banner de métricas reales
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
                        label: 'Total Ítems',
                        valor: '$totalProductos',
                        color: primaryColor,
                      ),
                      Container(height: 24, width: 1, color: Colors.white12),
                      _StatMini(
                        label: 'Bajo Stock',
                        valor: '$totalStockBajo',
                        color: totalStockBajo > 0
                            ? Colors.orangeAccent
                            : Colors.grey,
                      ),
                      Container(height: 24, width: 1, color: Colors.white12),
                      _StatMini(
                        label: 'Valor Total',
                        valor: '\$${valorTotal.toStringAsFixed(1)}',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                // Buscador
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto o código...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Filtro Categorías
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categorias.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categorias[index];
                      final sel = cat == _categoriaSeleccionada;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: sel,
                        selectedColor: primaryColor,
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _categoriaSeleccionada = cat),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Lista dinámicamente actualizada desde MySQL
                Expanded(
                  child: productosFiltrados.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay productos registrados en MySQL',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: productosFiltrados.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = productosFiltrados[index];
                            final esBajo = p.esBajoStock;
                            final esAgotado = p.esAgotado;

                            Color badgeColor = primaryColor;
                            String badgeText = 'En Stock';
                            if (esAgotado) {
                              badgeColor = Colors.redAccent;
                              badgeText = 'Agotado';
                            } else if (esBajo) {
                              badgeColor = Colors.orangeAccent;
                              badgeText = 'Bajo Stock';
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: esBajo || esAgotado
                                      ? badgeColor.withValues(alpha: 0.4)
                                      : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _obtenerIconoCategoria(p.categoria),
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.nombre,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: badgeColor,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                badgeText,
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.codigo} • ${p.categoria} (${p.unidad})',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${p.precio.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Botones interactivos que sincronizan con MySQL
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () =>
                                                _modificarStock(p.id, -1),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              '${p.stock}',
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                _modificarStock(p.id, 1),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mín: ${p.stockMinimo}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
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
      ),
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 1),
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
