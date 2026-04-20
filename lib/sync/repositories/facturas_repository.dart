import 'package:sqflite/sqflite.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE — FACTURA (cabecera)
// =============================================================================

class FacturaSync extends SyncableModel {
  final int? id;
  final String numeroControl;
  final String fechaCreacion;
  final int clienteId;
  final int usuarioId;
  final String tipoDocumento;
  final double baseImponible;
  final double montoIva;
  final double retencionIva;
  final double tasaUsd;
  final double tasaEur;
  final double total;
  final String metodoPago;
  final String? referenciaPago;
  final double montoBs;
  final double montoUsd;
  final String? ubiiReference;
  final String? ubiiAuthCode;
  final String? ubiiCardType;
  final String? ubiiTerminal;
  final String? ubiiLote;
  final String? ubiiResponseCode;
  final String? ubiiResponseMessage;
  final String estado;

  const FacturaSync({
    this.id,
    required this.numeroControl,
    required this.fechaCreacion,
    required this.clienteId,
    required this.usuarioId,
    this.tipoDocumento = 'Factura',
    required this.baseImponible,
    required this.montoIva,
    this.retencionIva = 0,
    required this.tasaUsd,
    required this.tasaEur,
    required this.total,
    required this.metodoPago,
    this.referenciaPago,
    required this.montoBs,
    required this.montoUsd,
    this.ubiiReference,
    this.ubiiAuthCode,
    this.ubiiCardType,
    this.ubiiTerminal,
    this.ubiiLote,
    this.ubiiResponseCode,
    this.ubiiResponseMessage,
    this.estado = 'activo',
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'numero_control': numeroControl,
        'fecha_creacion': fechaCreacion,
        'cliente_id': clienteId,
        'usuario_id': usuarioId,
        'tipo_documento': tipoDocumento,
        'base_imponible': baseImponible,
        'monto_iva': montoIva,
        'retencion_iva': retencionIva,
        'tasa_usd': tasaUsd,
        'tasa_eur': tasaEur,
        'total': total,
        'metodo_pago': metodoPago,
        'referencia_pago': referenciaPago,
        'monto_bs': montoBs,
        'monto_usd': montoUsd,
        'ubii_reference': ubiiReference,
        'ubii_auth_code': ubiiAuthCode,
        'ubii_card_type': ubiiCardType,
        'ubii_terminal': ubiiTerminal,
        'ubii_lote': ubiiLote,
        'ubii_response_code': ubiiResponseCode,
        'ubii_response_message': ubiiResponseMessage,
        'estado': estado,
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'numero_control': numeroControl,
        'fecha_creacion': fechaCreacion,
        'cliente_id': clienteId,
        'usuario_id': usuarioId,
        'tipo_documento': tipoDocumento,
        'base_imponible': baseImponible,
        'monto_iva': montoIva,
        'retencion_iva': retencionIva,
        'tasa_usd': tasaUsd,
        'tasa_eur': tasaEur,
        'total': total,
        'metodo_pago': metodoPago,
        'referencia_pago': referenciaPago,
        'monto_bs': montoBs,
        'monto_usd': montoUsd,
        'ubii_reference': ubiiReference,
        'ubii_auth_code': ubiiAuthCode,
        'ubii_card_type': ubiiCardType,
        'ubii_terminal': ubiiTerminal,
        'ubii_lote': ubiiLote,
        'ubii_response_code': ubiiResponseCode,
        'ubii_response_message': ubiiResponseMessage,
        'estado': estado,
        ...syncRemoteFields,
      };

  factory FacturaSync.fromLocalMap(Map<String, dynamic> m) => FacturaSync(
        id: m['id'] as int?,
        numeroControl: m['numero_control'] as String,
        fechaCreacion: m['fecha_creacion'] as String,
        clienteId: m['cliente_id'] as int,
        usuarioId: m['usuario_id'] as int,
        tipoDocumento: m['tipo_documento'] as String? ?? 'Factura',
        baseImponible: (m['base_imponible'] as num).toDouble(),
        montoIva: (m['monto_iva'] as num).toDouble(),
        retencionIva: (m['retencion_iva'] as num?)?.toDouble() ?? 0,
        tasaUsd: (m['tasa_usd'] as num).toDouble(),
        tasaEur: (m['tasa_eur'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        metodoPago: m['metodo_pago'] as String,
        referenciaPago: m['referencia_pago'] as String?,
        montoBs: (m['monto_bs'] as num).toDouble(),
        montoUsd: (m['monto_usd'] as num).toDouble(),
        ubiiReference: m['ubii_reference'] as String?,
        ubiiAuthCode: m['ubii_auth_code'] as String?,
        ubiiCardType: m['ubii_card_type'] as String?,
        ubiiTerminal: m['ubii_terminal'] as String?,
        ubiiLote: m['ubii_lote'] as String?,
        ubiiResponseCode: m['ubii_response_code'] as String?,
        ubiiResponseMessage: m['ubii_response_message'] as String?,
        estado: m['estado'] as String? ?? 'activo',
        serverId: m['server_id'] as String?,
        lastModified: SyncableModel.parseLastModified(m),
        syncStatus: SyncStatus.fromInt(m['sync_status'] as int?),
      );

  factory FacturaSync.fromRemoteMap(Map<String, dynamic> m) =>
      FacturaSync.fromLocalMap({...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  FacturaSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      FacturaSync(
        id: id,
        numeroControl: numeroControl,
        fechaCreacion: fechaCreacion,
        clienteId: clienteId,
        usuarioId: usuarioId,
        tipoDocumento: tipoDocumento,
        baseImponible: baseImponible,
        montoIva: montoIva,
        retencionIva: retencionIva,
        tasaUsd: tasaUsd,
        tasaEur: tasaEur,
        total: total,
        metodoPago: metodoPago,
        referenciaPago: referenciaPago,
        montoBs: montoBs,
        montoUsd: montoUsd,
        ubiiReference: ubiiReference,
        ubiiAuthCode: ubiiAuthCode,
        ubiiCardType: ubiiCardType,
        ubiiTerminal: ubiiTerminal,
        ubiiLote: ubiiLote,
        ubiiResponseCode: ubiiResponseCode,
        ubiiResponseMessage: ubiiResponseMessage,
        estado: estado,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class FacturasRepository extends BaseRepository<FacturaSync> {
  static final FacturasRepository instance = FacturasRepository._();
  FacturasRepository._();

  @override
  String get tableName => 'factura';

  /// Facturas: local gana siempre (las ventas son sagradas).
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(FacturaSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(FacturaSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<FacturaSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps =
        await db.query(tableName, orderBy: 'fecha_creacion DESC');
    return maps.map(FacturaSync.fromLocalMap).toList();
  }

  @override
  Future<List<FacturaSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(FacturaSync.fromLocalMap).toList();
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
  FacturaSync fromRemoteMap(Map<String, dynamic> map) =>
      FacturaSync.fromRemoteMap(map);

  /// Marca una factura como pendiente de actualización (ej: al cerrar lote).
  Future<void> marcarPendienteUpdate(int localId) async {
    final db = await DbHelper.instance.database;
    await db.update(
      tableName,
      {
        'sync_status': SyncStatus.pendingUpdate.toInt(),
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}
