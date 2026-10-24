import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetcloud_aplication/main.dart';

void main() {
  testWidgets('Login screen is shown on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('VetCloud'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);

    final accountChip = find.widgetWithText(ActionChip, 'Gino Cova');
    await tester.ensureVisible(accountChip);
    await tester.tap(accountChip);
    await tester.pump();
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de vuelta,'), findsOneWidget);
    expect(find.text('Gino Cova'), findsWidgets);
  });
}
