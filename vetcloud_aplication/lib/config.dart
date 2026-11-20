// lib/config.dart
//
// URL del backend. Cambia el defaultValue por la URL que te dé Render, o pásala al
// compilar:  flutter build apk --release --dart-define=API_URL=https://tu-api.onrender.com
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://TU-API.onrender.com',
);

// Render (plan gratis) tarda ~1 minuto en despertar tras estar inactivo.
const Duration kApiTimeout = Duration(seconds: 60);
