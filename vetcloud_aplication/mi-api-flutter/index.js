const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bcrypt = require('bcryptjs'); // Importamos bcryptjs

const app = express();

// Middlewares
app.use(cors());
app.use(express.json()); // Permite recibir datos en formato JSON

// Configuración de la conexión a MySQL en XAMPP
const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',       // Usuario por defecto de XAMPP
  password: '',       // Contraseña por defecto de XAMPP (vacía)
  database: 'veterinaria_unimar', // <-- Reemplaza por el nombre de tu BD en phpMyAdmin
  port: 3306
});

// Probar conexión
db.connect((err) => {
  if (err) {
    console.error('Error al conectar a MySQL:', err.message); // <-- Agregamos err.message
    return;
  }
  console.log('¡Conexión exitosa a MySQL de XAMPP!');
});

// Ruta de prueba (Endpoint GET)
app.get('/', (req, res) => {
  res.json({ mensaje: 'API funcionando correctamente' });
});

// Iniciar el servidor en el puerto 3000
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});

// 1. Endpoint para OBTENER todos los clientes (GET)
app.get('/api/clientes', (req, res) => {
  const sql = 'SELECT * FROM clientes';
  
  db.query(sql, (err, result) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(result);
  });
});

// 2. Endpoint para CREAR un cliente (POST)
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

// Endpoint de Login (POST)
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;

  // Busca en la tabla 'usuarios' por el campo 'username' O por el 'email'
  const sql = 'SELECT * FROM usuarios WHERE username = ? OR email = ?';

  db.query(sql, [username, username], async (err, results) => {
    if (err) {
      console.error('Error en MySQL:', err.message);
      return res.status(500).json({ exito: false, mensaje: 'Error interno en el servidor' });
    }

    // Si no encuentra el usuario/email en la BD
    if (results.length === 0) {
      return res.status(401).json({
        exito: false,
        mensaje: 'Usuario o correo no registrado'
      });
    }

    const usuario = results[0];

    // Compara la contraseña enviada desde Flutter con el hash $2y$... guardado en la BD
    const esPasswordValida = await bcrypt.compare(password, usuario.password);

    if (esPasswordValida) {
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
      return res.status(401).json({
        exito: false,
        mensaje: 'Contraseña incorrecta'
      });
    }
  });
});