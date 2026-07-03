import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE — NOTA_CREDITO
// =============================================================================

class NotaCreditoSync extends SyncableModel {
  final int? id;
  final String numeroControl;
  final String tipo; // 'total' | 'parcial'
  final int facturaId;
  final String motivo;
  final double montoTotal;
  final double iva;
  final DateTime fechaEmision;
  final String estado; // 'pendiente' | 'procesada' | 'anulada'
  final int? usuarioId;
  final String? observaciones;
  final DateTime? fechaAnulacion;
  final String? motivoAnulacion;
  final int? usuarioAnulacionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotaCreditoSync({
    this.id,
    required this.numeroControl,
    required this.tipo,
    required this.facturaId,
    required this.motivo,
    required this.montoTotal,
    required this.iva,
    required this.fechaEmision,
    this.estado = 'pendiente',
    this.usuarioId,
    this.observaciones,
    this.fechaAnulacion,
    this.motivoAnulacion,
    this.usuarioAnulacionId,
    this.createdAt,
    this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'numero_control': numeroControl,
        'tipo': tipo,
        'factura_id': facturaId,
        'motivo': motivo,
        'monto_total': montoTotal,
        'iva': iva,
        'fecha_emision': fechaEmision.toIso8601String(),
        'estado': estado,
        'usuario_id': usuarioId,
        'observaciones': observaciones,
        'fecha_anulacion': fechaAnulacion?.toIso8601String(),
        'motivo_anulacion': motivoAnulacion,
        'usuario_anulacion_id': usuarioAnulacionId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'numero_control': numeroControl,
        'tipo': tipo,
        'factura_id': facturaId,
        'motivo': motivo,
        'monto_total': montoTotal,
        'iva': iva,
        'fecha_emision': fechaEmision.toIso8601String(),
        'estado': estado,
        'usuario_id': usuarioId,
        'observaciones': observaciones,
        'fecha_anulacion': fechaAnulacion?.toIso8601String(),
        'motivo_anulacion': motivoAnulacion,
        'usuario_anulacion_id': usuarioAnulacionId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        ...syncRemoteFields,
      };

  factory NotaCreditoSync.fromLocalMap(Map<String, dynamic> m) => NotaCreditoSync(
        id: m['id'] as int?,
        numeroControl: m['numero_control'] as String,
        tipo: m['tipo'] as String,
        facturaId: m['factura_id'] as int,
        motivo: m['motivo'] as String,
        montoTotal: (m['monto_total'] as num).toDouble(),
        iva: (m['iva'] as num).toDouble(),
        fechaEmision: DateTime.parse(m['fecha_emision'] as String),
        estado: m['estado'] as String,
        usuarioId: m['usuario_id'] as int?,
        observaciones: m['observaciones'] as String?,
        fechaAnulacion: m['fecha_anulacion'] != null
            ? DateTime.parse(m['fecha_anulacion'] as String)
            : null,
        motivoAnulacion: m['motivo_anulacion'] as String?,
        usuarioAnulacionId: m['usuario_anulacion_id'] as int?,
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

  factory NotaCreditoSync.fromRemoteMap(Map<String, dynamic> m) =>
      NotaCreditoSync.fromLocalMap({...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  NotaCreditoSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      NotaCreditoSync(
        id: id,
        numeroControl: numeroControl,
        tipo: tipo,
        facturaId: facturaId,
        motivo: motivo,
        montoTotal: montoTotal,
        iva: iva,
        fechaEmision: fechaEmision,
        estado: estado,
        usuarioId: usuarioId,
        observaciones: observaciones,
        fechaAnulacion: fechaAnulacion,
        motivoAnulacion: motivoAnulacion,
        usuarioAnulacionId: usuarioAnulacionId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  /// Verificar si es nota de crédito total
  bool get esTotal => tipo == 'total';

  /// Verificar si es nota de crédito parcial
  bool get esParcial => tipo == 'parcial';

  /// Verificar si está pendiente
  bool get estaPendiente => estado == 'pendiente';

  /// Verificar si está procesada
  bool get estaProcesada => estado == 'procesada';

  /// Verificar si está anulada
  bool get estaAnulada => estado == 'anulada';

  /// Calcular total general (monto + IVA)
  double get totalGeneral => montoTotal + iva;
}

// =============================================================================
// REPOSITORIO
// =============================================================================

class NotaCreditoRepository extends BaseRepository<NotaCreditoSync> {
  static final NotaCreditoRepository instance = NotaCreditoRepository._();
  NotaCreditoRepository._();

  @override
  String get tableName => 'nota_credito';

  /// Notas de crédito: local gana siempre (las devoluciones son sagradas)
  @override
  bool get localWinsOnConflict => true;

  @override
  Future<int> insertLocal(NotaCreditoSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(NotaCreditoSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<NotaCreditoSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'fecha_emision DESC');
    return maps.map(NotaCreditoSync.fromLocalMap).toList();
  }

  @override
  Future<List<NotaCreditoSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(NotaCreditoSync.fromLocalMap).toList();
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
  NotaCreditoSync fromRemoteMap(Map<String, dynamic> map) =>
      NotaCreditoSync.fromRemoteMap(map);

  /// Obtener notas de crédito por factura
  Future<List<NotaCreditoSync>> getByFacturaId(int facturaId) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'factura_id = ?',
      whereArgs: [facturaId],
      orderBy: 'fecha_emision DESC',
    );
    return maps.map(NotaCreditoSync.fromLocalMap).toList();
  }

  /// Obtener notas de crédito por estado
  Future<List<NotaCreditoSync>> getByEstado(String estado) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'estado = ?',
      whereArgs: [estado],
      orderBy: 'fecha_emision DESC',
    );
    return maps.map(NotaCreditoSync.fromLocalMap).toList();
  }

  /// Obtener notas de crédito por tipo
  Future<List<NotaCreditoSync>> getByTipo(String tipo) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'tipo = ?',
      whereArgs: [tipo],
      orderBy: 'fecha_emision DESC',
    );
    return maps.map(NotaCreditoSync.fromLocalMap).toList();
  }

  /// Marcar nota de crédito como procesada
  Future<void> marcarComoProcesada(int localId) async {
    final db = await DbHelper.instance.database;
    await db.update(
      tableName,
      {
        'estado': 'procesada',
        'updated_at': DateTime.now().toIso8601String(),
        'last_modified': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.pendingUpdate.toInt(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Anular nota de crédito
  Future<void> anularNotaCredito({
    required int localId,
    required String motivo,
    required int usuarioId,
  }) async {
    final db = await DbHelper.instance.database;
    await db.update(
      tableName,
      {
        'estado': 'anulada',
        'fecha_anulacion': DateTime.now().toIso8601String(),
        'motivo_anulacion': motivo,
        'usuario_anulacion_id': usuarioId,
        'updated_at': DateTime.now().toIso8601String(),
        'last_modified': DateTime.now().toIso8601String(),
        'sync_status': SyncStatus.pendingUpdate.toInt(),
      },
      where: 'id = ? AND estado IN (?, ?)',
      whereArgs: [localId, 'pendiente', 'procesada'],
    );
  }

  /// Verificar si una factura tiene notas de crédito activas
  Future<bool> facturaTieneNotasCredito(int facturaId) async {
    final db = await DbHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM nota_credito 
      WHERE factura_id = ? 
        AND estado IN ('pendiente', 'procesada')
    ''', [facturaId]);
    
    final count = (result.first['count'] as int?) ?? 0;
    return count > 0;
  }

  /// Obtener estadísticas de notas de crédito
  Future<Map<String, dynamic>> obtenerEstadisticas({
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final db = await DbHelper.instance.database;
    
    final where = <String>[];
    final whereArgs = <dynamic>[];
    
    if (fechaDesde != null) {
      where.add('fecha_emision >= ?');
      whereArgs.add(fechaDesde.toIso8601String());
    }
    
    if (fechaHasta != null) {
      where.add('fecha_emision <= ?');
      whereArgs.add(fechaHasta.toIso8601String());
    }
    
    final whereClause = where.isNotEmpty ? where.join(' AND ') : '1=1';
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_notas,
        SUM(monto_total) as total_monto,
        SUM(iva) as total_iva,
        SUM(monto_total + iva) as total_general,
        COUNT(CASE WHEN tipo = 'total' THEN 1 END) as totales,
        COUNT(CASE WHEN tipo = 'parcial' THEN 1 END) as parciales,
        COUNT(CASE WHEN estado = 'pendiente' THEN 1 END) as pendientes,
        COUNT(CASE WHEN estado = 'procesada' THEN 1 END) as procesadas,
        COUNT(CASE WHEN estado = 'anulada' THEN 1 END) as anuladas
      FROM nota_credito
      WHERE $whereClause
    ''', whereArgs);
    
    return result.isNotEmpty ? result.first : {};
  }
}