/// Modelo para representar una transacción de Pago Móvil
class PagoMovilTransaction {
  final String orderNumber;
  final String bankAba;
  final String phoneCliente;
  final String phoneComercio;
  final double monto;
  final String cedulaCliente;
  final String referencia;
  final DateTime createdAt;
  final PagoMovilStatus status;
  final String? errorMessage;
  final String? responseCode;
  final String? responseMessage;
  
  PagoMovilTransaction({
    required this.orderNumber,
    required this.bankAba,
    required this.phoneCliente,
    required this.phoneComercio,
    required this.monto,
    required this.cedulaCliente,
    this.referencia = '',
    DateTime? createdAt,
    this.status = PagoMovilStatus.pending,
    this.errorMessage,
    this.responseCode,
    this.responseMessage,
  }) : createdAt = createdAt ?? DateTime.now();
  
  PagoMovilTransaction copyWith({
    String? orderNumber,
    String? bankAba,
    String? phoneCliente,
    String? phoneComercio,
    double? monto,
    String? cedulaCliente,
    String? referencia,
    DateTime? createdAt,
    PagoMovilStatus? status,
    String? errorMessage,
    String? responseCode,
    String? responseMessage,
  }) {
    return PagoMovilTransaction(
      orderNumber: orderNumber ?? this.orderNumber,
      bankAba: bankAba ?? this.bankAba,
      phoneCliente: phoneCliente ?? this.phoneCliente,
      phoneComercio: phoneComercio ?? this.phoneComercio,
      monto: monto ?? this.monto,
      cedulaCliente: cedulaCliente ?? this.cedulaCliente,
      referencia: referencia ?? this.referencia,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      responseCode: responseCode ?? this.responseCode,
      responseMessage: responseMessage ?? this.responseMessage,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'bankAba': bankAba,
      'phoneCliente': phoneCliente,
      'phoneComercio': phoneComercio,
      'monto': monto,
      'cedulaCliente': cedulaCliente,
      'referencia': referencia,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString(),
      'errorMessage': errorMessage,
      'responseCode': responseCode,
      'responseMessage': responseMessage,
    };
  }
  
  factory PagoMovilTransaction.fromMap(Map<String, dynamic> map) {
    return PagoMovilTransaction(
      orderNumber: map['orderNumber'] as String,
      bankAba: map['bankAba'] as String,
      phoneCliente: map['phoneCliente'] as String,
      phoneComercio: map['phoneComercio'] as String,
      monto: (map['monto'] as num).toDouble(),
      cedulaCliente: map['cedulaCliente'] as String,
      referencia: map['referencia'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      status: _statusFromString(map['status'] as String),
      errorMessage: map['errorMessage'] as String?,
      responseCode: map['responseCode'] as String?,
      responseMessage: map['responseMessage'] as String?,
    );
  }
  
  static PagoMovilStatus _statusFromString(String status) {
    switch (status) {
      case 'PagoMovilStatus.pending':
        return PagoMovilStatus.pending;
      case 'PagoMovilStatus.processing':
        return PagoMovilStatus.processing;
      case 'PagoMovilStatus.approved':
        return PagoMovilStatus.approved;
      case 'PagoMovilStatus.rejected':
        return PagoMovilStatus.rejected;
      case 'PagoMovilStatus.timeout':
        return PagoMovilStatus.timeout;
      case 'PagoMovilStatus.error':
        return PagoMovilStatus.error;
      default:
        return PagoMovilStatus.pending;
    }
  }
}

enum PagoMovilStatus {
  pending,
  processing,
  approved,
  rejected,
  timeout,
  error,
}

extension PagoMovilStatusExtension on PagoMovilStatus {
  String get displayName {
    switch (this) {
      case PagoMovilStatus.pending:
        return 'Pendiente';
      case PagoMovilStatus.processing:
        return 'Procesando';
      case PagoMovilStatus.approved:
        return 'Aprobado';
      case PagoMovilStatus.rejected:
        return 'Rechazado';
      case PagoMovilStatus.timeout:
        return 'Expirado';
      case PagoMovilStatus.error:
        return 'Error';
    }
  }
  
  String get emoji {
    switch (this) {
      case PagoMovilStatus.pending:
        return '⏳';
      case PagoMovilStatus.processing:
        return '🔄';
      case PagoMovilStatus.approved:
        return '✅';
      case PagoMovilStatus.rejected:
        return '❌';
      case PagoMovilStatus.timeout:
        return '⏰';
      case PagoMovilStatus.error:
        return '⚠️';
    }
  }
}

class BancoVenezolano {
  final String codigo;
  final String nombre;
  
  const BancoVenezolano({
    required this.codigo,
    required this.nombre,
  });
  
  static const List<BancoVenezolano> bancos = [
    BancoVenezolano(codigo: '0102', nombre: 'Banco de Venezuela'),
    BancoVenezolano(codigo: '0104', nombre: 'Banco Venezolano de Crédito'),
    BancoVenezolano(codigo: '0105', nombre: 'Banco Mercantil'),
    BancoVenezolano(codigo: '0108', nombre: 'Banco Provincial'),
    BancoVenezolano(codigo: '0114', nombre: 'Bancaribe'),
    BancoVenezolano(codigo: '0115', nombre: 'Banco Exterior'),
    BancoVenezolano(codigo: '0128', nombre: 'Banco Caroní'),
    BancoVenezolano(codigo: '0134', nombre: 'Banesco'),
    BancoVenezolano(codigo: '0137', nombre: 'Banco Sofitasa'),
    BancoVenezolano(codigo: '0138', nombre: 'Banco Plaza'),
    BancoVenezolano(codigo: '0146', nombre: 'Banco de la Gente Emprendedora'),
    BancoVenezolano(codigo: '0151', nombre: 'Banco Fondo Común (BFC)'),
    BancoVenezolano(codigo: '0156', nombre: '100% Banco'),
    BancoVenezolano(codigo: '0157', nombre: 'Banco Del Sur'),
    BancoVenezolano(codigo: '0163', nombre: 'Banco del Tesoro'),
    BancoVenezolano(codigo: '0166', nombre: 'Banco Agrícola de Venezuela'),
    BancoVenezolano(codigo: '0168', nombre: 'Bancrecer'),
    BancoVenezolano(codigo: '0169', nombre: 'Mi Banco'),
    BancoVenezolano(codigo: '0171', nombre: 'Banco Activo'),
    BancoVenezolano(codigo: '0172', nombre: 'Bancamiga'),
    BancoVenezolano(codigo: '0173', nombre: 'Banco Internacional de Desarrollo'),
    BancoVenezolano(codigo: '0174', nombre: 'Banplus'),
    BancoVenezolano(codigo: '0175', nombre: 'Banco Bicentenario'),
    BancoVenezolano(codigo: '0177', nombre: 'Banco de la Fuerza Armada Nacional Bolivariana'),
    BancoVenezolano(codigo: '0191', nombre: 'Banco Nacional de Crédito (BNC)'),
  ];
  
  static BancoVenezolano? findByCodigo(String codigo) {
    try {
      return bancos.firstWhere((b) => b.codigo == codigo);
    } catch (e) {
      return null;
    }
  }
}
