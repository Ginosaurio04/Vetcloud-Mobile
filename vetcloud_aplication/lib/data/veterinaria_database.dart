import '../models/cliente.dart';
import '../models/producto.dart';

class VeterinariaDatabase {
  static const demoPassword = '123456';
  static final VeterinariaDatabase instance = VeterinariaDatabase._internal();

  VeterinariaDatabase._internal() {
    _cargarDatosIniciales();
  }

  // Copia local de los clientes incluidos en veterinaria_unimar.sql.
  final List<Cliente> _clientes = [];

  // Productos de demostración: el SQL actual no contiene una tabla de productos.
  final List<Producto> _productos = [];

  Cliente? _usuarioActual;

  Cliente? get usuarioActual => _usuarioActual;
  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Producto> get productos => _productos;

  void _cargarDatosIniciales() {
    // Datos exactos volcados en veterinaria_unimar.sql (tabla `clientes`)
    _clientes.addAll([
      const Cliente(
        idCliente: 1,
        cedula: 'V-12345678',
        nombreCompleto: 'Gino Cova',
        telefono: '0412-1112233',
        email: 'gino.cova@email.com',
        direccion: 'Pampatar, Nueva Esparta',
        puntosFidelidad: 150,
        fechaRegistro: '2026-03-30 04:41:46',
      ),
      const Cliente(
        idCliente: 3,
        cedula: 'V-11222333',
        nombreCompleto: 'Eyla Vasquez',
        telefono: '0424-7778899',
        email: 'eyla.v@email.com',
        direccion: 'Porlamar, Nueva Esparta',
        puntosFidelidad: 200,
        fechaRegistro: '2026-03-30 04:41:46',
      ),
      const Cliente(
        idCliente: 4,
        cedula: 'V-44555666',
        nombreCompleto: 'Maria Rodriguez',
        telefono: '0416-2223344',
        email: 'm.rodriguez@email.com',
        direccion: 'Juan Griego, Nueva Esparta',
        puntosFidelidad: 45,
        fechaRegistro: '2026-03-30 04:41:46',
      ),
      const Cliente(
        idCliente: 5,
        cedula: 'V-99888777',
        nombreCompleto: 'Carlos Perez',
        telefono: '0412-5556677',
        email: 'carlos.perez@email.com',
        direccion: 'El Valle, Nueva Esparta',
        puntosFidelidad: 10,
        fechaRegistro: '2026-03-30 04:41:46',
      ),
      const Cliente(
        idCliente: 12,
        cedula: '12345678',
        nombreCompleto: 'jose',
        telefono: '04160310037',
        email: 'jsanchez.3440@unimar.edu.ve',
        direccion: 'ewfasfeasfd',
        puntosFidelidad: 0,
        fechaRegistro: '2026-04-06 06:28:12',
      ),
    ]);

    // Productos del inventario veterinario para Veterinaria Unimar
    _productos.addAll([
      Producto(
        id: 1,
        codigo: 'VAC-001',
        nombre: 'Vacuna Séxtuple Canina',
        categoria: 'Vacunas',
        stock: 24,
        stockMinimo: 10,
        precio: 25.00,
        unidad: 'Dosis',
        descripcion:
            'Inmunización contra parvovirus, moquillo, hepatitis y leptospirosis.',
      ),
      Producto(
        id: 2,
        codigo: 'VAC-002',
        nombre: 'Vacuna Antirrábica Rabisin',
        categoria: 'Vacunas',
        stock: 5,
        stockMinimo: 8,
        precio: 15.00,
        unidad: 'Dosis',
        descripcion: 'Protección contra la rabia para perros y gatos.',
      ),
      Producto(
        id: 3,
        codigo: 'ANT-001',
        nombre: 'Bravecto 10-20 kg',
        categoria: 'Antiparasitarios',
        stock: 14,
        stockMinimo: 5,
        precio: 38.50,
        unidad: 'Tableta',
        descripcion:
            'Protección masticable contra pulgas y garrapatas por 12 semanas.',
      ),
      Producto(
        id: 4,
        codigo: 'ANT-002',
        nombre: 'Simparica Trio 5-10 kg',
        categoria: 'Antiparasitarios',
        stock: 3,
        stockMinimo: 6,
        precio: 22.00,
        unidad: 'Tableta',
        descripcion:
            'Antiparasitario integral para pulgas, garrapatas y parásitos internos.',
      ),
      Producto(
        id: 5,
        codigo: 'MED-001',
        nombre: 'Enrofloxacina 50 mg',
        categoria: 'Medicamentos',
        stock: 35,
        stockMinimo: 10,
        precio: 8.50,
        unidad: 'Blíster 10 comp.',
        descripcion:
            'Antibiótico bactericida de amplio espectro para caninos y felinos.',
      ),
      Producto(
        id: 6,
        codigo: 'MED-002',
        nombre: 'Meloxicam Gotas 0.5%',
        categoria: 'Medicamentos',
        stock: 4,
        stockMinimo: 5,
        precio: 12.00,
        unidad: 'Frasco 15 ml',
        descripcion: 'Antiinflamatorio no esteroideo analgésico.',
      ),
      Producto(
        id: 7,
        codigo: 'ALI-001',
        nombre: 'Pro Plan Adulto Mediano 15 kg',
        categoria: 'Alimentos',
        stock: 8,
        stockMinimo: 4,
        precio: 65.00,
        unidad: 'Saco 15 kg',
        descripcion: 'Alimento super premium balanceado para perros adultos.',
      ),
      Producto(
        id: 8,
        codigo: 'ALI-002',
        nombre: 'Royal Canin Renal Feline 2 kg',
        categoria: 'Alimentos',
        stock: 0,
        stockMinimo: 3,
        precio: 34.00,
        unidad: 'Bolsa 2 kg',
        descripcion: 'Dieta veterinaria de soporte renal para gatos.',
      ),
      Producto(
        id: 9,
        codigo: 'INS-001',
        nombre: 'Jeringas Desechables 3 ml',
        categoria: 'Insumos',
        stock: 120,
        stockMinimo: 30,
        precio: 0.35,
        unidad: 'Unidad',
        descripcion: 'Jeringa médica desechable estéril de 3 ml con aguja.',
      ),
      Producto(
        id: 10,
        codigo: 'INS-002',
        nombre: 'Suero Fisiológico 0.9% 500 ml',
        categoria: 'Insumos',
        stock: 18,
        stockMinimo: 10,
        precio: 3.50,
        unidad: 'Frasco 500 ml',
        descripcion: 'Solución salina estéril para hidratación intravenosa.',
      ),
    ]);
  }

  /// Inicia una sesión local de demostración; el SQL no almacena contraseñas.
  bool autenticar(String identificador, String password) {
    if (password != demoPassword) return false;

    final term = identificador.trim().toLowerCase();
    final cedulaNormalizada = term.replaceAll(RegExp(r'[^0-9]'), '');
    Cliente? cliente;

    for (final candidato in _clientes) {
      final emailCoincide = candidato.email.trim().toLowerCase() == term;
      final cedulaCoincide =
          candidato.cedula.trim().toLowerCase() == term ||
          (cedulaNormalizada.isNotEmpty &&
              candidato.cedula.replaceAll(RegExp(r'[^0-9]'), '') ==
                  cedulaNormalizada);
      if (emailCoincide || cedulaCoincide) {
        cliente = candidato;
        break;
      }
    }

    if (cliente == null) return false;
    _usuarioActual = cliente;
    return true;
  }

  void cerrarSesion() {
    _usuarioActual = null;
  }

  // Operaciones de inventario
  void modificarStock(int productoId, int delta) {
    final index = _productos.indexWhere((p) => p.id == productoId);
    if (index != -1) {
      final nuevoStock = _productos[index].stock + delta;
      if (nuevoStock >= 0) {
        _productos[index].stock = nuevoStock;
      }
    }
  }

  void agregarProducto(Producto producto) {
    _productos.insert(0, producto);
  }

  void eliminarProducto(int id) {
    _productos.removeWhere((p) => p.id == id);
  }

  int get totalProductos => _productos.length;

  int get totalStockBajo =>
      _productos.where((p) => p.esBajoStock || p.esAgotado).length;

  double get valorTotalInventario =>
      _productos.fold(0.0, (acc, p) => acc + (p.stock * p.precio));
}
