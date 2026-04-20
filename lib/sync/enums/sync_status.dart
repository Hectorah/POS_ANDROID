/// Estados de sincronización para cada registro local.
///
/// - [synced]         → El registro está sincronizado con Supabase.
/// - [pendingUpload]  → Registro nuevo, aún no subido a Supabase.
/// - [pendingUpdate]  → Registro modificado localmente, pendiente de actualizar en Supabase.
enum SyncStatus {
  synced,
  pendingUpload,
  pendingUpdate;

  /// Convierte el enum a entero para almacenar en SQLite.
  int toInt() {
    switch (this) {
      case SyncStatus.synced:
        return 0;
      case SyncStatus.pendingUpload:
        return 1;
      case SyncStatus.pendingUpdate:
        return 2;
    }
  }

  /// Reconstruye el enum desde un entero leído de SQLite.
  static SyncStatus fromInt(int? value) {
    switch (value) {
      case 0:
        return SyncStatus.synced;
      case 1:
        return SyncStatus.pendingUpload;
      case 2:
        return SyncStatus.pendingUpdate;
      default:
        return SyncStatus.pendingUpload;
    }
  }
}
