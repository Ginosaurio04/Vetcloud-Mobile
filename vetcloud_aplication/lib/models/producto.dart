class Producto {
  final int id;
  final String codigo;
  final String nombre;
  final String categoria;
  int stock;
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

  bool get esBajoStock => stock <= stockMinimo && stock > 0;
  bool get esAgotado => stock <= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'categoria': categoria,
      'stock': stock,
      'stock_minimo': stockMinimo,
      'precio': precio,
      'unidad': unidad,
      'descripcion': descripcion,
    };
  }
}
