import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class ClienteSync extends SyncableModel {
  final int? id;
  final String identificacion;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final String? correo;
  final int agenteRetencion;

  const ClienteSync({
    this.id,
    required this.identificacion,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.correo,
    this.agenteRetencion = 0,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'identificacion': identificacion,
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'correo': correo,
        'agente_retencion': agenteRetencion,
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'identificacion': identificacion,
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'correo': correo,
        'agente_retencion': agenteRetencion,
        ...syncRemoteFields,
      };

  factory ClienteSync.fromLocalMap(Map<String, dynamic> m) => ClienteSync(
        id: m['id'] as int?,
        identificacion: m['identificacion'] as String,
        nombre: m['nombre'] as String,
        direccion: m['direccion'] as String?,
        telefono: m['telefono'] as String?,
        correo: m['correo'] as String?,
        agenteRetencion: (m['agente_retencion'] as int?) ?? 0,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory ClienteSync.fromRemoteMap(Map<String, dynamic> m) => ClienteSync(
        identificacion: m['identificacion'] as String,
        nombre: m['nombre'] as String,
        direccion: m['direccion'] as String?,
        telefono: m['telefono'] as String?,
        correo: m['correo'] as String?,
        agenteRetencion: (m['agente_retencion'] as int?) ?? 0,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.synced,
      );

  @override
  ClienteSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      ClienteSync(
        id: id,
        identificacion: identificacion,
        nombre: nombre,
        direccion: direccion,
        telefono: telefono,
        correo: correo,
        agenteRetencion: agenteRetencion,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class ClientesRepository extends BaseRepository<ClienteSync> {
  static final ClientesRepository instance = ClientesRepository._();
  ClientesRepository._();

  @override
  String get tableName => 'clientes';

  /// Clientes: servidor gana (base de clientes centralizada).
  @override
  bool get localWinsOnConflict => false;

  @override
  Future<int> insertLocal(ClienteSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(ClienteSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<ClienteSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'nombre ASC');
    return maps.map(ClienteSync.fromLocalMap).toList();
  }

  @override
  Future<List<ClienteSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(ClienteSync.fromLocalMap).toList();
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
  ClienteSync fromRemoteMap(Map<String, dynamic> map) =>
      ClienteSync.fromRemoteMap(map);

  Future<ClienteSync?> getByIdentificacion(String identificacion) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'identificacion = ?', whereArgs: [identificacion], limit: 1);
    return maps.isEmpty ? null : ClienteSync.fromLocalMap(maps.first);
  }

  Future<List<ClienteSync>> buscar(String query) async {
    final db = await DbHelper.instance.database;
    final term = '%$query%';
    final maps = await db.query(tableName,
        where: 'nombre LIKE ? OR identificacion LIKE ?',
        whereArgs: [term, term],
        orderBy: 'nombre ASC',
        limit: 50);
    return maps.map(ClienteSync.fromLocalMap).toList();
  }
}
