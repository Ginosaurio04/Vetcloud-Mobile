import 'package:flutter/material.dart';

class MenuOptions {
  final String title;
  final IconData icon;
  final Widget screen;
  final String route;

  MenuOptions({
    required this.title,
    required this.icon,
    required this.screen,
    required this.route,
  });
}
