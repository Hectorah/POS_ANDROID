import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../enums/sync_status.dart';
import '../../models/fiscal_models.dart';
import 'base_repository.dart';

class SesionesFiscalesRepository extends BaseRepository<SesionFiscal> {
  static final SesionesFiscalesRepository instance = SesionesFiscalesRepository._();
  SesionesFiscalesRepository._();

  @override
  String get tableName => 'sesiones_fiscales';

  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(SesionFiscal model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(SesionFiscal model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<SesionFiscal>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'fecha_apertura DESC');
    return maps.map(SesionFiscal.fromLocalMap).toList();
  }

  @override
  Future<List<SesionFiscal>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(SesionFiscal.fromLocalMap).toList();
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
  SesionFiscal fromRemoteMap(Map<String, dynamic> map) =>
      SesionFiscal.fromRemoteMap(map);
}
