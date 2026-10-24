class Producto {
  final int id;
  final String codigo;
  final String nombre;
  final String categoria;
  final int stock;
  final int stockMinimo;
  final double precio;
  final String unidad;
  final String descripcion;

  Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.stock,
    required this.stockMinimo,
    required this.precio,
    required this.unidad,
    required this.descripcion,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      categoria: map['categoria'] ?? '',
      stock: map['stock'] is int
          ? map['stock']
          : int.parse(map['stock'].toString()),
      // Mapea 'stock_minimo' de MySQL a 'stockMinimo' de Dart
      stockMinimo: map['stock_minimo'] != null
          ? (map['stock_minimo'] is int
                ? map['stock_minimo']
                : int.parse(map['stock_minimo'].toString()))
          : (map['stockMinimo'] ?? 5),
      // Convierte 'precio' (String de MySQL DECIMAL) a double
      precio: map['precio'] != null
          ? double.parse(map['precio'].toString())
          : 0.0,
      unidad: map['unidad'] ?? 'Unidad',
      descripcion: map['descripcion'] ?? '',
    );
  }

  bool get esBajoStock => stock <= stockMinimo && stock > 0;
  bool get esAgotado => stock <= 0;
}
