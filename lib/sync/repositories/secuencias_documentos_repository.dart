import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../enums/sync_status.dart';
import '../../models/fiscal_models.dart';
import 'base_repository.dart';

class SecuenciasDocumentosRepository extends BaseRepository<SecuenciaDocumento> {
  static final SecuenciasDocumentosRepository instance = SecuenciasDocumentosRepository._();
  SecuenciasDocumentosRepository._();

  @override
  String get tableName => 'secuencias_documentos';

  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(SecuenciaDocumento model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(SecuenciaDocumento model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<SecuenciaDocumento>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'tipo_documento ASC');
    return maps.map(SecuenciaDocumento.fromLocalMap).toList();
  }

  @override
  Future<List<SecuenciaDocumento>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(SecuenciaDocumento.fromLocalMap).toList();
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
  SecuenciaDocumento fromRemoteMap(Map<String, dynamic> map) =>
      SecuenciaDocumento.fromRemoteMap(map);
}
