import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE
// =============================================================================

class CierreLoteSync extends SyncableModel {
  final int? id;
  final String fechaCreacion;
  final int usuarioId;
  final String tipoCierre;
  final String? ubiiResponseCode;
  final String? ubiiResponseMessage;
  final String? ubiiTerminal;
  final String? ubiiLote;
  final String? ubiiFecha;
  final String? ubiiHora;
  final int totalTransacciones;
  final double montoTotal;
  final String? datosCompletos;

  const CierreLoteSync({
    this.id,
    required this.fechaCreacion,
    required this.usuarioId,
    required this.tipoCierre,
    this.ubiiResponseCode,
    this.ubiiResponseMessage,
    this.ubiiTerminal,
    this.ubiiLote,
    this.ubiiFecha,
    this.ubiiHora,
    this.totalTransacciones = 0,
    required this.montoTotal,
    this.datosCompletos,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'fecha_creacion': fechaCreacion,
        'usuario_id': usuarioId,
        'tipo_cierre': tipoCierre,
        'ubii_response_code': ubiiResponseCode,
        'ubii_response_message': ubiiResponseMessage,
        'ubii_terminal': ubiiTerminal,
        'ubii_lote': ubiiLote,
        'ubii_fecha': ubiiFecha,
        'ubii_hora': ubiiHora,
        'total_transacciones': totalTransacciones,
        'monto_total': montoTotal,
        'datos_completos': datosCompletos,
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'fecha_creacion': fechaCreacion,
        'usuario_id': usuarioId,
        'tipo_cierre': tipoCierre,
        'ubii_response_code': ubiiResponseCode,
        'ubii_response_message': ubiiResponseMessage,
        'ubii_terminal': ubiiTerminal,
        'ubii_lote': ubiiLote,
        'ubii_fecha': ubiiFecha,
        'ubii_hora': ubiiHora,
        'total_transacciones': totalTransacciones,
        'monto_total': montoTotal,
        'datos_completos': datosCompletos,
        ...syncRemoteFields,
      };

  factory CierreLoteSync.fromLocalMap(Map<String, dynamic> m) => CierreLoteSync(
        id: m['id'] as int?,
        fechaCreacion: m['fecha_creacion'] as String,
        usuarioId: m['usuario_id'] as int,
        tipoCierre: m['tipo_cierre'] as String,
        ubiiResponseCode: m['ubii_response_code'] as String?,
        ubiiResponseMessage: m['ubii_response_message'] as String?,
        ubiiTerminal: m['ubii_terminal'] as String?,
        ubiiLote: m['ubii_lote'] as String?,
        ubiiFecha: m['ubii_fecha'] as String?,
        ubiiHora: m['ubii_hora'] as String?,
        totalTransacciones: (m['total_transacciones'] as int?) ?? 0,
        montoTotal: (m['monto_total'] as num).toDouble(),
        datosCompletos: m['datos_completos'] as String?,
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory CierreLoteSync.fromRemoteMap(Map<String, dynamic> m) =>
      CierreLoteSync.fromLocalMap(
          {...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  CierreLoteSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      CierreLoteSync(
        id: id,
        fechaCreacion: fechaCreacion,
        usuarioId: usuarioId,
        tipoCierre: tipoCierre,
        ubiiResponseCode: ubiiResponseCode,
        ubiiResponseMessage: ubiiResponseMessage,
        ubiiTerminal: ubiiTerminal,
        ubiiLote: ubiiLote,
        ubiiFecha: ubiiFecha,
        ubiiHora: ubiiHora,
        totalTransacciones: totalTransacciones,
        montoTotal: montoTotal,
        datosCompletos: datosCompletos,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class CierresLoteRepository extends BaseRepository<CierreLoteSync> {
  static final CierresLoteRepository instance = CierresLoteRepository._();
  CierresLoteRepository._();

  @override
  String get tableName => 'cierres_lote';

  /// Cierres de lote: local gana (registros fiscales locales).
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(CierreLoteSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(CierreLoteSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<CierreLoteSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps =
        await db.query(tableName, orderBy: 'fecha_creacion DESC');
    return maps.map(CierreLoteSync.fromLocalMap).toList();
  }

  @override
  Future<List<CierreLoteSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(CierreLoteSync.fromLocalMap).toList();
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
  CierreLoteSync fromRemoteMap(Map<String, dynamic> map) =>
      CierreLoteSync.fromRemoteMap(map);
}
