import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class ProductoSync extends SyncableModel {
  final int? id;
  final String codArticulo;
  final String? codBarras;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String tipoImpuesto;
  final String unidadMedida;

  const ProductoSync({
    this.id,
    required this.codArticulo,
    this.codBarras,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.tipoImpuesto = 'G',
    this.unidadMedida = 'und',
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'cod_articulo': codArticulo,
        'cod_barras': codBarras,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'tipo_impuesto': tipoImpuesto,
        'unidad_medida': unidadMedida,
        ...syncLocalFields, // server_id, last_modified, sync_status
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'cod_articulo': codArticulo,
        'cod_barras': codBarras,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'tipo_impuesto': tipoImpuesto,
        'unidad_medida': unidadMedida,
        ...syncRemoteFields, // last_modified
      };

  factory ProductoSync.fromLocalMap(Map<String, dynamic> m) => ProductoSync(
        id: m['id'] as int?,
        codArticulo: m['cod_articulo'] as String,
        codBarras: m['cod_barras'] as String?,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        precio: (m['precio'] as num).toDouble(),
        tipoImpuesto: m['tipo_impuesto'] as String? ?? 'G',
        unidadMedida: m['unidad_medida'] as String? ?? 'und',
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory ProductoSync.fromRemoteMap(Map<String, dynamic> m) => ProductoSync(
        codArticulo: m['cod_articulo'] as String,
        codBarras: m['cod_barras'] as String?,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        precio: (m['precio'] as num).toDouble(),
        tipoImpuesto: m['tipo_impuesto'] as String? ?? 'G',
        unidadMedida: m['unidad_medida'] as String? ?? 'und',
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.synced,
      );

  @override
  ProductoSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      ProductoSync(
        id: id,
        codArticulo: codArticulo,
        codBarras: codBarras,
        nombre: nombre,
        descripcion: descripcion,
        precio: precio,
        tipoImpuesto: tipoImpuesto,
        unidadMedida: unidadMedida,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class ProductosRepository extends BaseRepository<ProductoSync> {
  static final ProductosRepository instance = ProductosRepository._();
  ProductosRepository._();

  @override
  String get tableName => 'productos';

  /// Catálogo centralizado → servidor gana en conflictos.
  @override
  bool get localWinsOnConflict => false;

  @override
  Future<int> insertLocal(ProductoSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(ProductoSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<ProductoSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'nombre ASC');
    return maps.map(ProductoSync.fromLocalMap).toList();
  }

  @override
  Future<List<ProductoSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(ProductoSync.fromLocalMap).toList();
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
  ProductoSync fromRemoteMap(Map<String, dynamic> map) =>
      ProductoSync.fromRemoteMap(map);

  // ---------------------------------------------------------------------------
  // Métodos de negocio específicos
  // ---------------------------------------------------------------------------

  Future<List<ProductoSync>> buscar(String query) async {
    final db = await DbHelper.instance.database;
    final term = '%$query%';
    final maps = await db.query(tableName,
        where: 'nombre LIKE ? OR cod_articulo LIKE ? OR cod_barras LIKE ?',
        whereArgs: [term, term, term],
        orderBy: 'nombre ASC');
    return maps.map(ProductoSync.fromLocalMap).toList();
  }

  Future<ProductoSync?> getByCodArticulo(String cod) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'cod_articulo = ?', whereArgs: [cod], limit: 1);
    return maps.isEmpty ? null : ProductoSync.fromLocalMap(maps.first);
  }
}
