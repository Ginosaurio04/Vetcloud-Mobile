import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_botton_navigation.dart';

class ClientesScreen extends StatefulWidget {
  final String title;

  const ClientesScreen({super.key, this.title = 'Clientes'});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _searchController = TextEditingController();
  late Future<List<dynamic>> _futureClientes;

  final String _baseUrl = 'http://localhost:3000/api/clientes';

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() {
    setState(() {
      _futureClientes = _obtenerClientes();
    });
  }

  Future<List<dynamic>> _obtenerClientes() async {
    final res = await http.get(Uri.parse(_baseUrl));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Error al conectar con el servidor');
    }
  }

  Future<void> _guardarNuevoCliente(Map<String, dynamic> clienteData) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(clienteData),
    );

    if (res.statusCode == 201) {
      _cargarClientes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente registrado exitosamente'),
            backgroundColor: Color(0xFF0DCF7E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['error'] ?? 'Error al guardar el cliente'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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

  void _abrirModalAgregarCliente(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final cedulaCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();

    // Campos detallados de la Mascota
    final nombreMascotaCtrl = TextEditingController();
    final especieMascotaCtrl = TextEditingController(text: 'Perro');
    final razaMascotaCtrl = TextEditingController();
    final edadMascotaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2429),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                      Icon(Icons.person_add_alt_1, color: Color(0xFF0DCF7E)),
                      SizedBox(width: 8),
                      Text(
                        'Registrar Cliente y Mascota',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // DATOS DEL CLIENTE
                  const Text(
                    'DATOS DEL PROPIETARIO',
                    style: TextStyle(
                      color: Color(0xFF0DCF7E),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: cedulaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Cédula / ID *',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.badge, color: Color(0xFF0DCF7E)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'La Cédula es obligatoria'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.person, color: Color(0xFF0DCF7E)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'El Nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.phone, color: Color(0xFF0DCF7E)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico *',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.email, color: Color(0xFF0DCF7E)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'El Email es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: direccionCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Dirección de Habitación *',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.home, color: Color(0xFF0DCF7E)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'La Dirección es obligatoria'
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // DATOS DETALLADOS DE LA MASCOTA
                  const Text(
                    'INFORMACIÓN DE LA MASCOTA',
                    style: TextStyle(
                      color: Color(0xFF0DCF7E),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: nombreMascotaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Mascota',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.pets, color: Color(0xFF0DCF7E)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: especieMascotaCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Especie (Ej. Perro/Gato)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: razaMascotaCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Raza',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: edadMascotaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Edad de la Mascota',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.cake, color: Color(0xFF0DCF7E)),
                    ),
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
                        _guardarNuevoCliente({
                          'cedula': cedulaCtrl.text.trim(),
                          'nombre': nombreCtrl.text.trim(),
                          'telefono': telefonoCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'direccion': direccionCtrl.text.trim(),
                          'mascota': nombreMascotaCtrl.text.trim().isEmpty
                              ? 'Sin Registro'
                              : '${nombreMascotaCtrl.text.trim()} (${especieMascotaCtrl.text.trim()} - ${razaMascotaCtrl.text.trim()})',
                        });
                      }
                    },
                    child: const Text(
                      'Guardar Registro Completo',
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
  }

  void _mostrarDetalleCliente(
    BuildContext context,
    Map<String, dynamic> cliente,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2429),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.contact_page, color: Color(0xFF0DCF7E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cliente['nombre'] ?? 'Cliente',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemDetalle(Icons.badge, 'Cédula:', cliente['cedula'] ?? 'N/A'),
            _itemDetalle(
              Icons.phone,
              'Teléfono:',
              cliente['telefono'] ?? 'N/A',
            ),
            _itemDetalle(Icons.email, 'Email:', cliente['email'] ?? 'N/A'),
            _itemDetalle(
              Icons.home,
              'Dirección:',
              cliente['direccion'] ?? 'N/A',
            ),
            const Divider(color: Colors.white24, height: 20),
            _itemDetalle(
              Icons.pets,
              'Mascota:',
              cliente['mascota'] ?? 'Sin Mascota',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFF0DCF7E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemDetalle(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0DCF7E), size: 16),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
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
          'Directorio de Clientes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _abrirModalAgregarCliente(context),
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureClientes,
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
                  const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error al cargar clientes:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarClientes,
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

          final clientes = snapshot.data ?? [];
          final query = _searchController.text.trim().toLowerCase();

          final clientesFiltrados = clientes.where((c) {
            final nombre = (c['nombre'] ?? '').toString().toLowerCase();
            final telefono = (c['telefono'] ?? '').toString().toLowerCase();
            final mascota = (c['mascota'] ?? '').toString().toLowerCase();
            final cedula = (c['cedula'] ?? '').toString().toLowerCase();
            return query.isEmpty ||
                nombre.contains(query) ||
                telefono.contains(query) ||
                cedula.contains(query) ||
                mascota.contains(query);
          }).toList();

          return Column(
            children: [
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
                      label: 'Total Clientes',
                      valor: '${clientes.length}',
                      color: primaryColor,
                    ),
                    Container(height: 24, width: 1, color: Colors.white12),
                    _StatMini(
                      label: 'Mascotas Reg.',
                      valor:
                          '${clientes.where((c) => (c['mascota'] ?? '').toString().isNotEmpty).length}',
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        'Buscar por cliente, cédula, teléfono o mascota...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: clientesFiltrados.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay clientes registrados.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: clientesFiltrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cliente = clientesFiltrados[index];
                          final nombre = cliente['nombre'] ?? 'Sin Nombre';
                          final telefono =
                              cliente['telefono'] ?? 'Sin Teléfono';
                          final mascota = cliente['mascota'] ?? 'Sin Mascota';

                          return InkWell(
                            onTap: () =>
                                _mostrarDetalleCliente(context, cliente),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: Text(
                                      nombre.isNotEmpty
                                          ? nombre[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_android,
                                              color: Colors.white54,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              telefono,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: primaryColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.pets,
                                          color: primaryColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          mascota,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
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
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 2),
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
