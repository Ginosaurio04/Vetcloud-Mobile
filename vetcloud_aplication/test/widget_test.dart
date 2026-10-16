import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetcloud_aplication/data/veterinaria_database.dart';
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

  test('Demo login requires the demo password and matches SQL clients', () {
    final database = VeterinariaDatabase.instance;

    expect(database.autenticar('gino.cova@email.com', 'incorrecta'), isFalse);
    expect(database.autenticar('cuenta-inexistente', '123456'), isFalse);
    expect(database.autenticar('V12345678', '123456'), isTrue);
    expect(database.usuarioActual?.nombreCompleto, 'Gino Cova');
  });
}
