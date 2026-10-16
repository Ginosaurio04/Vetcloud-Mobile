import 'package:flutter/material.dart';
import '../data/veterinaria_database.dart';
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

  final List<String> _categorias = [
    'Todos',
    'Vacunas',
    'Antiparasitarios',
    'Medicamentos',
    'Alimentos',
    'Insumos',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalAgregarProducto(BuildContext context) {
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
                            'Nuevo Producto de Inventario',
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
                                final codigo = v?.trim().toUpperCase() ?? '';
                                if (codigo.isEmpty) return 'Requerido';
                                final existe = VeterinariaDatabase
                                    .instance
                                    .productos
                                    .any(
                                      (producto) =>
                                          producto.codigo.toUpperCase() ==
                                          codigo,
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
                                if (val != null) {
                                  setModalState(() => categoria = val);
                                }
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
                                final stock = int.tryParse(v ?? '');
                                return stock == null || stock < 0
                                    ? 'Ingresa un valor >= 0'
                                    : null;
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
                                final stockMinimo = int.tryParse(v ?? '');
                                return stockMinimo == null || stockMinimo < 0
                                    ? 'Ingresa un valor >= 0'
                                    : null;
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
                                final precio = double.tryParse(v ?? '');
                                return precio == null ||
                                        !precio.isFinite ||
                                        precio < 0
                                    ? 'Precio inválido'
                                    : null;
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
                                  ? 'Campo requerido'
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
                            final nuevo = Producto(
                              id: DateTime.now().millisecondsSinceEpoch,
                              codigo: codigoCtrl.text.trim().toUpperCase(),
                              nombre: nombreCtrl.text.trim(),
                              categoria: categoria,
                              stock: int.parse(stockCtrl.text),
                              stockMinimo: int.parse(stockMinCtrl.text),
                              precio: double.parse(precioCtrl.text),
                              unidad: unidadCtrl.text.trim(),
                              descripcion: 'Agregado manualmente al inventario',
                            );
                            VeterinariaDatabase.instance.agregarProducto(nuevo);
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Producto "${nuevo.nombre}" agregado con éxito.',
                                ),
                                backgroundColor: const Color(0xFF0DCF7E),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Guardar Producto',
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
      case 'insumos':
      default:
        return Icons.healing;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0DCF7E);
    const darkBg = Color(0xFF14191F);
    const cardBg = Color(0xFF1E2429);

    final db = VeterinariaDatabase.instance;
    final productos = db.productos;

    final query = _searchController.text.trim().toLowerCase();
    final productosFiltrados = productos.where((p) {
      final coincideCat =
          _categoriaSeleccionada == 'Todos' ||
          p.categoria.toLowerCase() == _categoriaSeleccionada.toLowerCase();
      final coincideQuery =
          query.isEmpty ||
          p.nombre.toLowerCase().contains(query) ||
          p.codigo.toLowerCase().contains(query);
      return coincideCat && coincideQuery;
    }).toList();

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: const Text(
          'Inventario VetCloud',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: primaryColor),
            tooltip: 'Agregar Producto',
            onPressed: () => _abrirModalAgregarProducto(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Métricas de Inventario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cardBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatMini(
                  label: 'Total Ítems',
                  valor: '${db.totalProductos}',
                  color: primaryColor,
                ),
                Container(height: 24, width: 1, color: Colors.white12),
                _StatMini(
                  label: 'Bajo Stock',
                  valor: '${db.totalStockBajo}',
                  color: db.totalStockBajo > 0
                      ? Colors.orangeAccent
                      : Colors.grey,
                ),
                Container(height: 24, width: 1, color: Colors.white12),
                _StatMini(
                  label: 'Valor Total',
                  valor: '\$${db.valorTotalInventario.toStringAsFixed(1)}',
                  color: Colors.white,
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inventario de demostración: el SQL no tiene tabla de productos y estos cambios no se guardan.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
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
                hintText: 'Buscar por producto o código...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Chips de categorías
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final seleccionada = cat == _categoriaSeleccionada;
                return ChoiceChip(
                  label: Text(cat),
                  selected: seleccionada,
                  selectedColor: primaryColor,
                  backgroundColor: cardBg,
                  labelStyle: TextStyle(
                    color: seleccionada ? Colors.black : Colors.white70,
                    fontWeight: seleccionada
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _categoriaSeleccionada = cat);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Lista de Productos
          Expanded(
            child: productosFiltrados.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron productos.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: productosFiltrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final producto = productosFiltrados[index];
                      final esBajoStock = producto.esBajoStock;
                      final esAgotado = producto.esAgotado;

                      Color badgeColor = primaryColor;
                      String badgeText = 'En Stock';
                      if (esAgotado) {
                        badgeColor = Colors.redAccent;
                        badgeText = 'Agotado';
                      } else if (esBajoStock) {
                        badgeColor = Colors.orangeAccent;
                        badgeText = 'Bajo Stock';
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: esBajoStock || esAgotado
                                ? badgeColor.withValues(alpha: 0.4)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _obtenerIconoCategoria(producto.categoria),
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          producto.nombre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                    '${producto.codigo} • ${producto.categoria} • ${producto.unidad}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${producto.precio.toStringAsFixed(2)}',
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
                            // Control de Stock (+ y -)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          db.modificarStock(producto.id, -1);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                        '${producto.stock}',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          db.modificarStock(producto.id, 1);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                  'Mín: ${producto.stockMinimo}',
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
