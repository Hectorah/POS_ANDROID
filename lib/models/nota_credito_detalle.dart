import 'package:pos_android/sync/models/syncable_model.dart';
import 'package:pos_android/sync/enums/sync_status.dart';

/// Modelo para detalles de Nota de Crédito
class NotaCreditoDetalle extends SyncableModel {
  final int? id;
  final int notaCreditoId;
  final int productoId;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? lote;
  final String? serial;
  final DateTime? fechaVencimiento;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotaCreditoDetalle({
    this.id,
    super.serverId,
    required this.notaCreditoId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.lote,
    this.serial,
    this.fechaVencimiento,
    super.syncStatus = SyncStatus.synced,
    DateTime? lastModified,
    this.createdAt,
    this.updatedAt,
  }) : super(
          lastModified: lastModified ?? DateTime.now(),
        );

  /// Crear desde mapa de la base de datos
  factory NotaCreditoDetalle.fromMap(Map<String, dynamic> map) {
    return NotaCreditoDetalle(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      notaCreditoId: map['nota_credito_id'] as int,
      productoId: map['producto_id'] as int,
      cantidad: (map['cantidad'] as num).toDouble(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      lote: map['lote'] as String?,
      serial: map['serial'] as String?,
      fechaVencimiento: map['fecha_vencimiento'] != null
          ? DateTime.parse(map['fecha_vencimiento'] as String)
          : null,
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
      'nota_credito_id': notaCreditoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'lote': lote,
      'serial': serial,
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Serializa para Supabase (sin IDs locales)
  @override
  Map<String, dynamic> toRemoteMap() {
    return {
      ...syncRemoteFields,
      'nota_credito_id': notaCreditoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'lote': lote,
      'serial': serial,
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Crear copia con nuevos valores de sincronización
  @override
  NotaCreditoDetalle copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) {
    return NotaCreditoDetalle(
      id: id,
      serverId: serverId ?? this.serverId,
      notaCreditoId: notaCreditoId,
      productoId: productoId,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      subtotal: subtotal,
      lote: lote,
      serial: serial,
      fechaVencimiento: fechaVencimiento,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Crear copia con nuevos valores (completa)
  NotaCreditoDetalle copyWith({
    int? id,
    String? serverId,
    int? notaCreditoId,
    int? productoId,
    double? cantidad,
    double? precioUnitario,
    double? subtotal,
    String? lote,
    String? serial,
    DateTime? fechaVencimiento,
    SyncStatus? syncStatus,
    DateTime? lastModified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaCreditoDetalle(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      notaCreditoId: notaCreditoId ?? this.notaCreditoId,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      lote: lote ?? this.lote,
      serial: serial ?? this.serial,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calcular IVA (asumiendo 16%)
  double get iva => subtotal * 0.16;

  /// Calcular total (subtotal + IVA)
  double get total => subtotal + iva;

  @override
  String toString() {
    return 'NotaCreditoDetalle{id: $id, productoId: $productoId, cantidad: $cantidad, subtotal: $subtotal}';
  }
}
