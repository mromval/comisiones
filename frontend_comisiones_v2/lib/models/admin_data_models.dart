// lib/models/admin_data_models.dart
class AdminUser {
  final int id;
  final String email;
  final String nombreCompleto;
  final String rol;
  final String? nombrePerfil;
  final String? nombreEquipo;

  AdminUser({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
    this.nombrePerfil,
    this.nombreEquipo,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: int.parse(json['id'].toString()), 
      email: json['email'] as String,
      nombreCompleto: json['nombre_completo'] as String,
      rol: json['rol'] as String,
      nombrePerfil: json['nombre_perfil'] as String?,
      nombreEquipo: json['nombre_equipo'] as String?,
    );
  }
}

class AdminTeam {
  final int id;
  final String nombreEquipo;
  final String? nombreSupervisor;

  AdminTeam({
    required this.id,
    required this.nombreEquipo,
    this.nombreSupervisor,
  });

  factory AdminTeam.fromJson(Map<String, dynamic> json) {
    return AdminTeam(
      id: int.parse(json['id'].toString()),
      nombreEquipo: json['nombre_equipo'] as String,
      nombreSupervisor: json['nombre_supervisor'] as String?,
    );
  }
}

class AdminProfile {
  final int id;
  final String nombrePerfil;
  final int ordenSorteo; 

  AdminProfile({
    required this.id,
    required this.nombrePerfil,
    required this.ordenSorteo, 
  });

  factory AdminProfile.fromJson(Map<String, dynamic> json) {
    return AdminProfile(
      id: int.parse(json['id'].toString()),
      nombrePerfil: json['nombre_perfil'] as String,
      ordenSorteo: int.parse(json['orden_sorteo'].toString()), 
    );
  }
}

class AdminConcurso {
  final int id;
  final String periodoInicio;
  final String periodoFin;
  final bool estaActiva;
  final String nombrePerfil;
  final String nombreComponente;
  final String claveLogica;
  final double? requisitoMinUfTotal;
  final double? requisitoTasaRecaudacion;
  final int? requisitoMinContratos;
  final double? topeMonto;

  AdminConcurso({
    required this.id,
    required this.periodoInicio,
    required this.periodoFin,
    required this.estaActiva,
    required this.nombrePerfil,
    required this.nombreComponente,
    required this.claveLogica,
    this.requisitoMinUfTotal,
    this.requisitoTasaRecaudacion,
    this.requisitoMinContratos,
    this.topeMonto,
  });

  factory AdminConcurso.fromJson(Map<String, dynamic> json) {
    double? safeDoubleParse(dynamic val) {
      if (val == null) return null;
      return double.tryParse(val.toString());
    }
    int? safeIntParse(dynamic val) {
      if (val == null) return null;
      return int.tryParse(val.toString());
    }
    return AdminConcurso(
      id: int.parse(json['id'].toString()),
      periodoInicio: json['periodo_inicio'] as String,
      periodoFin: json['periodo_fin'] as String,
      estaActiva: (int.parse(json['esta_activa'].toString())) == 1, 
      nombrePerfil: json['nombre_perfil'] as String,
      nombreComponente: json['nombre_componente'] as String,
      claveLogica: json['clave_logica'] as String,
      requisitoMinUfTotal: safeDoubleParse(json['requisito_min_uf_total']),
      requisitoTasaRecaudacion: safeDoubleParse(json['requisito_tasa_recaudacion']),
      requisitoMinContratos: safeIntParse(json['requisito_min_contratos']),
      topeMonto: safeDoubleParse(json['tope_monto']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'periodo_inicio': periodoInicio,
      'periodo_fin': periodoFin,
      'esta_activa': estaActiva ? 1 : 0,
      'nombre_perfil': nombrePerfil,
      'nombre_componente': nombreComponente,
      'clave_logica': claveLogica,
      'requisito_min_uf_total': requisitoMinUfTotal,
      'requisito_tasa_recaudacion': requisitoTasaRecaudacion,
      'requisito_min_contratos': requisitoMinContratos,
      'tope_monto': topeMonto,
    };
  }
}

class AdminTramo {
  final int id;
  final int reglaId;
  final double tramoDesdeUf;
  final double tramoHastaUf;
  final double montoPago;

  AdminTramo({
    required this.id,
    required this.reglaId,
    required this.tramoDesdeUf,
    required this.tramoHastaUf,
    required this.montoPago,
  });

  factory AdminTramo.fromJson(Map<String, dynamic> json) {
    return AdminTramo(
      id: int.parse(json['id'].toString()),
      reglaId: int.parse(json['regla_id'].toString()),
      tramoDesdeUf: double.parse(json['tramo_desde_uf'].toString()),
      tramoHastaUf: double.parse(json['tramo_hasta_uf'].toString()),
      montoPago: double.parse(json['monto_pago'].toString()),
    );
  }
}

class AdminComponent {
  final int id;
  final String nombreComponente;
  final String claveLogica;

  AdminComponent({
    required this.id,
    required this.nombreComponente,
    required this.claveLogica,
  });

  factory AdminComponent.fromJson(Map<String, dynamic> json) {
    return AdminComponent(
      id: int.parse(json['id'].toString()),
      nombreComponente: json['nombre_componente'] as String,
      claveLogica: json['clave_logica'] as String,
    );
  }
}

class AdminConfig {
  final String llave;
  final String? valor; 

  AdminConfig({
    required this.llave,
    this.valor, 
  });

  factory AdminConfig.fromJson(Map<String, dynamic> json) {
    return AdminConfig(
      llave: json['llave'] as String,
      valor: json['valor'] as String?, 
    );
  }
}

// --- ¡NUEVO MODELO AÑADIDO! ---
class AdminMetrica {
  final int usuarioId;
  final String nombreMetrica;
  final double valor;

  AdminMetrica({
    required this.usuarioId,
    required this.nombreMetrica,
    required this.valor,
  });

  factory AdminMetrica.fromJson(Map<String, dynamic> json) {
    return AdminMetrica(
      usuarioId: int.parse(json['usuario_id'].toString()),
      nombreMetrica: json['nombre_metrica'] as String,
      valor: double.parse(json['valor'].toString()),
    );
  }
}