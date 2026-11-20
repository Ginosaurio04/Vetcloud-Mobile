// lib/config.dart
//
// URL del backend (Render). Es el único lugar donde se escribe; todas las
// pantallas la usan a través de kApiUrl. Sin "/" al final.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://vetcloud-mobile.onrender.com',
);

// Render (plan gratis) tarda ~1 minuto en despertar tras estar inactivo.
const Duration kApiTimeout = Duration(seconds: 60);
