import 'package:pos_android/sync/models/syncable_model.dart';
import 'package:pos_android/sync/enums/sync_status.dart';

/// Modelo principal para Nota de Crédito
class NotaCredito extends SyncableModel {
  final int? id;
  final String numeroControl;
  final String tipo; // 'total' | 'parcial'
  final int facturaId;
  final String motivo;
  final double montoTotal;
  final double iva;
  final DateTime fechaEmision;
  final String estado; // 'pendiente' | 'procesada' | 'anulada'
  final int? usuarioId;
  final String? observaciones;
  final DateTime? fechaAnulacion;
  final String? motivoAnulacion;
  final int? usuarioAnulacionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotaCredito({
    this.id,
    super.serverId,
    required this.numeroControl,
    required this.tipo,
    required this.facturaId,
    required this.motivo,
    required this.montoTotal,
    required this.iva,
    required this.fechaEmision,
    this.estado = 'pendiente',
    this.usuarioId,
    this.observaciones,
    this.fechaAnulacion,
    this.motivoAnulacion,
    this.usuarioAnulacionId,
    super.syncStatus = SyncStatus.synced,
    DateTime? lastModified,
    this.createdAt,
    this.updatedAt,
  }) : super(
          lastModified: lastModified ?? DateTime.now(),
        );

  /// Crear desde mapa de la base de datos
  factory NotaCredito.fromMap(Map<String, dynamic> map) {
    return NotaCredito(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      numeroControl: map['numero_control'] as String,
      tipo: map['tipo'] as String,
      facturaId: map['factura_id'] as int,
      motivo: map['motivo'] as String,
      montoTotal: (map['monto_total'] as num).toDouble(),
      iva: (map['iva'] as num).toDouble(),
      fechaEmision: DateTime.parse(map['fecha_emision'] as String),
      estado: map['estado'] as String,
      usuarioId: map['usuario_id'] as int?,
      observaciones: map['observaciones'] as String?,
      fechaAnulacion: map['fecha_anulacion'] != null
          ? DateTime.parse(map['fecha_anulacion'] as String)
          : null,
      motivoAnulacion: map['motivo_anulacion'] as String?,
      usuarioAnulacionId: map['usuario_anulacion_id'] as int?,
      syncStatus: SyncStatus.fromInt(map['sync_status'] as int? ?? 0),
      lastModified: map['last_modified'] != null
          ? DateTime.parse(map['last_modified'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Serializa para SQLite (incluye campos de control)
  @override
  Map<String, dynamic> toLocalMap() {
    return {
      if (id != null) 'id': id,
      ...syncLocalFields,
      'numero_control': numeroControl,
      'tipo': tipo,
      'factura_id': facturaId,
      'motivo': motivo,
      'monto_total': montoTotal,
      'iva': iva,
      'fecha_emision': fechaEmision.toIso8601String(),
      'estado': estado,
      'usuario_id': usuarioId,
      'observaciones': observaciones,
      'fecha_anulacion': fechaAnulacion?.toIso8601String(),
      'motivo_anulacion': motivoAnulacion,
      'usuario_anulacion_id': usuarioAnulacionId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Serializa para Supabase (sin IDs locales)
  @override
  Map<String, dynamic> toRemoteMap() {
    return {
      ...syncRemoteFields,
      'numero_control': numeroControl,
      'tipo': tipo,
      'factura_id': facturaId,
      'motivo': motivo,
      'monto_total': montoTotal,
      'iva': iva,
      'fecha_emision': fechaEmision.toIso8601String(),
      'estado': estado,
      'usuario_id': usuarioId,
      'observaciones': observaciones,
      'fecha_anulacion': fechaAnulacion?.toIso8601String(),
      'motivo_anulacion': motivoAnulacion,
      'usuario_anulacion_id': usuarioAnulacionId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Crear copia con nuevos valores
  @override
  NotaCredito copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) {
    return NotaCredito(
      id: id,
      serverId: serverId ?? this.serverId,
      numeroControl: numeroControl,
      tipo: tipo,
      facturaId: facturaId,
      motivo: motivo,
      montoTotal: montoTotal,
      iva: iva,
      fechaEmision: fechaEmision,
      estado: estado,
      usuarioId: usuarioId,
      observaciones: observaciones,
      fechaAnulacion: fechaAnulacion,
      motivoAnulacion: motivoAnulacion,
      usuarioAnulacionId: usuarioAnulacionId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Crear copia con nuevos valores (completa)
  NotaCredito copyWith({
    int? id,
    String? serverId,
    String? numeroControl,
    String? tipo,
    int? facturaId,
    String? motivo,
    double? montoTotal,
    double? iva,
    DateTime? fechaEmision,
    String? estado,
    int? usuarioId,
    String? observaciones,
    DateTime? fechaAnulacion,
    String? motivoAnulacion,
    int? usuarioAnulacionId,
    SyncStatus? syncStatus,
    DateTime? lastModified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaCredito(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      numeroControl: numeroControl ?? this.numeroControl,
      tipo: tipo ?? this.tipo,
      facturaId: facturaId ?? this.facturaId,
      motivo: motivo ?? this.motivo,
      montoTotal: montoTotal ?? this.montoTotal,
      iva: iva ?? this.iva,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      estado: estado ?? this.estado,
      usuarioId: usuarioId ?? this.usuarioId,
      observaciones: observaciones ?? this.observaciones,
      fechaAnulacion: fechaAnulacion ?? this.fechaAnulacion,
      motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
      usuarioAnulacionId: usuarioAnulacionId ?? this.usuarioAnulacionId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Marcar como procesada
  NotaCredito markAsProcesada() {
    return copyWith(
      estado: 'procesada',
      updatedAt: DateTime.now(),
      lastModified: DateTime.now(),
    );
  }

  /// Marcar como anulada
  NotaCredito markAsAnulada({
    required String motivo,
    required int usuarioId,
  }) {
    return copyWith(
      estado: 'anulada',
      fechaAnulacion: DateTime.now(),
      motivoAnulacion: motivo,
      usuarioAnulacionId: usuarioId,
      updatedAt: DateTime.now(),
      lastModified: DateTime.now(),
    );
  }

  /// Verificar si es nota de crédito total
  bool get esTotal => tipo == 'total';

  /// Verificar si es nota de crédito parcial
  bool get esParcial => tipo == 'parcial';

  /// Verificar si está pendiente
  bool get estaPendiente => estado == 'pendiente';

  /// Verificar si está procesada
  bool get estaProcesada => estado == 'procesada';

  /// Verificar si está anulada
  bool get estaAnulada => estado == 'anulada';

  /// Calcular total general (monto + IVA)
  double get totalGeneral => montoTotal + iva;

  @override
  String toString() {
    return 'NotaCredito{id: $id, numeroControl: $numeroControl, tipo: $tipo, estado: $estado, montoTotal: $montoTotal}';
  }
}
