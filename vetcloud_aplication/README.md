# VetCloud Móvil

Aplicación Flutter de demostración para la Veterinaria Unimar.

## Ejecutar y validar

Desde esta carpeta:

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

## Datos de demostración

`database/veterinaria_unimar.sql` define únicamente la tabla `clientes`. La app
incluye una copia local de esos clientes para la demostración; no se conecta
directamente a MySQL.

El acceso local acepta el correo o la cédula de un cliente precargado y la
contraseña de demostración `123456`. El SQL no tiene contraseñas ni roles, por
lo que este acceso no debe usarse en producción.

El inventario también es local: el SQL no define una tabla de productos y los
cambios hechos en la app no persisten al cerrarla. Para producción se necesita
un backend seguro con autenticación y endpoints de clientes e inventario.
