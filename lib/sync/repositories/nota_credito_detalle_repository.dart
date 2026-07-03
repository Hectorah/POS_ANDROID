import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE — NOTA_CREDITO_DETALLE
// =============================================================================

class NotaCreditoDetalleSync extends SyncableModel {
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

  const NotaCreditoDetalleSync({
    this.id,
    required this.notaCreditoId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.lote,
    this.serial,
    this.fechaVencimiento,
    this.createdAt,
    this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
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
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
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
        ...syncRemoteFields,
      };

  factory NotaCreditoDetalleSync.fromLocalMap(Map<String, dynamic> m) => NotaCreditoDetalleSync(
        id: m['id'] as int?,
        notaCreditoId: m['nota_credito_id'] as int,
        productoId: m['producto_id'] as int,
        cantidad: (m['cantidad'] as num).toDouble(),
        precioUnitario: (m['precio_unitario'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
        lote: m['lote'] as String?,
        serial: m['serial'] as String?,
        fechaVencimiento: m['fecha_vencimiento'] != null
            ? DateTime.parse(m['fecha_vencimiento'] as String)
            : null,
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory NotaCreditoDetalleSync.fromRemoteMap(Map<String, dynamic> m) =>
      NotaCreditoDetalleSync.fromLocalMap({...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  NotaCreditoDetalleSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      NotaCreditoDetalleSync(
        id: id,
        notaCreditoId: notaCreditoId,
        productoId: productoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        subtotal: subtotal,
        lote: lote,
        serial: serial,
        fechaVencimiento: fechaVencimiento,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  /// Calcular IVA (asumiendo 16%)
  double get iva => subtotal * 0.16;

  /// Calcular total (subtotal + IVA)
  double get total => subtotal + iva;
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class NotaCreditoDetalleRepository extends BaseRepository<NotaCreditoDetalleSync> {
  static final NotaCreditoDetalleRepository instance = NotaCreditoDetalleRepository._();
  NotaCreditoDetalleRepository._();

  @override
  String get tableName => 'nota_credito_detalle';

  /// Detalles de notas de crédito: local gana siempre
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(NotaCreditoDetalleSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(NotaCreditoDetalleSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<NotaCreditoDetalleSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'id ASC');
    return maps.map(NotaCreditoDetalleSync.fromLocalMap).toList();
  }

  @override
  Future<List<NotaCreditoDetalleSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(NotaCreditoDetalleSync.fromLocalMap).toList();
  }

  @override
  Future<void> updateSyncFields(int localId,
      {required String? serverId,
      required SyncStatus syncStatus,
      required DateTime lastModified}) async {
    final db = await DbHelper.instance.database;
    await db.update(
      tableName,
      {
        'server_id': serverId,
        'sync_status': syncStatus.toInt(),
        'last_modified': lastModified.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  @override
  NotaCreditoDetalleSync fromRemoteMap(Map<String, dynamic> map) =>
      NotaCreditoDetalleSync.fromRemoteMap(map);

  /// Obtener detalles por nota de crédito
  Future<List<NotaCreditoDetalleSync>> getByNotaCreditoId(int notaCreditoId) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'nota_credito_id = ?',
      whereArgs: [notaCreditoId],
      orderBy: 'id ASC',
    );
    return maps.map(NotaCreditoDetalleSync.fromLocalMap).toList();
  }

  /// Obtener detalles con información del producto
  Future<List<Map<String, dynamic>>> getDetallesConProducto(int notaCreditoId) async {
    final db = await DbHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT 
        d.id,
        d.nota_credito_id,
        d.producto_id,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.lote,
        d.serial,
        d.fecha_vencimiento,
        p.cod_articulo,
        p.nombre as producto_nombre,
        p.unidad_medida
      FROM nota_credito_detalle d
      INNER JOIN productos p ON d.producto_id = p.id
      WHERE d.nota_credito_id = ?
      ORDER BY d.id ASC
    ''', [notaCreditoId]);
    
    return results;
  }

  /// Crear múltiples detalles
  Future<void> crearMultiplesDetalles(List<NotaCreditoDetalleSync> detalles) async {
    final db = await DbHelper.instance.database;
    
    await db.transaction((txn) async {
      for (final detalle in detalles) {
        await txn.insert(
          tableName,
          detalle.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Eliminar detalles por nota de crédito
  Future<int> eliminarPorNotaCreditoId(int notaCreditoId) async {
    final db = await DbHelper.instance.database;
    return await db.delete(
      tableName,
      where: 'nota_credito_id = ?',
      whereArgs: [notaCreditoId],
    );
  }

  /// Obtener productos devueltos por factura
  Future<List<Map<String, dynamic>>> obtenerProductosDevueltosPorFactura(int facturaId) async {
    final db = await DbHelper.instance.database;
    
    final result = await db.rawQuery('''
      SELECT 
        p.id as producto_id,
        p.cod_articulo,
        p.nombre as producto_nombre,
        SUM(d.cantidad) as cantidad_total_devuelta,
        d.precio_unitario,
        SUM(d.subtotal) as subtotal_total
      FROM nota_credito n
      INNER JOIN nota_credito_detalle d ON n.id = d.nota_credito_id
      INNER JOIN productos p ON d.producto_id = p.id
      WHERE n.factura_id = ? 
        AND n.estado IN ('pendiente', 'procesada')
      GROUP BY p.id, d.precio_unitario
      ORDER BY p.nombre ASC
    ''', [facturaId]);
    
    return result;
  }

  /// Obtener monto total devuelto por factura
  Future<double> obtenerMontoDevueltoPorFactura(int facturaId) async {
    final db = await DbHelper.instance.database;
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(d.subtotal), 0) as total_devuelto
      FROM nota_credito n
      INNER JOIN nota_credito_detalle d ON n.id = d.nota_credito_id
      WHERE n.factura_id = ? 
        AND n.estado IN ('pendiente', 'procesada')
    ''', [facturaId]);
    
    return (result.first['total_devuelto'] as double?) ?? 0.0;
  }
}