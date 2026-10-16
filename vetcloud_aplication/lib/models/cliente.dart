class Cliente {
  final int idCliente;
  final String cedula;
  final String nombreCompleto;
  final String telefono;
  final String email;
  final String direccion;
  final int puntosFidelidad;
  final String fechaRegistro;

  const Cliente({
    required this.idCliente,
    required this.cedula,
    required this.nombreCompleto,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.puntosFidelidad,
    required this.fechaRegistro,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      idCliente: map['id_cliente'] as int? ?? 0,
      cedula: map['cedula'] as String? ?? '',
      nombreCompleto: map['nombre_completo'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      email: map['email'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      puntosFidelidad: map['puntos_fidelidad'] as int? ?? 0,
      fechaRegistro: map['fecha_registro'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'cedula': cedula,
      'nombre_completo': nombreCompleto,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'puntos_fidelidad': puntosFidelidad,
      'fecha_registro': fechaRegistro,
    };
  }
}
