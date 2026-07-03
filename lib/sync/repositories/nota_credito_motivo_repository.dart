import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import 'base_repository.dart';

// =============================================================================
// MODELO SINCRONIZABLE — NOTA_CREDITO_MOTIVO (catálogo)
// =============================================================================

class NotaCreditoMotivoSync extends SyncableModel {
  final int? id;
  final String codigo;
  final String descripcion;
  final String tipo; // 'total' | 'parcial' | 'ambos'
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotaCreditoMotivoSync({
    this.id,
    required this.codigo,
    required this.descripcion,
    this.tipo = 'ambos',
    this.activo = true,
    this.createdAt,
    this.updatedAt,
    super.serverId,
    required super.lastModified,
    required super.syncStatus,
  });

  @override
  Map<String, dynamic> toLocalMap() => {
        if (id != null) 'id': id,
        'codigo': codigo,
        'descripcion': descripcion,
        'tipo': tipo,
        'activo': activo ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        ...syncLocalFields,
      };

  @override
  Map<String, dynamic> toRemoteMap() => {
        'codigo': codigo,
        'descripcion': descripcion,
        'tipo': tipo,
        'activo': activo,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        ...syncRemoteFields,
      };

  factory NotaCreditoMotivoSync.fromLocalMap(Map<String, dynamic> m) => NotaCreditoMotivoSync(
        id: m['id'] as int?,
        codigo: m['codigo'] as String,
        descripcion: m['descripcion'] as String,
        tipo: m['tipo'] as String,
        activo: (m['activo'] as int? ?? 1) == 1,
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

  factory NotaCreditoMotivoSync.fromRemoteMap(Map<String, dynamic> m) =>
      NotaCreditoMotivoSync.fromLocalMap({...m, 'sync_status': SyncStatus.synced.toInt()});

  @override
  NotaCreditoMotivoSync copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) =>
      NotaCreditoMotivoSync(
        id: id,
        codigo: codigo,
        descripcion: descripcion,
        tipo: tipo,
        activo: activo,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serverId: serverId ?? this.serverId,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  /// Verificar si el motivo aplica para notas de crédito totales
  bool get aplicaParaTotal => tipo == 'total' || tipo == 'ambos';

  /// Verificar si el motivo aplica para notas de crédito parciales
  bool get aplicaParaParcial => tipo == 'parcial' || tipo == 'ambos';
}

// =============================================================================
// REPOSITORIO (catálogo - solo descarga desde Supabase)
// =============================================================================

class NotaCreditoMotivoRepository extends BaseRepository<NotaCreditoMotivoSync> {
  static final NotaCreditoMotivoRepository instance = NotaCreditoMotivoRepository._();
  NotaCreditoMotivoRepository._();

  @override
  String get tableName => 'nota_credito_motivo';

  /// Catálogo de motivos: remoto gana (se actualiza desde Supabase)
  @override
  bool get localWinsOnConflict => false;

  @override
  Future<int> insertLocal(NotaCreditoMotivoSync model) async {
    final db = await DbHelper.instance.database;
    return db.insert(tableName, model.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocal(NotaCreditoMotivoSync model) async {
    final db = await DbHelper.instance.database;
    await db.update(tableName, model.toLocalMap(),
        where: 'id = ?', whereArgs: [model.id]);
  }

  @override
  Future<List<NotaCreditoMotivoSync>> getAllLocal() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'tipo ASC, descripcion ASC');
    return maps.map(NotaCreditoMotivoSync.fromLocalMap).toList();
  }

  @override
  Future<List<NotaCreditoMotivoSync>> getLocalByStatus(SyncStatus status) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(tableName,
        where: 'sync_status = ?', whereArgs: [status.toInt()]);
    return maps.map(NotaCreditoMotivoSync.fromLocalMap).toList();
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
  NotaCreditoMotivoSync fromRemoteMap(Map<String, dynamic> map) =>
      NotaCreditoMotivoSync.fromRemoteMap(map);

  /// Obtener motivos por tipo
  Future<List<NotaCreditoMotivoSync>> getByTipo(String tipo) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'tipo IN (?, ?) AND activo = 1',
      whereArgs: [tipo, 'ambos'],
      orderBy: 'descripcion ASC',
    );
    return maps.map(NotaCreditoMotivoSync.fromLocalMap).toList();
  }

  /// Obtener motivo por código
  Future<NotaCreditoMotivoSync?> getByCodigo(String codigo) async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'codigo = ?',
      whereArgs: [codigo],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return NotaCreditoMotivoSync.fromLocalMap(maps.first);
    }
    return null;
  }

  /// Obtener motivos activos
  Future<List<NotaCreditoMotivoSync>> getActivos() async {
    final db = await DbHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: 'activo = 1',
      orderBy: 'tipo ASC, descripcion ASC',
    );
    return maps.map(NotaCreditoMotivoSync.fromLocalMap).toList();
  }

  /// Insertar motivos predefinidos
  Future<void> insertarMotivosPredefinidos() async {
    final motivos = [
      NotaCreditoMotivoSync(
        codigo: 'DEV_TOTAL',
        descripcion: 'Devolución total de la factura',
        tipo: 'total',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'DEV_PARCIAL',
        descripcion: 'Devolución parcial de productos',
        tipo: 'parcial',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'ERROR_FACT',
        descripcion: 'Error en facturación',
        tipo: 'ambos',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'PROD_DEFECT',
        descripcion: 'Producto defectuoso',
        tipo: 'parcial',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'PROD_NO_REC',
        descripcion: 'Producto no recibido por cliente',
        tipo: 'parcial',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'CAMBIO_PRECIO',
        descripcion: 'Cambio de precio',
        tipo: 'parcial',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'DESCUENTO_NO_APL',
        descripcion: 'Descuento no aplicado',
        tipo: 'parcial',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'ANULACION_CLIENTE',
        descripcion: 'Anulación solicitada por cliente',
        tipo: 'total',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
      NotaCreditoMotivoSync(
        codigo: 'ERROR_SISTEMA',
        descripcion: 'Error del sistema',
        tipo: 'ambos',
        activo: true,
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      ),
    ];

    final db = await DbHelper.instance.database;
    
    await db.transaction((txn) async {
      for (final motivo in motivos) {
        await txn.insert(
          tableName,
          motivo.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}