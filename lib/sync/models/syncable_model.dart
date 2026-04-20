import '../enums/sync_status.dart';

/// Clase base abstracta para todos los modelos sincronizables.
///
/// Implementa el principio de "Modelos Extensibles":
/// cualquier tabla nueva solo necesita heredar de esta clase
/// y ya obtiene los campos de control + helpers de serialización.
///
/// Campos de control heredados:
///   [serverId]     → UUID de Supabase (null hasta la primera subida).
///   [lastModified] → Timestamp de la última modificación local.
///   [syncStatus]   → Estado: synced / pendingUpload / pendingUpdate.
abstract class SyncableModel {
  final String? serverId;
  final DateTime lastModified;
  final SyncStatus syncStatus;

  const SyncableModel({
    this.serverId,
    required this.lastModified,
    required this.syncStatus,
  });

  // ---------------------------------------------------------------------------
  // HELPERS CENTRALIZADOS — evitan repetir los 3 campos en cada subclase
  // ---------------------------------------------------------------------------

  /// Mapa con los 3 campos de control para incluir en toLocalMap().
  /// Uso: { ...syncLocalFields, 'mi_campo': valor }
  Map<String, dynamic> get syncLocalFields => {
        'server_id': serverId,
        'last_modified': lastModified.toIso8601String(),
        'sync_status': syncStatus.toInt(),
      };

  /// Mapa con solo last_modified para incluir en toRemoteMap().
  /// sync_status y server_id no se envían a Supabase.
  Map<String, dynamic> get syncRemoteFields => {
        'last_modified': lastModified.toIso8601String(),
      };

  /// Parsea last_modified desde un mapa (local o remoto).
  static DateTime parseLastModified(Map<String, dynamic> m) =>
      DateTime.tryParse(m['last_modified'] as String? ?? '') ?? DateTime.now();

  // ---------------------------------------------------------------------------
  // CONTRATO — implementar en cada subclase
  // ---------------------------------------------------------------------------

  /// Serializa para SQLite (incluye campos de control vía [syncLocalFields]).
  Map<String, dynamic> toLocalMap();

  /// Serializa para Supabase (incluye solo [syncRemoteFields]).
  Map<String, dynamic> toRemoteMap();

  /// Retorna una copia con los campos de sincronización actualizados.
  SyncableModel copyWithSyncFields({
    String? serverId,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  });
}
