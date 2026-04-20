import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class FacturaDetalleSync extends SyncableModel {
  final int? id;
  final int facturaId;
  final int productoId;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  const FacturaDetalleSync({
    this.id,
    required this.facturaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'factura_id': facturaId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'subtotal': subtotal,
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'factura_id': facturaId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'subtotal': subtotal,
        ...syncRemoteFields,
      };

  factory FacturaDetalleSync.fromLocalMap(Map<String, dynamic> m) =>
      FacturaDetalleSync(
        id: m['id'] as int?,
        facturaId: m['factura_id'] as int,
        productoId: m['producto_id'] as int,
        cantidad: (m['cantidad'] as num).toDouble(),
        precioUnitario: (m['precio_unitario'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory FacturaDetalleSync.fromRemoteMap(Map<String, dynamic> m) =>
      FacturaDetalleSync.fromLocalMap(
          {...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  FacturaDetalleSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      FacturaDetalleSync(
        id: id,
        facturaId: facturaId,
        productoId: productoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        subtotal: subtotal,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class FacturaDetalleRepository extends BaseRepository<FacturaDetalleSync> {
  static final FacturaDetalleRepository instance = FacturaDetalleRepository._();
  FacturaDetalleRepository._();

  @override
  String get tableName => 'factura_detalle';

  /// Detalles de venta: local gana siempre.
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(FacturaDetalleSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(FacturaDetalleSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<FacturaDetalleSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName);
    return maps.map(FacturaDetalleSync.fromLocalMap).toList();
  }

  @override
  Future<List<FacturaDetalleSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(FacturaDetalleSync.fromLocalMap).toList();
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
  FacturaDetalleSync fromRemoteMap(Map<String, dynamic> map) =>
      FacturaDetalleSync.fromRemoteMap(map);

  Future<List<FacturaDetalleSync>> getByFacturaId(int facturaId) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'factura_id = ?', whereArgs: [facturaId]);
    return maps.map(FacturaDetalleSync.fromLocalMap).toList();
  }
}
