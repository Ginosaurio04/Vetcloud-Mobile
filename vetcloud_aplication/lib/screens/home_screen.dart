import 'package:flutter/material.dart';
import '../data/veterinaria_database.dart';
import '../widgets/custom_botton_navigation.dart';

class HomeScreen extends StatelessWidget {
  final String title;

  const HomeScreen({super.key, this.title = 'Home'});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0DCF7E);
    const darkBg = Color(0xFF14191F);
    const cardBg = Color(0xFF1E2429);

    final db = VeterinariaDatabase.instance;
    final usuario = db.usuarioActual;
    final clientes = db.clientes;
    final totalProductos = db.totalProductos;
    final totalStockBajo = db.totalStockBajo;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.pets, color: primaryColor, size: 24),
            SizedBox(width: 8),
            Text(
              'VetCloud Unimar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              db.cerrarSesion();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Bienvenida con Usuario Activo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor.withValues(alpha: 0.25), cardBg],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: primaryColor,
                    child: Text(
                      (usuario?.nombreCompleto.isNotEmpty ?? false)
                          ? usuario!.nombreCompleto[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenido de vuelta,',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        Text(
                          usuario?.nombreCompleto ?? 'Invitado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usuario != null
                              ? 'C.I: ${usuario.cedula}'
                              : 'Veterinaria Unimar',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (usuario != null && usuario.puntosFidelidad > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${usuario.puntosFidelidad} pts',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Métricas Rápidas
            const Text(
              'Resumen del Sistema',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.people_alt_outlined,
                    label: 'Clientes BD',
                    value: '${clientes.length}',
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Productos demo',
                    value: '$totalProductos',
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Bajo Stock',
                    value: '$totalStockBajo',
                    color: totalStockBajo > 0
                        ? Colors.orangeAccent
                        : Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Acceso Rápido a Inventario
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/inventario'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor,
                      child: Icon(Icons.inventory_2, color: Colors.black),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Módulo de Inventario',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Existencias locales de demostración',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Clientes en la Base de Datos (veterinaria_unimar.sql)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Clientes (copia del SQL)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${clientes.length} registrados',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clientes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cliente = clientes[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white12,
                        child: Text(
                          cliente.nombreCompleto.isNotEmpty
                              ? cliente.nombreCompleto[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.nombreCompleto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'C.I: ${cliente.cedula} • Tel: ${cliente.telefono}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              cliente.email,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cliente.puntosFidelidad} pts',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigation(currentIndex: 0),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2429),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
