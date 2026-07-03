import '../sync/models/syncable_model.dart';
import '../sync/enums/sync_status.dart';

// =============================================================================
// ENUMS
// =============================================================================

enum EstadoSesionFiscal { abierta, cerrada }

extension EstadoSesionFiscalExtension on EstadoSesionFiscal {
  String toDbString() {
    switch (this) {
      case EstadoSesionFiscal.abierta:
        return 'ABIERTA';
      case EstadoSesionFiscal.cerrada:
        return 'CERRADA';
    }
  }

  static EstadoSesionFiscal fromDbString(String? value) {
    if (value == 'CERRADA') {
      return EstadoSesionFiscal.cerrada;
    }
    return EstadoSesionFiscal.abierta;
  }
}

enum EstadoSyncSeniat { pendiente, enviado, aprobado, rechazado }

extension EstadoSyncSeniatExtension on EstadoSyncSeniat {
  String toDbString() {
    switch (this) {
      case EstadoSyncSeniat.pendiente:
        return 'PENDIENTE';
      case EstadoSyncSeniat.enviado:
        return 'ENVIADO';
      case EstadoSyncSeniat.aprobado:
        return 'APROBADO';
      case EstadoSyncSeniat.rechazado:
        return 'RECHAZADO';
    }
  }

  static EstadoSyncSeniat fromDbString(String? value) {
    switch (value) {
      case 'ENVIADO':
        return EstadoSyncSeniat.enviado;
      case 'APROBADO':
        return EstadoSyncSeniat.aprobado;
      case 'RECHAZADO':
        return EstadoSyncSeniat.rechazado;
      default:
        return EstadoSyncSeniat.pendiente;
    }
  }
}

// =============================================================================
// CLASE SESION FISCAL
// =============================================================================

class SesionFiscal extends SyncableModel {
  final int? id;
  final String numeroSesion;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final int usuarioAperturaId;
  final String usuarioAperturaNombre;
  final int? usuarioCierreId;
  final String? usuarioCierreNombre;
  final EstadoSesionFiscal estado;
  
  // Totales
  final double totalVentas;
  final double totalNotasCredito;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalPagoMovil;
  final double totalOtrosMetodos;
  
  // Totales Fiscales
  final double totalBaseImponible;
  final double totalIva;
  final double totalExento;
  final double totalGeneral;
  
  // Contadores
  final int cantidadFacturas;
  final int cantidadNotasCredito;
  final int cantidadTransacciones;
  
  // Rangos
  final String? facturaInicial;
  final String? facturaFinal;
  final String? ncInicial;
  final String? ncFinal;
  
  // Arqueo y Gastos
  final bool arqueoRealizado;
  final int? arqueoId;
  final double fondoCajaInicial;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  const SesionFiscal({
    this.id,
    required this.numeroSesion,
    required this.fechaApertura,
    this.fechaCierre,
    required this.usuarioAperturaId,
    required this.usuarioAperturaNombre,
    this.usuarioCierreId,
    this.usuarioCierreNombre,
    this.estado = EstadoSesionFiscal.abierta,
    this.totalVentas = 0.0,
    this.totalNotasCredito = 0.0,
    this.totalEfectivo = 0.0,
    this.totalTarjeta = 0.0,
    this.totalPagoMovil = 0.0,
    this.totalOtrosMetodos = 0.0,
    this.totalBaseImponible = 0.0,
    this.totalIva = 0.0,
    this.totalExento = 0.0,
    this.totalGeneral = 0.0,
    this.cantidadFacturas = 0,
    this.cantidadNotasCredito = 0,
    this.cantidadTransacciones = 0,
    this.facturaInicial,
    this.facturaFinal,
    this.ncInicial,
    this.ncFinal,
    this.arqueoRealizado = false,
    this.arqueoId,
    this.fondoCajaInicial = 0.0,
    required this.createdAt,
    required this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  bool get isAbierta => estado == EstadoSesionFiscal.abierta;
  bool get isCerrada => estado == EstadoSesionFiscal.cerrada;

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'numero_sesion': numeroSesion,
        'fecha_apertura': fechaApertura.toIso8601String(),
        'fecha_cierre': fechaCierre?.toIso8601String(),
        'usuario_apertura_id': usuarioAperturaId,
        'usuario_apertura_nombre': usuarioAperturaNombre,
        'usuario_cierre_id': usuarioCierreId,
        'usuario_cierre_nombre': usuarioCierreNombre,
        'estado': estado.toDbString(),
        'total_ventas': totalVentas,
        'total_notas_credito': totalNotasCredito,
        'total_efectivo': totalEfectivo,
        'total_tarjeta': totalTarjeta,
        'total_pago_movil': totalPagoMovil,
        'total_otros_metodos': totalOtrosMetodos,
        'total_base_imponible': totalBaseImponible,
        'total_iva': totalIva,
        'total_exento': totalExento,
        'total_general': totalGeneral,
        'cantidad_facturas': cantidadFacturas,
        'cantidad_notas_credito': cantidadNotasCredito,
        'cantidad_transacciones': cantidadTransacciones,
        'factura_inicial': facturaInicial,
        'factura_final': facturaFinal,
        'nc_inicial': ncInicial,
        'nc_final': ncFinal,
        'arqueo_realizado': arqueoRealizado ? 1 : 0,
        'arqueo_id': arqueoId,
        'fondo_caja_inicial': fondoCajaInicial,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'numero_sesion': numeroSesion,
        'fecha_apertura': fechaApertura.toIso8601String(),
        'fecha_cierre': fechaCierre?.toIso8601String(),
        'usuario_apertura_id': usuarioAperturaId,
        'usuario_apertura_nombre': usuarioAperturaNombre,
        'usuario_cierre_id': usuarioCierreId,
        'usuario_cierre_nombre': usuarioCierreNombre,
        'estado': estado.toDbString(),
        'total_ventas': totalVentas,
        'total_notas_credito': totalNotasCredito,
        'total_efectivo': totalEfectivo,
        'total_tarjeta': totalTarjeta,
        'total_pago_movil': totalPagoMovil,
        'total_otros_metodos': totalOtrosMetodos,
        'total_base_imponible': totalBaseImponible,
        'total_iva': totalIva,
        'total_exento': totalExento,
        'total_general': totalGeneral,
        'cantidad_facturas': cantidadFacturas,
        'cantidad_notas_credito': cantidadNotasCredito,
        'cantidad_transacciones': cantidadTransacciones,
        'factura_inicial': facturaInicial,
        'factura_final': facturaFinal,
        'nc_inicial': ncInicial,
        'nc_final': ncFinal,
        'arqueo_realizado': arqueoRealizado,
        'arqueo_id': arqueoId,
        'fondo_caja_inicial': fondoCajaInicial,
        ...syncRemoteFields,
      };

  factory SesionFiscal.fromLocalMap(Map<String, dynamic> m) => SesionFiscal(
        id: m['id'] as int?,
        numeroSesion: m['numero_sesion'] as String,
        fechaApertura: DateTime.parse(m['fecha_apertura'] as String),
        fechaCierre: m['fecha_cierre'] != null
            ? DateTime.parse(m['fecha_cierre'] as String)
            : null,
        usuarioAperturaId: m['usuario_apertura_id'] as int,
        usuarioAperturaNombre: m['usuario_apertura_nombre'] as String,
        usuarioCierreId: m['usuario_cierre_id'] as int?,
        usuarioCierreNombre: m['usuario_cierre_nombre'] as String?,
        estado: EstadoSesionFiscalExtension.fromDbString(m['estado'] as String?),
        totalVentas: (m['total_ventas'] as num? ?? 0.0).toDouble(),
        totalNotasCredito: (m['total_notas_credito'] as num? ?? 0.0).toDouble(),
        totalEfectivo: (m['total_efectivo'] as num? ?? 0.0).toDouble(),
        totalTarjeta: (m['total_tarjeta'] as num? ?? 0.0).toDouble(),
        totalPagoMovil: (m['total_pago_movil'] as num? ?? 0.0).toDouble(),
        totalOtrosMetodos: (m['total_otros_metodos'] as num? ?? 0.0).toDouble(),
        totalBaseImponible: (m['total_base_imponible'] as num? ?? 0.0).toDouble(),
        totalIva: (m['total_iva'] as num? ?? 0.0).toDouble(),
        totalExento: (m['total_exento'] as num? ?? 0.0).toDouble(),
        totalGeneral: (m['total_general'] as num? ?? 0.0).toDouble(),
        cantidadFacturas: m['cantidad_facturas'] as int? ?? 0,
        cantidadNotasCredito: m['cantidad_notas_credito'] as int? ?? 0,
        cantidadTransacciones: m['cantidad_transacciones'] as int? ?? 0,
        facturaInicial: m['factura_inicial'] as String?,
        facturaFinal: m['factura_final'] as String?,
        ncInicial: m['nc_inicial'] as String?,
        ncFinal: m['nc_final'] as String?,
        arqueoRealizado: m['arqueo_realizado'] == 1,
        arqueoId: m['arqueo_id'] as int?,
        fondoCajaInicial: (m['fondo_caja_inicial'] as num? ?? 0.0).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory SesionFiscal.fromRemoteMap(Map<String, dynamic> m) =>
      SesionFiscal.fromLocalMap({
        ...m,
        'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': m['updated_at'] ?? DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.synced.toInt()
      });

  @override
  SesionFiscal copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      SesionFiscal(
        id: id,
        numeroSesion: numeroSesion,
        fechaApertura: fechaApertura,
        fechaCierre: fechaCierre,
        usuarioAperturaId: usuarioAperturaId,
        usuarioAperturaNombre: usuarioAperturaNombre,
        usuarioCierreId: usuarioCierreId,
        usuarioCierreNombre: usuarioCierreNombre,
        estado: estado,
        totalVentas: totalVentas,
        totalNotasCredito: totalNotasCredito,
        totalEfectivo: totalEfectivo,
        totalTarjeta: totalTarjeta,
        totalPagoMovil: totalPagoMovil,
        totalOtrosMetodos: totalOtrosMetodos,
        totalBaseImponible: totalBaseImponible,
        totalIva: totalIva,
        totalExento: totalExento,
        totalGeneral: totalGeneral,
        cantidadFacturas: cantidadFacturas,
        cantidadNotasCredito: cantidadNotasCredito,
        cantidadTransacciones: cantidadTransacciones,
        facturaInicial: facturaInicial,
        facturaFinal: facturaFinal,
        ncInicial: ncInicial,
        ncFinal: ncFinal,
        arqueoRealizado: arqueoRealizado,
        arqueoId: arqueoId,
        fondoCajaInicial: fondoCajaInicial,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// CLASE REPORTE CIERRE
// =============================================================================

class ReporteCierre extends SyncableModel {
  final int? id;
  final int sesionFiscalId;
  final String numeroReporte;
  final DateTime fechaReporte;
  final int facturasEmitidas;
  final int notasCreditoEmitidas;
  final double totalVentas;
  final double totalNotasCredito;
  final double totalNeto;
  final double iva16;
  final double iva8;
  final double ivaTotal;
  final double exento;
  final double desgloseEfectivo;
  final double desgloseTarjeta;
  final double desglosePagoMovil;
  final double desgloseOtros;
  final String rifComercio;
  final String nombreComercio;
  final String direccionComercio;
  final String? hashIntegridad;
  final String? seniatSyncId;
  final DateTime? seniatSyncFecha;
  final EstadoSyncSeniat seniatSyncEstado;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReporteCierre({
    this.id,
    required this.sesionFiscalId,
    required this.numeroReporte,
    required this.fechaReporte,
    this.facturasEmitidas = 0,
    this.notasCreditoEmitidas = 0,
    this.totalVentas = 0.0,
    this.totalNotasCredito = 0.0,
    this.totalNeto = 0.0,
    this.iva16 = 0.0,
    this.iva8 = 0.0,
    this.ivaTotal = 0.0,
    this.exento = 0.0,
    this.desgloseEfectivo = 0.0,
    this.desgloseTarjeta = 0.0,
    this.desglosePagoMovil = 0.0,
    this.desgloseOtros = 0.0,
    required this.rifComercio,
    required this.nombreComercio,
    required this.direccionComercio,
    this.hashIntegridad,
    this.seniatSyncId,
    this.seniatSyncFecha,
    this.seniatSyncEstado = EstadoSyncSeniat.pendiente,
    required this.createdAt,
    required this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'sesion_fiscal_id': sesionFiscalId,
        'numero_reporte': numeroReporte,
        'fecha_reporte': fechaReporte.toIso8601String(),
        'facturas_emitidas': facturasEmitidas,
        'notas_credito_emitidas': notasCreditoEmitidas,
        'total_ventas': totalVentas,
        'total_notas_credito': totalNotasCredito,
        'total_neto': totalNeto,
        'iva_16': iva16,
        'iva_8': iva8,
        'iva_total': ivaTotal,
        'exento': exento,
        'desglose_efectivo': desgloseEfectivo,
        'desglose_tarjeta': desgloseTarjeta,
        'desglose_pago_movil': desglosePagoMovil,
        'desglose_otros': desgloseOtros,
        'rif_comercio': rifComercio,
        'nombre_comercio': nombreComercio,
        'direccion_comercio': direccionComercio,
        'hash_integridad': hashIntegridad,
        'seniat_sync_id': seniatSyncId,
        'seniat_sync_fecha': seniatSyncFecha?.toIso8601String(),
        'seniat_sync_estado': seniatSyncEstado.toDbString(),
        'created_at': createdAt.toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'sesion_fiscal_id': sesionFiscalId,
        'numero_reporte': numeroReporte,
        'fecha_reporte': fechaReporte.toIso8601String(),
        'facturas_emitidas': facturasEmitidas,
        'notas_credito_emitidas': notasCreditoEmitidas,
        'total_ventas': totalVentas,
        'total_notas_credito': totalNotasCredito,
        'total_neto': totalNeto,
        'iva_16': iva16,
        'iva_8': iva8,
        'iva_total': ivaTotal,
        'exento': exento,
        'desglose_efectivo': desgloseEfectivo,
        'desglose_tarjeta': desgloseTarjeta,
        'desglose_pago_movil': desglosePagoMovil,
        'desglose_otros': desgloseOtros,
        'rif_comercio': rifComercio,
        'nombre_comercio': nombreComercio,
        'direccion_comercio': direccionComercio,
        'hash_integridad': hashIntegridad,
        'seniat_sync_id': seniatSyncId,
        'seniat_sync_fecha': seniatSyncFecha?.toIso8601String(),
        'seniat_sync_estado': seniatSyncEstado.toDbString(),
        ...syncRemoteFields,
      };

  factory ReporteCierre.fromLocalMap(Map<String, dynamic> m) => ReporteCierre(
        id: m['id'] as int?,
        sesionFiscalId: m['sesion_fiscal_id'] as int,
        numeroReporte: m['numero_reporte'] as String,
        fechaReporte: DateTime.parse(m['fecha_reporte'] as String),
        facturasEmitidas: m['facturas_emitidas'] as int? ?? 0,
        notasCreditoEmitidas: m['notas_credito_emitidas'] as int? ?? 0,
        totalVentas: (m['total_ventas'] as num? ?? 0.0).toDouble(),
        totalNotasCredito: (m['total_notas_credito'] as num? ?? 0.0).toDouble(),
        totalNeto: (m['total_neto'] as num? ?? 0.0).toDouble(),
        iva16: (m['iva_16'] as num? ?? 0.0).toDouble(),
        iva8: (m['iva_8'] as num? ?? 0.0).toDouble(),
        ivaTotal: (m['iva_total'] as num? ?? 0.0).toDouble(),
        exento: (m['exento'] as num? ?? 0.0).toDouble(),
        desgloseEfectivo: (m['desglose_efectivo'] as num? ?? 0.0).toDouble(),
        desgloseTarjeta: (m['desglose_tarjeta'] as num? ?? 0.0).toDouble(),
        desglosePagoMovil: (m['desglose_pago_movil'] as num? ?? 0.0).toDouble(),
        desgloseOtros: (m['desglose_otros'] as num? ?? 0.0).toDouble(),
        rifComercio: m['rif_comercio'] as String? ?? '',
        nombreComercio: m['nombre_comercio'] as String? ?? '',
        direccionComercio: m['direccion_comercio'] as String? ?? '',
        hashIntegridad: m['hash_integridad'] as String?,
        seniatSyncId: m['seniat_sync_id'] as String?,
        seniatSyncFecha: m['seniat_sync_fecha'] != null
            ? DateTime.parse(m['seniat_sync_fecha'] as String)
            : null,
        seniatSyncEstado: EstadoSyncSeniatExtension.fromDbString(m['seniat_sync_estado'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory ReporteCierre.fromRemoteMap(Map<String, dynamic> m) =>
      ReporteCierre.fromLocalMap({
        ...m,
        'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': m['updated_at'] ?? DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.synced.toInt()
      });

  @override
  ReporteCierre copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      ReporteCierre(
        id: id,
        sesionFiscalId: sesionFiscalId,
        numeroReporte: numeroReporte,
        fechaReporte: fechaReporte,
        facturasEmitidas: facturasEmitidas,
        notasCreditoEmitidas: notasCreditoEmitidas,
        totalVentas: totalVentas,
        totalNotasCredito: totalNotasCredito,
        totalNeto: totalNeto,
        iva16: iva16,
        iva8: iva8,
        ivaTotal: ivaTotal,
        exento: exento,
        desgloseEfectivo: desgloseEfectivo,
        desgloseTarjeta: desgloseTarjeta,
        desglosePagoMovil: desglosePagoMovil,
        desgloseOtros: desgloseOtros,
        rifComercio: rifComercio,
        nombreComercio: nombreComercio,
        direccionComercio: direccionComercio,
        hashIntegridad: hashIntegridad,
        seniatSyncId: seniatSyncId,
        seniatSyncFecha: seniatSyncFecha,
        seniatSyncEstado: seniatSyncEstado,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// CLASES ARQUEO DE CAJA
// =============================================================================

// =============================================================================
// CLASES ARQUEO DE CAJA
// =============================================================================

/// Modelo para el conteo físico de efectivo consolidado por moneda
class ConteoEfectivo {
  final double efectivoBs;
  final double efectivoUsd;
  final double efectivoEur;
  final double efectivoCop;

  const ConteoEfectivo({
    this.efectivoBs = 0.0,
    this.efectivoUsd = 0.0,
    this.efectivoEur = 0.0,
    this.efectivoCop = 0.0,
  });

  double get totalBs => efectivoBs;
  double get totalUsd => efectivoUsd;
  double get totalEur => efectivoEur;
  double get totalCop => efectivoCop;

  Map<String, dynamic> toJson() => {
    'efectivo_bs': efectivoBs,
    'efectivo_usd': efectivoUsd,
    'efectivo_eur': efectivoEur,
    'efectivo_cop': efectivoCop,
  };

  factory ConteoEfectivo.fromJson(Map<String, dynamic> json) => ConteoEfectivo(
    efectivoBs: (json['efectivo_bs'] ?? json['total_efectivo_bs'] ?? 0.0).toDouble(),
    efectivoUsd: (json['efectivo_usd'] ?? json['total_efectivo_usd'] ?? 0.0).toDouble(),
    efectivoEur: (json['efectivo_eur'] ?? json['total_efectivo_eur'] ?? 0.0).toDouble(),
    efectivoCop: (json['efectivo_cop'] ?? json['total_efectivo_cop'] ?? 0.0).toDouble(),
  );

  factory ConteoEfectivo.vacio() => const ConteoEfectivo();
}

/// Modelo para el arqueo de caja
class ArqueoCaja extends SyncableModel {
  final int? id;
  final int sesionFiscalId;
  final String numeroArqueo;
  final DateTime fechaArqueo;
  final int usuarioArqueoId;
  final String usuarioArqueoNombre;
  final ConteoEfectivo conteo;
  
  // Totales declarados
  final double totalEfectivoDeclarado;
  final double totalTarjetaDeclarado;
  final double totalPagoMovilDeclarado;
  final double totalOtrosDeclarado;
  
  // Totales del sistema
  final double totalEfectivoSistema;
  final double totalTarjetaSistema;
  final double totalPagoMovilSistema;
  final double totalOtrosSistema;
  
  // Diferencias
  final double diferenciaEfectivo;
  final double diferenciaTarjeta;
  final double diferenciaPagoMovil;
  final double diferenciaTotal;
  
  final bool cuadrado;
  final String? observaciones;
  final double fondoCajaInicial;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ArqueoCaja({
    this.id,
    required this.sesionFiscalId,
    required this.numeroArqueo,
    required this.fechaArqueo,
    required this.usuarioArqueoId,
    required this.usuarioArqueoNombre,
    required this.conteo,
    required this.totalEfectivoDeclarado,
    required this.totalTarjetaDeclarado,
    required this.totalPagoMovilDeclarado,
    required this.totalOtrosDeclarado,
    required this.totalEfectivoSistema,
    required this.totalTarjetaSistema,
    required this.totalPagoMovilSistema,
    required this.totalOtrosSistema,
    required this.diferenciaEfectivo,
    required this.diferenciaTarjeta,
    required this.diferenciaPagoMovil,
    required this.diferenciaTotal,
    required this.cuadrado,
    this.observaciones,
    this.fondoCajaInicial = 0.0,
    required this.createdAt,
    required this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  bool get estaCuadrado => cuadrado;
  double get totalDeclarado => totalEfectivoDeclarado + totalTarjetaDeclarado + totalPagoMovilDeclarado + totalOtrosDeclarado;
  double get totalSistema => totalEfectivoSistema + totalTarjetaSistema + totalPagoMovilSistema + totalOtrosSistema;

  @override
  Map<String, dynamic> toLocalMap() => {
    if (id != null) 'id': id,
    'sesion_fiscal_id': sesionFiscalId,
    'numero_arqueo': numeroArqueo,
    'fecha_arqueo': fechaArqueo.toIso8601String(),
    'usuario_arqueo_id': usuarioArqueoId,
    'usuario_arqueo_nombre': usuarioArqueoNombre,
    ...conteo.toJson(),
    'total_efectivo_usd': totalEfectivoDeclarado,
    'total_efectivo_bs': conteo.totalBs,
    'total_efectivo_eur': conteo.totalEur,
    'total_efectivo_cop': conteo.totalCop,
    'total_tarjeta_declarado': totalTarjetaDeclarado,
    'total_pago_movil_declarado': totalPagoMovilDeclarado,
    'total_otros_declarado': totalOtrosDeclarado,
    'total_efectivo_sistema': totalEfectivoSistema,
    'total_tarjeta_sistema': totalTarjetaSistema,
    'total_pago_movil_sistema': totalPagoMovilSistema,
    'total_otros_sistema': totalOtrosSistema,
    'diferencia_efectivo': diferenciaEfectivo,
    'diferencia_tarjeta': diferenciaTarjeta,
    'diferencia_pago_movil': diferenciaPagoMovil,
    'diferencia_total': diferenciaTotal,
    'cuadrado': cuadrado ? 1 : 0,
    'observaciones': observaciones,
    'fondo_caja_inicial': fondoCajaInicial,
    'created_at': createdAt.toIso8601String(),
    ...syncLocalFields,
  };

  @override
  Map<String, dynamic> toRemoteMap() => {
    'sesion_fiscal_id': sesionFiscalId,
    'numero_arqueo': numeroArqueo,
    'fecha_arqueo': fechaArqueo.toIso8601String(),
    'usuario_arqueo_id': usuarioArqueoId,
    'usuario_arqueo_nombre': usuarioArqueoNombre,
    'conteo': conteo.toJson(),
    'total_efectivo_declarado': totalEfectivoDeclarado,
    'total_tarjeta_declarado': totalTarjetaDeclarado,
    'total_pago_movil_declarado': totalPagoMovilDeclarado,
    'total_otros_declarado': totalOtrosDeclarado,
    'total_efectivo_sistema': totalEfectivoSistema,
    'total_tarjeta_sistema': totalTarjetaSistema,
    'total_pago_movil_sistema': totalPagoMovilSistema,
    'total_otros_sistema': totalOtrosSistema,
    'diferencia_efectivo': diferenciaEfectivo,
    'diferencia_tarjeta': diferenciaTarjeta,
    'diferencia_pago_movil': diferenciaPagoMovil,
    'diferencia_total': diferenciaTotal,
    'cuadrado': cuadrado,
    'observaciones': observaciones,
    'fondo_caja_inicial': fondoCajaInicial,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    ...syncRemoteFields,
  };

  factory ArqueoCaja.fromLocalMap(Map<String, dynamic> m) => ArqueoCaja(
    id: m['id'] as int?,
    sesionFiscalId: m['sesion_fiscal_id'] as int,
    numeroArqueo: m['numero_arqueo'] as String,
    fechaArqueo: DateTime.parse(m['fecha_arqueo'] as String),
    usuarioArqueoId: m['usuario_arqueo_id'] as int,
    usuarioArqueoNombre: m['usuario_arqueo_nombre'] as String,
    conteo: ConteoEfectivo(
      efectivoBs: (m['total_efectivo_bs'] as num? ?? m['efectivo_bs'] ?? 0.0).toDouble(),
      efectivoUsd: (m['total_efectivo_usd'] as num? ?? m['efectivo_usd'] ?? 0.0).toDouble(),
      efectivoEur: (m['total_efectivo_eur'] as num? ?? m['efectivo_eur'] ?? 0.0).toDouble(),
      efectivoCop: (m['total_efectivo_cop'] as num? ?? m['efectivo_cop'] ?? 0.0).toDouble(),
    ),
    totalEfectivoDeclarado: (m['total_efectivo_usd'] as num? ?? 0.0).toDouble(),
    totalTarjetaDeclarado: (m['total_tarjeta_declarado'] as num? ?? 0.0).toDouble(),
    totalPagoMovilDeclarado: (m['total_pago_movil_declarado'] as num? ?? 0.0).toDouble(),
    totalOtrosDeclarado: (m['total_otros_declarado'] as num? ?? 0.0).toDouble(),
    totalEfectivoSistema: (m['total_efectivo_sistema'] as num? ?? 0.0).toDouble(),
    totalTarjetaSistema: (m['total_tarjeta_sistema'] as num? ?? 0.0).toDouble(),
    totalPagoMovilSistema: (m['total_pago_movil_sistema'] as num? ?? 0.0).toDouble(),
    totalOtrosSistema: (m['total_otros_sistema'] as num? ?? 0.0).toDouble(),
    diferenciaEfectivo: (m['diferencia_efectivo'] as num? ?? 0.0).toDouble(),
    diferenciaTarjeta: (m['diferencia_tarjeta'] as num? ?? 0.0).toDouble(),
    diferenciaPagoMovil: (m['diferencia_pago_movil'] as num? ?? 0.0).toDouble(),
    diferenciaTotal: (m['diferencia_total'] as num? ?? 0.0).toDouble(),
    cuadrado: m['cuadrado'] == 1,
    observaciones: m['observaciones'] as String?,
    fondoCajaInicial: (m['fondo_caja_inicial'] as num? ?? 0.0).toDouble(),
    createdAt: DateTime.parse(m['created_at'] as String? ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    serverId: m['server_id'] as String?,
    lastModified: SyncableModel.parseLastModified(m),
    syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
  );

  @override
  ArqueoCaja copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) => ArqueoCaja(
    id: id,
    sesionFiscalId: sesionFiscalId,
    numeroArqueo: numeroArqueo,
    fechaArqueo: fechaArqueo,
    usuarioArqueoId: usuarioArqueoId,
    usuarioArqueoNombre: usuarioArqueoNombre,
    conteo: conteo,
    totalEfectivoDeclarado: totalEfectivoDeclarado,
    totalTarjetaDeclarado: totalTarjetaDeclarado,
    totalPagoMovilDeclarado: totalPagoMovilDeclarado,
    totalOtrosDeclarado: totalOtrosDeclarado,
    totalEfectivoSistema: totalEfectivoSistema,
    totalTarjetaSistema: totalTarjetaSistema,
    totalPagoMovilSistema: totalPagoMovilSistema,
    totalOtrosSistema: totalOtrosSistema,
    diferenciaEfectivo: diferenciaEfectivo,
    diferenciaTarjeta: diferenciaTarjeta,
    diferenciaPagoMovil: diferenciaPagoMovil,
    diferenciaTotal: diferenciaTotal,
    cuadrado: cuadrado,
    observaciones: observaciones,
    fondoCajaInicial: fondoCajaInicial,
    createdAt: createdAt,
    updatedAt: updatedAt,
    serverId: serverId ?? this.serverId,
    lastModified: lastModified ?? this.lastModified,
    syncStatus: syncStatus ?? this.syncStatus,
  );
}


// =============================================================================
// CLASE SECUENCIA DOCUMENTO
// =============================================================================

class SecuenciaDocumento extends SyncableModel {
  final int? id;
  final String tipoDocumento; // 'FACTURA' o 'NOTA_CREDITO'
  final String prefijo;
  final int ultimoNumero;
  final bool reinicioDiario;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecuenciaDocumento({
    this.id,
    required this.tipoDocumento,
    required this.prefijo,
    required this.ultimoNumero,
    required this.reinicioDiario,
    required this.createdAt,
    required this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  String generarSiguienteNumero() {
    final siguiente = ultimoNumero + 1;
    return '$prefijo-${siguiente.toString().padLeft(7, '0')}';
  }

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'tipo_documento': tipoDocumento,
        'prefijo': prefijo,
        'ultimo_numero': ultimoNumero,
        'reinicio_diario': reinicioDiario ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'tipo_documento': tipoDocumento,
        'prefijo': prefijo,
        'ultimo_numero': ultimoNumero,
        'reinicio_diario': reinicioDiario,
        ...syncRemoteFields,
      };

  factory SecuenciaDocumento.fromLocalMap(Map<String, dynamic> m) =>
      SecuenciaDocumento(
        id: m['id'] as int?,
        tipoDocumento: m['tipo_documento'] as String,
        prefijo: m['prefijo'] as String,
        ultimoNumero: m['ultimo_numero'] as int,
        reinicioDiario: m['reinicio_diario'] == 1 || m['reinicio_diario'] == true,
        createdAt: DateTime.parse(m['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory SecuenciaDocumento.fromRemoteMap(Map<String, dynamic> m) =>
      SecuenciaDocumento.fromLocalMap({
        ...m,
        'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': m['updated_at'] ?? DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.synced.toInt()
      });

  @override
  SecuenciaDocumento copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      SecuenciaDocumento(
        id: id,
        tipoDocumento: tipoDocumento,
        prefijo: prefijo,
        ultimoNumero: ultimoNumero,
        reinicioDiario: reinicioDiario,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}
