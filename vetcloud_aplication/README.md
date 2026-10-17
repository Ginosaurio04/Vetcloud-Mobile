# VetCloud Móvil

Aplicación Flutter de demostración para la Veterinaria Unimar.

## Ejecutar y validar

Abre la carpeta `vetcloud_aplication` en VS Code (no ejecutes `main.dart` con
**Code Runner**). Usa **F5** y selecciona `VetCloud (Chrome)` para previsualizar,
o `VetCloud (Android)` cuando haya un dispositivo conectado.

Desde una terminal abierta en esta carpeta:

```powershell
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build apk --debug
```

En VS Code también puedes usar **Terminal > Run Build Task** para compilar el
APK debug. Se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

Para ejecutar en Android, instala Android SDK Command-line Tools desde Android
Studio y acepta las licencias con `flutter doctor --android-licenses`. Verifica
la configuración con `flutter doctor` y conecta un teléfono con depuración USB
o inicia un emulador Android.

## Datos de demostración

`database/veterinaria_unimar.sql` define únicamente la tabla `clientes`. La app
incluye una copia local de esos clientes para la demostración; no se conecta
directamente a MySQL.

El acceso actual es una demostración local. El SQL no tiene contraseñas ni
roles, así que la base de datos todavía no puede autenticar el login. Para
conectarlo hace falta una API/backend seguro; no pongas credenciales MySQL en
la aplicación Flutter.

El inventario también es local: el SQL no define una tabla de productos y los
cambios hechos en la app no persisten al cerrarla. Para producción se necesita
un backend seguro con autenticación y endpoints de clientes e inventario.
