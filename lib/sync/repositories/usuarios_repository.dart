import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class UsuarioSync extends SyncableModel {
  final int? id;
  final String nombre;
  final String usuario;
  final String clave;
  final String nivel;

  const UsuarioSync({
    this.id,
    required this.nombre,
    required this.usuario,
    required this.clave,
    required this.nivel,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'usuario': usuario,
        'clave': clave,
        'nivel': nivel,
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'nombre': nombre,
        'usuario': usuario,
        'clave': clave,
        'nivel': nivel,
        ...syncRemoteFields,
      };

  factory UsuarioSync.fromLocalMap(Map<String, dynamic> m) => UsuarioSync(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        usuario: m['usuario'] as String,
        clave: m['clave'] as String,
        nivel: m['nivel'] as String,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory UsuarioSync.fromRemoteMap(Map<String, dynamic> m) => UsuarioSync(
        nombre: m['nombre'] as String,
        usuario: m['usuario'] as String,
        clave: m['clave'] as String,
        nivel: m['nivel'] as String,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.synced,
      );

  @override
  UsuarioSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      UsuarioSync(
        id: id,
        nombre: nombre,
        usuario: usuario,
        clave: clave,
        nivel: nivel,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class UsuariosRepository extends BaseRepository<UsuarioSync> {
  static final UsuariosRepository instance = UsuariosRepository._();
  UsuariosRepository._();

  @override
  String get tableName => 'usuarios';

  /// Usuarios: el servidor gana (gestión centralizada de accesos).
  @override
  bool get localWinsOnConflict => false;

  @override
  Future<int> insertLocal(UsuarioSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(UsuarioSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<UsuarioSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'nombre ASC');
    return maps.map(UsuarioSync.fromLocalMap).toList();
  }

  @override
  Future<List<UsuarioSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(UsuarioSync.fromLocalMap).toList();
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
  UsuarioSync fromRemoteMap(Map<String, dynamic> map) =>
      UsuarioSync.fromRemoteMap(map);
}
