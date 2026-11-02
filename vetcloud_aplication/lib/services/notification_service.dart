import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class NotificationService {
  static Future<void> mostrarNotificacionInmediata({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    // Si la app se ejecuta en Web (Chrome), se ignora el envío nativo
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'citas_channel',
          'Notificaciones de Citas',
          channelDescription:
              'Canal para recordatorios y confirmaciones de citas',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // 🟢 Sintaxis con parámetros nombrados id:, title:, body:
    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: titulo,
      body: cuerpo,
      notificationDetails: notificationDetails,
    );
  }

  static Future<void> cancelarNotificacion(int id) async {
    if (kIsWeb) return;

    // 🟢 Sintaxis con parámetro nombrado id:
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
