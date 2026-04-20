import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class ExistenciaSync extends SyncableModel {
  final int? id;
  final int productoId;
  final String codArticulo;
  final double stock;

  const ExistenciaSync({
    this.id,
    required this.productoId,
    required this.codArticulo,
    required this.stock,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'producto_id': productoId,
        'cod_articulo': codArticulo,
        'stock': stock,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'producto_id': productoId,
        'cod_articulo': codArticulo,
        'stock': stock,
        ...syncRemoteFields,
      };

  factory ExistenciaSync.fromLocalMap(Map<String, dynamic> m) => ExistenciaSync(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int,
        codArticulo: m['cod_articulo'] as String,
        stock: (m['stock'] as num).toDouble(),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory ExistenciaSync.fromRemoteMap(Map<String, dynamic> m) => ExistenciaSync(
        productoId: m['producto_id'] as int,
        codArticulo: m['cod_articulo'] as String,
        stock: (m['stock'] as num).toDouble(),
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.synced,
      );

  @override
  ExistenciaSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      ExistenciaSync(
        id: id,
        productoId: productoId,
        codArticulo: codArticulo,
        stock: stock,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class ExistenciasRepository extends BaseRepository<ExistenciaSync> {
  static final ExistenciasRepository instance = ExistenciasRepository._();
  ExistenciasRepository._();

  @override
  String get tableName => 'existencias';

  /// Stock: local gana (las ventas reducen stock localmente en tiempo real).
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(ExistenciaSync model) async {
    final db = await DbHelper.instance.database;

    // Upsert: si ya existe una existencia para este producto, actualiza
    final existing = await db.query(
      tableName,
      columns: ['id'],
      where: 'producto_id = ?',
      whereArgs: [model.productoId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        tableName,
        model.toLocalMap()..remove('id'), // no incluir id en el SET
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }

    return db.insert(tableName, model.toLocalMap());
  }

  @override
  Future<void> updateLocal(ExistenciaSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<ExistenciaSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName);
    return maps.map(ExistenciaSync.fromLocalMap).toList();
  }

  @override
  Future<List<ExistenciaSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(ExistenciaSync.fromLocalMap).toList();
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
  ExistenciaSync fromRemoteMap(Map<String, dynamic> map) =>
      ExistenciaSync.fromRemoteMap(map);

  Future<ExistenciaSync?> getByProductoId(int productoId) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'producto_id = ?', whereArgs: [productoId], limit: 1);
    return maps.isEmpty ? null : ExistenciaSync.fromLocalMap(maps.first);
  }
}
