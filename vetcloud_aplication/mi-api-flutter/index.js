const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bcrypt = require('bcryptjs');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json()); // Permite recibir datos en formato JSON

// Configuración de la conexión a MySQL en XAMPP
const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',       // Usuario por defecto de XAMPP
  password: '',       // Contraseña por defecto de XAMPP (vacía)
  database: 'veterinaria_unimar',
  port: 3306
});

// Probar conexión y preparar tablas
db.connect((err) => {
  if (err) {
    console.error('Error al conectar a MySQL:', err.message);
    return;
  }
  console.log('¡Conexión exitosa a MySQL de XAMPP!');

  // Crear la tabla de productos automáticamente si no existe
  const sqlCrearTabla = `
    CREATE TABLE IF NOT EXISTS productos (
      id INT AUTO_INCREMENT PRIMARY KEY,
      codigo VARCHAR(50) UNIQUE NOT NULL,
      nombre VARCHAR(100) NOT NULL,
      categoria VARCHAR(50) NOT NULL,
      stock INT DEFAULT 0,
      stock_minimo INT DEFAULT 5,
      precio DECIMAL(10, 2) NOT NULL,
      unidad VARCHAR(30) DEFAULT 'Unidad',
      descripcion TEXT
    );
  `;
  db.query(sqlCrearTabla, (err) => {
    if (err) console.error('Error al verificar/crear tabla productos:', err.message);
  });
});

// Ruta raíz de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: 'API VetCloud funcionando correctamente' });
});

// ==========================================
// ENDPOINTS DE CLIENTES
// ==========================================

// OBTENER todos los clientes (GET)
app.get('/api/clientes', (req, res) => {
  const sql = 'SELECT * FROM clientes';
  
  db.query(sql, (err, result) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(result);
  });
});

// CREAR un cliente (POST)
app.post('/api/clientes', (req, res) => {
  const { nombre, telefono, mascota } = req.body;
  const sql = 'INSERT INTO clientes (nombre, telefono, mascota) VALUES (?, ?, ?)';

  db.query(sql, [nombre, telefono, mascota], (err, result) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
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
  const horaIntento = new Date().toLocaleTimeString();

  // Registro detallado en consola
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
      return res.status(401).json({
        exito: false,
        mensaje: 'Usuario o correo no registrado'
      });
    }

    const usuario = results[0];
    const esPasswordValida = await bcrypt.compare(password, usuario.password);

    if (esPasswordValida) {
      console.log(`✅ Resultado: ACCESO CONCEDIDO a ${usuario.username} (${usuario.email})`);
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
      return res.status(401).json({
        exito: false,
        mensaje: 'Contraseña incorrecta'
      });
    }
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
  const { cantidad } = req.body; // Recibe +1 o -1

  const sql = 'UPDATE productos SET stock = GREATEST(0, stock + ?) WHERE id = ?';

  db.query(sql, [cantidad, id], (err) => {
    if (err) {
      return res.status(500).json({ mensaje: 'Error al actualizar el stock', error: err.message });
    }
    res.json({ mensaje: 'Stock actualizado con éxito' });
  });
});

// ==========================================
// INICIO DEL SERVIDOR
// ==========================================
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});