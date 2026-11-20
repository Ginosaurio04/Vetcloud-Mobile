const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bcrypt = require('bcryptjs');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json()); // Permite recibir datos en formato JSON

// Configuración de la conexión a MySQL.
// En tu PC usa XAMPP por defecto; en Render/TiDB se configura con variables de entorno.
// Se usa un POOL (no una sola conexión) para que el servidor no se rompa si MySQL
// cierra la conexión por inactividad.
const db = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'veterinaria_unimar',
  port: Number(process.env.DB_PORT) || 3306,
  ssl: process.env.DB_SSL === 'true'
    ? { minVersion: 'TLSv1.2', rejectUnauthorized: true }
    : undefined,
  waitForConnections: true,
  connectionLimit: 5,
  enableKeepAlive: true,
});

// Probar conexión a la Base de Datos al arrancar
db.getConnection((err, conn) => {
  if (err) {
    console.error('Error al conectar a MySQL:', err.message);
    return;
  }
  console.log('¡Conexión exitosa a MySQL!');
  conn.release();
});

// ==========================================
// BITÁCORA Y REGISTRO DE ACTIVIDAD
// ==========================================
// Render está detrás de un proxy: así req.ip trae la IP real del usuario.
app.set('trust proxy', true);

const ZONA = 'America/Caracas';
const ahora = () => new Date().toLocaleString('sv-SE', { timeZone: ZONA }); // YYYY-MM-DD HH:MM:SS

// La app no envía token, así que tras un login exitoso se recuerda "esta IP = este usuario"
// durante 12 horas (en memoria: se borra si Render reinicia o se duerme).
// Si la app envía el encabezado "x-usuario", ese valor tiene prioridad.
const SESION_MS = 12 * 60 * 60 * 1000;
const sesionesPorIp = new Map();

const ipDe = (req) => req.ip || req.socket.remoteAddress || 'desconocida';

function usuarioDe(req) {
  const cabecera = req.headers['x-usuario'];
  if (cabecera) return String(cabecera).slice(0, 100);
  const sesion = sesionesPorIp.get(ipDe(req));
  if (sesion && Date.now() - sesion.t < SESION_MS) return sesion.usuario;
  return 'anónimo';
}

// Tabla de bitácora (se crea sola si no existe)
db.query(
  `CREATE TABLE IF NOT EXISTS bitacora (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    accion VARCHAR(60) NOT NULL,
    detalle VARCHAR(500) DEFAULT NULL,
    ip VARCHAR(60) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
  (err) => {
    if (err) console.error('❌ No se pudo crear la tabla bitacora:', err.message);
  }
);

// Guarda una acción en la bitácora. Si falla, nunca interrumpe la respuesta al usuario.
function registrar(req, accion, detalle = '', usuarioForzado = null) {
  const usuario = usuarioForzado || usuarioDe(req);
  db.query(
    'INSERT INTO bitacora (fecha, usuario, accion, detalle, ip) VALUES (?, ?, ?, ?, ?)',
    [ahora(), usuario, accion, String(detalle).slice(0, 500), ipDe(req)],
    (err) => {
      if (err) console.error('❌ No se pudo guardar en bitácora:', err.message);
    }
  );
}

// Registro de TODAS las peticiones en los logs de Render (nunca se imprime el body: hay contraseñas).
// Se omite "/" porque es la ruta que visita el monitor para mantener el servidor despierto.
app.use((req, res, next) => {
  if (req.path === '/') return next();
  const inicio = Date.now();
  res.on('finish', () => {
    console.log(
      `[${ahora()}] ${req.method} ${req.originalUrl} → ${res.statusCode} ` +
      `(${Date.now() - inicio} ms) | usuario: ${usuarioDe(req)} | ip: ${ipDe(req)}`
    );
  });
  next();
});

// Ruta raíz de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: 'API VetCloud funcionando correctamente' });
});

// ==========================================
// ENDPOINTS DE CLIENTES (Estructura Completa)
// ==========================================

// 1. OBTENER todos los clientes (1 sola fila por cliente con mascotas agrupadas para el Directorio)
app.get('/api/clientes', (req, res) => {
  const sql = `
    SELECT 
      c.id_cliente AS id, 
      c.cedula,
      c.nombre_completo AS nombre, 
      c.telefono, 
      c.email,
      c.direccion,
      c.puntos_fidelidad,
      COALESCE(
        GROUP_CONCAT(CONCAT(m.nombre_animal, ' (', COALESCE(m.especie, 'Mascota'), ')') SEPARATOR ', '),
        'Sin Mascota'
      ) AS mascota 
    FROM clientes c
    LEFT JOIN mascotas m ON c.id_cliente = m.id_cliente
    GROUP BY c.id_cliente
    ORDER BY c.nombre_completo ASC
  `;
  
  db.query(sql, (err, result) => {
    if (err) {
      console.error('❌ Error al consultar clientes:', err.message);
      return res.status(500).json({ error: err.message });
    }
    res.json(result);
  });
});

// 2. OBTENER opciones desglosadas por mascota (Exclusivo para el desplegable de Citas)
app.get('/api/clientes-mascotas-citas', (req, res) => {
  const sql = `
    SELECT 
      c.id_cliente, 
      c.nombre_completo AS nombre, 
      m.id_mascota,
      COALESCE(m.nombre_animal, 'Sin Mascota') AS nombre_mascota,
      COALESCE(m.especie, 'Mascota') AS especie
    FROM clientes c
    INNER JOIN mascotas m ON c.id_cliente = m.id_cliente
    ORDER BY c.nombre_completo ASC, m.id_mascota ASC
  `;
  
  db.query(sql, (err, result) => {
    if (err) {
      console.error('❌ Error al consultar clientes para citas:', err.message);
      return res.status(500).json({ error: err.message });
    }
    res.json(result);
  });
});

// CREAR un cliente (POST) - Incluye cédula, email y dirección
app.post('/api/clientes', (req, res) => {
  const { cedula, nombre, telefono, email, direccion } = req.body;

  // Validación básica de campos requeridos
  if (!cedula || !nombre || !email || !direccion) {
    return res.status(400).json({ 
      error: 'Cédula, nombre, email y dirección son obligatorios' 
    });
  }

  const sql = `
    INSERT INTO clientes (cedula, nombre_completo, telefono, email, direccion) 
    VALUES (?, ?, ?, ?, ?)
  `;

  db.query(sql, [cedula, nombre, telefono || 'N/A', email, direccion], (err, result) => {
    if (err) {
      console.error('❌ Error al crear cliente:', err.message);
      return res.status(500).json({ error: err.message });
    }
    
    console.log(`\n👤 NUEVO CLIENTE REGISTRADO (#${result.insertId})`);
    console.log(`> Cédula: ${cedula} | Nombre: ${nombre}`);
    registrar(req, 'CLIENTE_CREADO', `${nombre} (${cedula})`);

    res.status(201).json({ 
      mensaje: 'Cliente registrado con éxito',
      id: result.insertId 
    });
  });
});

// ==========================================
// ENDPOINT DE AUTENTICACIÓN (LOGIN) CON LOGS
// ==========================================

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const horaIntento = ahora();

  console.log(`\n========================================`);
  console.log(`[${horaIntento}] INTENTO DE INICIO DE SESIÓN`);
  console.log(`> Usuario / Correo ingresado: "${username}"`);
  console.log(`========================================`);

  const sql = 'SELECT * FROM usuarios WHERE username = ? OR email = ?';

  db.query(sql, [username, username], async (err, results) => {
    if (err) {
      console.error(`❌ Error en MySQL: ${err.message}`);
      return res.status(500).json({ exito: false, mensaje: 'Error interno en el servidor' });
    }

    if (results.length === 0) {
      console.log(`⚠️  Resultado: USUARIO NO ENCONTRADO ("${username}")`);
      registrar(req, 'LOGIN_FALLIDO', 'Usuario no registrado', String(username || '').slice(0, 100));
      return res.status(401).json({
        exito: false,
        mensaje: 'Usuario o correo no registrado'
      });
    }

    const usuario = results[0];
    const esPasswordValida = await bcrypt.compare(password, usuario.password);

    if (esPasswordValida) {
      console.log(`✅ Resultado: ACCESO CONCEDIDO a ${usuario.username} (${usuario.email})`);
      sesionesPorIp.set(ipDe(req), { usuario: usuario.username, t: Date.now() });
      registrar(req, 'LOGIN', usuario.email, usuario.username);
      return res.status(200).json({
        exito: true,
        mensaje: 'Inicio de sesión exitoso',
        cliente: {
          id_cliente: usuario.id,
          nombre_completo: usuario.username,
          email: usuario.email,
          cedula: usuario.username,
          telefono: 'N/A',
          direccion: 'N/A',
          puntos_fidelidad: 0
        }
      });
    } else {
      console.log(`❌ Resultado: CONTRASEÑA INCORRECTA para ${usuario.username}`);
      registrar(req, 'LOGIN_FALLIDO', 'Contraseña incorrecta', usuario.username);
      return res.status(401).json({
        exito: false,
        mensaje: 'Contraseña incorrecta'
      });
    }
  });
});

// ==========================================
// ENDPOINTS DE CITAS MÉDICAS (Ajustados para Calendario y Desplegable)
// ==========================================

// OBTENER todas las citas (GET) - Con JOIN para traer datos de Cliente y Mascota
app.get('/api/citas', (req, res) => {
  const sql = `
    SELECT 
      ci.id_cita AS id,
      ci.id_cita,
      ci.id_mascota,
      COALESCE(cl.nombre_completo, 'Cliente General') AS cliente,
      COALESCE(m.nombre_animal, CONCAT('Mascota #', ci.id_mascota)) AS mascota,
      ci.tipo_servicio AS servicio,
      DATE_FORMAT(ci.fecha_cita, '%Y-%m-%d') AS fecha,
      TIME_FORMAT(ci.fecha_cita, '%H:%i') AS hora,
      DATE_FORMAT(ci.fecha_cita, '%d/%m/%Y %h:%i %p') AS fecha_formateada,
      COALESCE(NULLIF(ci.estado, ''), 'En Espera') AS estado,
      COALESCE(ci.observaciones, 'Sin observaciones') AS notas
    FROM citas ci
    LEFT JOIN mascotas m ON ci.id_mascota = m.id_mascota
    LEFT JOIN clientes cl ON m.id_cliente = cl.id_cliente
    ORDER BY ci.fecha_cita ASC
  `;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al consultar citas:', err.message);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// CREAR una nueva cita (POST)
app.post('/api/citas', (req, res) => {
  const { id_mascota, servicio, fecha, hora, notas } = req.body;
  const horaRegistro = ahora();

  // Se formatea fecha y hora al standard DATETIME 'YYYY-MM-DD HH:MM:SS'
  const fechaCita = `${fecha} ${hora}`;
  const mascotaId = id_mascota || 1; 

  const sql = `
    INSERT INTO citas (id_mascota, fecha_cita, tipo_servicio, estado, observaciones)
    VALUES (?, ?, ?, 'En Espera', ?)
  `;
  
  db.query(sql, [mascotaId, fechaCita, servicio, notas || 'Sin observaciones'], (err, result) => {
    if (err) {
      console.error('❌ Error al agendar cita:', err.message);
      return res.status(500).json({ error: err.message });
    }
    console.log(`\n📅 [${horaRegistro}] NUEVA CITA REGISTRADA (#${result.insertId})`);
    console.log(`> Mascota ID: ${mascotaId} | Servicio: ${servicio} | Fecha/Hora: ${fechaCita}`);
    registrar(req, 'CITA_CREADA', `#${result.insertId} | ${servicio} | ${fechaCita}`);
    
    res.status(201).json({ mensaje: 'Cita agendada con éxito', id: result.insertId });
  });
});

// CAMBIAR estado de la cita (PUT)
app.put('/api/citas/:id/estado', (req, res) => {
  const { id } = req.params;
  const { estado } = req.body;
  const horaCambio = ahora();

  const sql = 'UPDATE citas SET estado = ? WHERE id_cita = ?';
  db.query(sql, [estado, id], (err) => {
    if (err) {
      console.error('❌ Error al actualizar estado de la cita:', err.message);
      return res.status(500).json({ error: err.message });
    }
    console.log(`\n🔄 [${horaCambio}] ESTADO DE CITA ACTUALIZADO`);
    console.log(`> Cita ID #${id} cambiada a: "${estado}"`);
    registrar(req, 'CITA_ESTADO', `Cita #${id} → ${estado}`);
    
    res.json({ mensaje: 'Estado actualizado correctamente' });
  });
});

// ==========================================
// ENDPOINTS DE INVENTARIO (PRODUCTOS)
// ==========================================

// OBTENER todos los productos (GET)
app.get('/api/productos', (req, res) => {
  const sql = 'SELECT * FROM productos';
  db.query(sql, (err, results) => {
    if (err) {
      return res.status(500).json({ mensaje: 'Error al consultar productos', error: err.message });
    }
    res.json(results);
  });
});

// CREAR un nuevo producto (POST)
app.post('/api/productos', (req, res) => {
  const { codigo, nombre, categoria, stock, stock_minimo, precio, unidad, descripcion } = req.body;
  const sql = `
    INSERT INTO productos (codigo, nombre, categoria, stock, stock_minimo, precio, unidad, descripcion)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql, 
    [codigo, nombre, categoria, stock, stock_minimo, precio, unidad, descripcion], 
    (err, result) => {
      if (err) {
        if (err.code === 'ER_DUP_ENTRY') {
          return res.status(400).json({ mensaje: 'El código / SKU ya existe' });
        }
        return res.status(500).json({ mensaje: 'Error al registrar el producto', error: err.message });
      }
      registrar(req, 'PRODUCTO_CREADO', `${nombre} (${codigo})`);
      res.status(201).json({ 
        mensaje: 'Producto creado exitosamente', 
        id: result.insertId 
      });
    }
  );
});

// ACTUALIZAR el stock (+1 o -1) de un producto (PUT)
app.put('/api/productos/:id/stock', (req, res) => {
  const { id } = req.params;
  const { cantidad } = req.body;

  const sql = 'UPDATE productos SET stock = GREATEST(0, stock + ?) WHERE id = ?';

  db.query(sql, [cantidad, id], (err) => {
    if (err) {
      return res.status(500).json({ mensaje: 'Error al actualizar el stock', error: err.message });
    }
    registrar(req, 'STOCK_AJUSTE', `Producto #${id}: ${Number(cantidad) > 0 ? '+' : ''}${cantidad}`);
    res.json({ mensaje: 'Stock actualizado con éxito' });
  });
});

// ==========================================
// ENDPOINTS DE FACTURACIÓN Y VENTAS
// ==========================================

// PROCESAR FACTURA / VENTA (POST)
app.post('/api/ventas', (req, res) => {
  const { cliente, items, subtotal, iva, total, metodo_pago } = req.body;
  const fecha = ahora();

  const sqlVenta = 'INSERT INTO ventas (cliente, fecha, subtotal, iva, total, metodo_pago) VALUES (?, ?, ?, ?, ?, ?)';
  
  db.query(sqlVenta, [cliente, fecha, subtotal, iva, total, metodo_pago], (err, result) => {
    if (err) {
      console.error('❌ Error al registrar venta:', err.message);
      return res.status(500).json({ error: err.message });
    }

    const ventaId = result.insertId;

    if (Array.isArray(items)) {
      items.forEach((item) => {
        const sqlDetalle = 'INSERT INTO detalles_venta (venta_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal) VALUES (?, ?, ?, ?, ?, ?)';
        db.query(sqlDetalle, [ventaId, item.producto_id, item.nombre, item.cantidad, item.precio, item.subtotal]);

        const sqlStock = 'UPDATE productos SET stock = GREATEST(0, stock - ?) WHERE id = ?';
        db.query(sqlStock, [item.cantidad, item.producto_id]);
      });
    }

    console.log(`\n🧾 [${fecha}] NUEVA FACTURA REGISTRADA (#${ventaId})`);
    console.log(`> Cliente: ${cliente} | Total: $${total} USD (${metodo_pago})`);
    registrar(req, 'VENTA', `#${ventaId} | ${cliente} | $${total} (${metodo_pago})`);

    res.status(201).json({ mensaje: 'Factura procesada con éxito', ventaId });
  });
});

// OBTENER HISTORIAL DE VENTAS (GET)
app.get('/api/ventas', (req, res) => {
  const sql = 'SELECT * FROM ventas ORDER BY id DESC';
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Error al obtener ventas:', err.message);
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// ==========================================
// ENDPOINT DE REGISTRO DE USUARIOS (POST)
// ==========================================
app.post('/api/register', async (req, res) => {
  const { username, email, password } = req.body;
  const horaRegistro = ahora();

  if (!username || !email || !password) {
    return res.status(400).json({
      exito: false,
      mensaje: 'Todos los campos son obligatorios'
    });
  }

  try {
    // Verificar si el usuario o correo ya existen
    const sqlCheck = 'SELECT id FROM usuarios WHERE username = ? OR email = ?';
    db.query(sqlCheck, [username, email], async (err, results) => {
      if (err) {
        console.error('❌ Error en MySQL:', err.message);
        return res.status(500).json({ exito: false, mensaje: 'Error interno en el servidor' });
      }

      if (results.length > 0) {
        return res.status(409).json({
          exito: false,
          mensaje: 'El usuario o correo electrónico ya está registrado'
        });
      }

      // Encriptar contraseña con bcryptjs
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      const sqlInsert = 'INSERT INTO usuarios (username, email, password) VALUES (?, ?, ?)';
      db.query(sqlInsert, [username, email, hashedPassword], (errInsert, result) => {
        if (errInsert) {
          console.error('❌ Error al registrar usuario:', errInsert.message);
          return res.status(500).json({ exito: false, mensaje: 'Error al guardar el usuario' });
        }

        console.log(`\n🆕 [${horaRegistro}] NUEVO USUARIO REGISTRADO (#${result.insertId})`);
        console.log(`> Usuario: ${username} | Email: ${email}`);
        registrar(req, 'USUARIO_REGISTRADO', `${username} (${email})`, username);

        return res.status(201).json({
          exito: true,
          mensaje: 'Usuario creado exitosamente',
          id: result.insertId
        });
      });
    });
  } catch (error) {
    console.error('❌ Error encriptando contraseña:', error);
    return res.status(500).json({ exito: false, mensaje: 'Error interno al procesar la solicitud' });
  }
});

// ==========================================
// INICIO DEL SERVIDOR
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en el puerto ${PORT}`);
});