import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetCloud - Veterinaria Unimar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF14191F),
        primaryColor: const Color(0xFF0DCF7E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0DCF7E),
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.getAppRoutes(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
