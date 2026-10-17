import 'package:flutter/material.dart';
import '../models/menu_options.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/inventario_screen.dart';

class AppRoutes {
  // 1. Ruta inicial en minúsculas para mantener consistencia
  static const initialRoute = '/login';

  static final menuOptions = <MenuOptions>[
    MenuOptions(
      route: '/home',
      icon: Icons.home_outlined,
      title: 'Home',
      screen: const HomeScreen(),
    ),
    MenuOptions(
      route: '/inventario',
      icon: Icons.inventory_2_outlined,
      title: 'Inventario',
      screen: const InventarioScreen(),
    ),
  ];

  static Map<String, Widget Function(BuildContext)> getAppRoutes() {
    Map<String, Widget Function(BuildContext)> appRoutes = {};

    // 2. Definición explícita de rutas (todas en minúsculas)
    appRoutes.addAll({
      '/login': (BuildContext context) => const LoginScreen(),
      '/home': (BuildContext context) => const HomeScreen(),
      '/inventario': (BuildContext context) => const InventarioScreen(),
    });

    // Rutas dinámicas desde menuOptions
    for (final option in menuOptions) {
      appRoutes.addAll({option.route: (BuildContext context) => option.screen});
    }

    return appRoutes;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      case '/inventario':
        return MaterialPageRoute(
          builder: (context) => const InventarioScreen(),
        );
      case '/home':
        return MaterialPageRoute(builder: (context) => const HomeScreen());
      default:
        // Si no se encuentra la ruta, redirige al Login en lugar de al Home
        return MaterialPageRoute(builder: (context) => const LoginScreen());
    }
  }
}
