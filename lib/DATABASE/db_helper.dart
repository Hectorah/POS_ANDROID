import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../core/app_config.dart';
import '../sync/services/sync_trigger.dart';

class DbHelper {
  // Patrón Singleton: Una única instancia para toda la app
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  /// Inicializar la base de datos al inicio de la app
  /// Este método debe llamarse en main() o en el splash screen
  static Future<void> initialize() async {
    try {
      debugPrint('🗄️ Inicializando base de datos...');
      
      // Esto forzará la creación de la BD si no existe
      await instance.database;
      
      // Verificar que el usuario admin existe
      final adminExists = await instance._verificarAdminExiste();
      
      if (!adminExists) {
        debugPrint('⚠️ Usuario admin no encontrado, creando...');
        await instance._crearUsuarioAdmin();
      }
      
      debugPrint('✅ Base de datos inicializada correctamente');
      debugPrint('📊 Ubicación: ${await getDatabasesPath()}');
      
      // Mostrar estadísticas
      final stats = await instance.obtenerEstadisticas();
      debugPrint('📈 Estadísticas:');
      debugPrint('   - Productos: ${stats['productos']}');
      debugPrint('   - Clientes: ${stats['clientes']}');
      debugPrint('   - Facturas: ${stats['facturas']}');
      
    } catch (e) {
      debugPrint('❌ Error inicializando base de datos: $e');
      rethrow;
    }
  }

  /// Verificar si el usuario admin existe
  Future<bool> _verificarAdminExiste() async {
    try {
      final db = await database;
      final result = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: ['admin'],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Crear usuario admin si no existe
  Future<void> _crearUsuarioAdmin() async {
    try {
      final db = await database;
      // Contraseña por defecto para desarrollo (cambiar en producción)
      const defaultPassword = '1';
      final adminPassword = _hashPassword(defaultPassword);
      
      await db.insert('usuarios', {
        'nombre': 'Administrador',
        'usuario': 'admin',
        'clave': adminPassword,
        'nivel': 'administrador',
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ Usuario admin creado');
    } catch (e) {
      debugPrint('❌ Error creando usuario admin: $e');
    }
  }

  // Getter para obtener la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('POS_ANDROID.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 13, // v13: índice único en existencias.producto_id para evitar duplicados
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // Habilitar el soporte para llaves foráneas (Relaciones entre tablas)
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Método para hashear contraseñas
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  // ============================================================================
  // MÉTODOS PARA NÚMERO DE CONTROL FISCAL
  // ============================================================================
  
  /// Formatear número de control con el formato estándar: 00-0000001
  /// 
  /// Parámetros:
  /// - [numero]: Número secuencial (1, 2, 3, ...)
  /// - [prefijo]: Prefijo del número de control (por defecto "00")
  /// - [digitos]: Cantidad de dígitos para el número (por defecto 7)
  /// 
  /// Retorna: String en formato "00-0000001"
  static String _formatearNumeroControl(int numero, {String prefijo = '00', int digitos = 7}) {
    final numeroFormateado = numero.toString().padLeft(digitos, '0');
    return '$prefijo-$numeroFormateado';
  }
  
  /// Generar el siguiente número de control disponible
  /// 
  /// Este método:
  /// 1. Consulta el último número de control usado
  /// 2. Incrementa en 1
  /// 3. Formatea con el estándar (00-0000001)
  /// 4. Valida que no exceda el rango autorizado
  /// 
  /// Retorna: String con el número de control generado
  /// Lanza: Exception si se excede el rango autorizado
  Future<String> generarNumeroControl({String? prefijo, int? rangoMaximo}) async {
    final db = await database;
    
    // Usar configuración centralizada si no se especifican parámetros
    final prefijoFinal = prefijo ?? AppConfig.prefijoNumeroControl;
    final rangoMaximoFinal = rangoMaximo ?? AppConfig.rangoMaximoNumeroControl;
    
    try {
      debugPrint('🔢 Generando número de control...');
      
      // 1. Obtener el último número de control usado
      final result = await db.rawQuery('''
        SELECT numero_control 
        FROM factura 
        WHERE numero_control IS NOT NULL
        ORDER BY CAST(SUBSTR(numero_control, INSTR(numero_control, '-') + 1) AS INTEGER) DESC
        LIMIT 1
      ''');
      
      int siguienteNumero = 1; // Por defecto, empezar en 1
      
      if (result.isNotEmpty && result.first['numero_control'] != null) {
        // 2. Extraer el número del formato "00-0000001"
        final ultimoControl = result.first['numero_control'] as String;
        final partes = ultimoControl.split('-');
        
        if (partes.length == 2) {
          final ultimoNumero = int.tryParse(partes[1]) ?? 0;
          siguienteNumero = ultimoNumero + 1;
          
          debugPrint('   Último número de control: $ultimoControl');
          debugPrint('   Siguiente número: $siguienteNumero');
        }
      } else {
        debugPrint('   Primera factura - Iniciando en 1');
      }
      
      // 3. Validar que no exceda el rango autorizado
      if (siguienteNumero > rangoMaximoFinal) {
        final mensaje = 'Rango de números de control agotado. '
                       'Último número: ${_formatearNumeroControl(rangoMaximoFinal, prefijo: prefijoFinal)}. '
                       'Solicite un nuevo rango al SENIAT.';
        debugPrint('❌ $mensaje');
        throw Exception(mensaje);
      }
      
      // 4. Alertar si quedan pocos números disponibles
      final restantes = rangoMaximoFinal - siguienteNumero;
      if (restantes <= AppConfig.umbralAlertaNumeroControl) {
        debugPrint('⚠️ ALERTA: Solo quedan $restantes números de control disponibles');
        debugPrint('   Solicite un nuevo rango al SENIAT pronto');
      }
      
      // 5. Verificar que el número generado no exista ya (defensa ante duplicados del pull)
      bool existe = true;
      while (existe) {
        final check = await db.query(
          'factura',
          columns: ['id'],
          where: 'numero_control = ?',
          whereArgs: [_formatearNumeroControl(siguienteNumero, prefijo: prefijoFinal)],
          limit: 1,
        );
        if (check.isEmpty) {
          existe = false;
        } else {
          debugPrint('⚠️ Número $siguienteNumero ya existe, incrementando...');
          siguienteNumero++;
          if (siguienteNumero > rangoMaximoFinal) {
            throw Exception('Rango de números de control agotado.');
          }
        }
      }

      // 6. Formatear y retornar
      final numeroControl = _formatearNumeroControl(siguienteNumero, prefijo: prefijoFinal);
      debugPrint('✅ Número de control generado: $numeroControl');

      return numeroControl;
      
    } catch (e) {
      debugPrint('❌ Error generando número de control: $e');
      rethrow;
    }
  }
  
  /// Validar que la secuencia de números de control no tenga saltos
  /// 
  /// Este método verifica que todos los números de control sean consecutivos
  /// sin saltos ni duplicados.
  /// 
  /// Retorna: true si la secuencia es válida, false si hay saltos
  Future<bool> validarSecuenciaControl({String prefijo = '00'}) async {
    final db = await database;
    
    try {
      debugPrint('🔍 Validando secuencia de números de control...');
      
      final facturas = await db.rawQuery('''
        SELECT id, numero_control 
        FROM factura 
        WHERE numero_control IS NOT NULL
        ORDER BY id ASC
      ''');
      
      if (facturas.isEmpty) {
        debugPrint('   No hay facturas para validar');
        return true;
      }
      
      for (int i = 0; i < facturas.length; i++) {
        final control = facturas[i]['numero_control'] as String;
        final partes = control.split('-');
        
        if (partes.length != 2 || partes[0] != prefijo) {
          debugPrint('⚠️ Formato inválido en factura ${facturas[i]['id']}: $control');
          return false;
        }
        
        final numero = int.tryParse(partes[1]);
        if (numero == null) {
          debugPrint('⚠️ Número inválido en factura ${facturas[i]['id']}: $control');
          return false;
        }
        
        // Verificar que el número sea i + 1 (secuencia consecutiva)
        final numeroEsperado = i + 1;
        if (numero != numeroEsperado) {
          debugPrint('⚠️ Salto detectado en factura ${facturas[i]['id']}:');
          debugPrint('   Esperado: ${_formatearNumeroControl(numeroEsperado, prefijo: prefijo)}');
          debugPrint('   Encontrado: $control');
          return false;
        }
      }
      
      debugPrint('✅ Secuencia de números de control válida (${facturas.length} facturas)');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error validando secuencia: $e');
      return false;
    }
  }
  
  /// Obtener estadísticas de números de control
  /// 
  /// Retorna información sobre el uso de números de control:
  /// - Último número usado
  /// - Total de facturas
  /// - Números disponibles (si se especifica rango)
  Future<Map<String, dynamic>> obtenerEstadisticasControl({int rangoMaximo = 9999999}) async {
    final db = await database;
    
    try {
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_facturas,
          MAX(numero_control) as ultimo_control
        FROM factura 
        WHERE numero_control IS NOT NULL
      ''');
      
      final totalFacturas = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM factura WHERE numero_control IS NOT NULL'
      )) ?? 0;
      
      final ultimoControl = result.first['ultimo_control'] as String?;
      
      int ultimoNumero = 0;
      if (ultimoControl != null) {
        final partes = ultimoControl.split('-');
        if (partes.length == 2) {
          ultimoNumero = int.tryParse(partes[1]) ?? 0;
        }
      }
      
      final disponibles = rangoMaximo - ultimoNumero;
      
      return {
        'total_facturas': totalFacturas,
        'ultimo_control': ultimoControl ?? 'N/A',
        'ultimo_numero': ultimoNumero,
        'disponibles': disponibles,
        'rango_maximo': rangoMaximo,
        'porcentaje_usado': totalFacturas > 0 
            ? (ultimoNumero / rangoMaximo * 100).toStringAsFixed(2) 
            : '0.00',
      };
      
    } catch (e) {
      debugPrint('❌ Error obteniendo estadísticas de control: $e');
      return {
        'total_facturas': 0,
        'ultimo_control': 'Error',
        'ultimo_numero': 0,
        'disponibles': rangoMaximo,
        'rango_maximo': rangoMaximo,
        'porcentaje_usado': '0.00',
      };
    }
  }

  Future _createDB(Database db, int version) async {
    // Definición de tipos de datos comunes para facilitar la lectura
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNull = 'TEXT';
    const numType = 'REAL NOT NULL DEFAULT 0';
    const dateType = 'TEXT DEFAULT CURRENT_TIMESTAMP';

    // 1. TABLA USUARIOS
    await db.execute('''
      CREATE TABLE usuarios (
        id $idType,
        nombre $textType,
        usuario $textType UNIQUE,
        clave $textType,
        nivel $textType,
        fecha_creacion $dateType,
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. TABLA PRODUCTOS
    await db.execute('''
      CREATE TABLE productos (
        id $idType,
        cod_articulo $textType UNIQUE,
        cod_barras $textNull,
        nombre $textType,
        descripcion $textNull,
        precio $numType,
        tipo_impuesto TEXT NOT NULL DEFAULT 'G',
        unidad_medida TEXT NOT NULL DEFAULT 'und',
        server_id TEXT,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1,
        fecha_creacion $dateType
      )
    ''');

    // 3. TABLA EXISTENCIAS (Stock)
    await db.execute('''
      CREATE TABLE existencias (
        id $idType,
        producto_id INTEGER NOT NULL UNIQUE,
        cod_articulo $textType,
        stock $numType,
        ultima_actualizacion $dateType,
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    // 4. TABLA CLIENTES
    await db.execute('''
      CREATE TABLE clientes (
        id $idType,
        identificacion $textType UNIQUE,
        nombre $textType,
        direccion $textNull,
        telefono $textNull,
        correo $textNull,
        agente_retencion INTEGER DEFAULT 0,
        fecha_creacion $dateType,
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 5. TABLA FACTURA (Cabecera)
    await db.execute('''
      CREATE TABLE factura (
        id $idType,
        numero_control $textType UNIQUE,
        fecha_creacion $dateType,
        cliente_id INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL,
        tipo_documento $textType DEFAULT 'Factura',
        base_imponible $numType,
        monto_iva $numType,
        retencion_iva $numType DEFAULT 0,
        tasa_usd $numType,
        tasa_eur $numType,
        total $numType,
        metodo_pago $textType,
        referencia_pago $textNull,
        monto_bs $numType,
        monto_usd $numType,
        ubii_reference $textNull,
        ubii_auth_code $textNull,
        ubii_card_type $textNull,
        ubii_terminal $textNull,
        ubii_lote $textNull,
        ubii_response_code $textNull,
        ubii_response_message $textNull,
        estado TEXT NOT NULL DEFAULT 'activo',
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id),
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
      )
    ''');

    // 6. TABLA FACTURA DETALLE (Renglones)
    await db.execute('''
      CREATE TABLE factura_detalle (
        id $idType,
        factura_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad $numType,
        precio_unitario $numType,
        subtotal $numType,
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (factura_id) REFERENCES factura (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');

    // 7. TABLA CIERRES DE LOTE (Settlement)
    await db.execute('''
      CREATE TABLE cierres_lote (
        id $idType,
        fecha_creacion $dateType,
        usuario_id INTEGER NOT NULL,
        tipo_cierre $textType,
        ubii_response_code $textNull,
        ubii_response_message $textNull,
        ubii_terminal $textNull,
        ubii_lote $textNull,
        ubii_fecha $textNull,
        ubii_hora $textNull,
        total_transacciones INTEGER DEFAULT 0,
        monto_total $numType,
        datos_completos $textNull,
        server_id $textNull,
        last_modified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sync_status INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
      )
    ''');

    // ========================================================================
    // INSERTAR USUARIO ADMINISTRADOR POR DEFECTO
    // ========================================================================
    debugPrint('🔐 Creando usuario administrador por defecto...');
    
    // Contraseña por defecto para desarrollo (cambiar en producción)
    const defaultPassword = '1';
    final adminPassword = _hashPassword(defaultPassword);
    
    await db.insert('usuarios', {
      'nombre': 'Administrador',
      'usuario': 'admin',
      'clave': adminPassword,
      'nivel': 'administrador',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    
    debugPrint('✅ Usuario admin creado exitosamente');
    debugPrint('   Usuario: admin');
    debugPrint('   Contraseña: 1');

    // ========================================================================
    // INSERTAR CLIENTE POR DEFECTO
    // ========================================================================
    debugPrint('👤 Creando cliente por defecto...');
    
    await db.insert('clientes', {
      'identificacion': 'V-00000000',
      'nombre': 'CLIENTE PRUEBA',
      'direccion': 'PRUEBA',
      'telefono': null,
      'correo': 'PRUEBA@GMAIL.COM',
      'agente_retencion': 0,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    
    debugPrint('✅ Cliente por defecto creado');
    debugPrint('   Identificación: V-00000000');
    debugPrint('   Nombre: CLIENTE GENERICO');
  }

  // Método para futuras actualizaciones sin perder datos
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Actualizando base de datos de v$oldVersion a v$newVersion');

    // Migración v12 a v13: índice único en existencias.producto_id
    // Elimina duplicados y previene que se vuelvan a crear.
    if (oldVersion < 13) {
      debugPrint('📝 Limpiando duplicados en existencias y creando índice único...');
      try {
        // 1. Eliminar filas duplicadas, conservando la de mayor stock
        await db.execute('''
          DELETE FROM existencias
          WHERE id NOT IN (
            SELECT MAX(id)
            FROM existencias
            GROUP BY producto_id
          )
        ''');

        // 2. Crear índice único para prevenir futuros duplicados
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_existencias_producto_id ON existencias(producto_id)',
        );
        debugPrint('✅ Índice único creado en existencias.producto_id');
      } catch (e) {
        debugPrint('⚠️ Error en migración v13: $e');
      }
    }

    // Migración v11 a v12: Campos de sincronización offline-first en TODAS las tablas.
    // server_id  → UUID asignado por Supabase (null hasta la primera subida)
    // last_modified → timestamp de última modificación local
    // sync_status   → 0=synced, 1=pendingUpload, 2=pendingUpdate
    if (oldVersion < 12) {
      final tables = [
        'productos',
        'existencias',
        'clientes',
        'factura',
        'factura_detalle',
        'cierres_lote',
        'usuarios',
      ];
      final now = DateTime.now().toIso8601String();
      for (final table in tables) {
        debugPrint('📝 Agregando campos sync a tabla $table...');
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN server_id TEXT');
          await db.execute(
            "ALTER TABLE $table ADD COLUMN last_modified TEXT NOT NULL DEFAULT '$now'",
          );
          await db.execute(
            'ALTER TABLE $table ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 1',
          );
          debugPrint('✅ Campos sync agregados a $table');
        } catch (e) {
          debugPrint('⚠️ Error en $table (puede que ya existan): $e');
        }
      }
    }

    // Migración v10 a v11: Agregar campo unidad_medida a productos
    if (oldVersion < 11) {
      debugPrint('📝 Agregando campo unidad_medida a tabla productos...');
      try {
        await db.execute(
          "ALTER TABLE productos ADD COLUMN unidad_medida TEXT NOT NULL DEFAULT 'und'",
        );
        debugPrint('✅ Campo unidad_medida agregado');
      } catch (e) {
        debugPrint('⚠️ Error agregando unidad_medida: $e');
      }
    }

    // [TEST] Migración v9 a v10: Agregar campo estado a factura (simulación cierre Z)
    // TODO: REVERTIR - eliminar esta migración y el campo estado cuando ya no se necesite
    if (oldVersion < 10) {
      debugPrint('📝 [TEST] Agregando campo estado a tabla factura...');
      try {
        await db.execute(
          "ALTER TABLE factura ADD COLUMN estado TEXT NOT NULL DEFAULT 'activo'",
        );
        debugPrint('✅ [TEST] Campo estado agregado (activo/cerrado)');
      } catch (e) {
        debugPrint('⚠️ [TEST] Error agregando campo estado: $e');
      }
    }

    // Migración de versión 8 a 9: Agregar campo telefono a clientes
    if (oldVersion < 9) {
      debugPrint('📝 Agregando campo telefono a tabla clientes...');
      
      try {
        // Agregar campo telefono
        await db.execute('ALTER TABLE clientes ADD COLUMN telefono TEXT');
        
        debugPrint('✅ Campo telefono agregado exitosamente');
        debugPrint('   - telefono: Número de teléfono del cliente (opcional)');
      } catch (e) {
        debugPrint('⚠️ Error agregando campo telefono: $e');
      }
    }
    
    // Migración de versión 7 a 8: Agregar campo tipo_impuesto a productos
    if (oldVersion < 8) {
      debugPrint('📝 Agregando campo tipo_impuesto a tabla productos...');
      
      try {
        // Agregar campo tipo_impuesto (E=Exento, G=General 16%)
        await db.execute('ALTER TABLE productos ADD COLUMN tipo_impuesto TEXT NOT NULL DEFAULT "G"');
        
        debugPrint('✅ Campo tipo_impuesto agregado exitosamente');
        debugPrint('   - E: Exento (productos sin IVA)');
        debugPrint('   - G: General (IVA 16%)');
      } catch (e) {
        debugPrint('⚠️ Error agregando campo tipo_impuesto: $e');
      }
    }
    
    // Migración de versión 1 a 2: Agregar campos de pago
    if (oldVersion < 2) {
      debugPrint('📝 Agregando campos de pago a tabla factura...');
      
      await db.execute('ALTER TABLE factura ADD COLUMN metodo_pago TEXT NOT NULL DEFAULT "cash"');
      await db.execute('ALTER TABLE factura ADD COLUMN referencia_pago TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN monto_bs REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE factura ADD COLUMN monto_usd REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_reference TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_auth_code TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_card_type TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_terminal TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_lote TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_response_code TEXT');
      await db.execute('ALTER TABLE factura ADD COLUMN ubii_response_message TEXT');
      
      debugPrint('✅ Campos de pago agregados exitosamente');
    }
    
    // Migración de versión 2 a 3: Agregar tabla de cierres de lote
    if (oldVersion < 3) {
      debugPrint('📝 Creando tabla de cierres de lote...');
      
      await db.execute('''
        CREATE TABLE cierres_lote (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
          usuario_id INTEGER NOT NULL,
          tipo_cierre TEXT NOT NULL,
          ubii_response_code TEXT,
          ubii_response_message TEXT,
          ubii_terminal TEXT,
          ubii_lote TEXT,
          ubii_fecha TEXT,
          ubii_hora TEXT,
          total_transacciones INTEGER DEFAULT 0,
          monto_total REAL NOT NULL DEFAULT 0,
          datos_completos TEXT,
          FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        )
      ''');
      
      debugPrint('✅ Tabla de cierres de lote creada exitosamente');
    }
    
    // Migración de versión 3 a 4: Agregar campos fiscales a tabla factura
    if (oldVersion < 4) {
      debugPrint('📝 Agregando campos fiscales a tabla factura...');
      
      await db.execute('ALTER TABLE factura ADD COLUMN tipo_documento TEXT NOT NULL DEFAULT "Factura"');
      await db.execute('ALTER TABLE factura ADD COLUMN base_imponible REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE factura ADD COLUMN monto_iva REAL NOT NULL DEFAULT 0');
      
      debugPrint('✅ Campos fiscales agregados exitosamente');
      debugPrint('   - tipo_documento: Tipo de documento fiscal');
      debugPrint('   - base_imponible: Subtotal sin IVA');
      debugPrint('   - monto_iva: Monto del IVA (16%)');
    }
    
    // Migración de versión 4 a 5: Agregar número de control
    if (oldVersion < 5) {
      debugPrint('📝 Agregando número de control a tabla factura...');
      
      // Agregar columna numero_control
      await db.execute('ALTER TABLE factura ADD COLUMN numero_control TEXT');
      
      // Generar números de control para facturas existentes
      final facturas = await db.query('factura', orderBy: 'id ASC');
      
      if (facturas.isNotEmpty) {
        debugPrint('   Generando números de control para ${facturas.length} facturas existentes...');
        
        for (int i = 0; i < facturas.length; i++) {
          final facturaId = facturas[i]['id'];
          final numeroControl = _formatearNumeroControl(i + 1);
          
          await db.update(
            'factura',
            {'numero_control': numeroControl},
            where: 'id = ?',
            whereArgs: [facturaId],
          );
        }
        
        debugPrint('   ✅ Números de control generados para facturas existentes');
      }
      
      // Crear índice único para numero_control
      await db.execute('CREATE UNIQUE INDEX idx_numero_control ON factura(numero_control)');
      
      debugPrint('✅ Número de control agregado exitosamente');
      debugPrint('   - Formato: 00-0000001 (correlativo único)');
      debugPrint('   - Índice único creado para validación');
    }
    
    // Migración de versión 5 a 6: Agregar campo descripcion a productos
    if (oldVersion < 6) {
      debugPrint('📝 Agregando campo descripcion a tabla productos...');
      
      try {
        await db.execute('ALTER TABLE productos ADD COLUMN descripcion TEXT');
        
        debugPrint('✅ Campo agregado exitosamente a tabla productos');
        debugPrint('   - descripcion: Descripción detallada del producto');
      } catch (e) {
        debugPrint('⚠️ Error agregando campo a productos (puede que ya exista): $e');
      }
    }
    
    // Migración de versión 6 a 7: Agregar campos de agente de retención
    if (oldVersion < 7) {
      debugPrint('📝 Agregando campos de agente de retención...');
      
      try {
        // Agregar campo agente_retencion a tabla clientes
        await db.execute('ALTER TABLE clientes ADD COLUMN agente_retencion INTEGER DEFAULT 0');
        debugPrint('   ✅ Campo agente_retencion agregado a tabla clientes');
        
        // Agregar campo retencion_iva a tabla factura
        await db.execute('ALTER TABLE factura ADD COLUMN retencion_iva REAL DEFAULT 0');
        debugPrint('   ✅ Campo retencion_iva agregado a tabla factura');
        
        debugPrint('✅ Campos de agente de retención agregados exitosamente');
        debugPrint('   - agente_retencion: Indica si el cliente es agente de retención (0=No, 1=Sí)');
        debugPrint('   - retencion_iva: Monto de retención de IVA (75% del IVA para agentes de retención)');
      } catch (e) {
        debugPrint('⚠️ Error agregando campos de agente de retención: $e');
      }
    }
  }

  // --- MÉTODOS DE AYUDA (CRUD básico) ---

  // Cerrar la base de datos cuando no se use (opcional)
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ============================================================================
  // MÉTODOS CRUD PARA PRODUCTOS
  // ============================================================================

  /// Obtener todos los productos con su stock
  Future<List<Map<String, dynamic>>> obtenerProductos({int? limit, int? offset}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.cod_articulo,
        p.cod_barras,
        p.nombre,
        p.precio,
        p.tipo_impuesto,
        p.unidad_medida,
        COALESCE(e.stock, 0.0) as stock,
        p.fecha_creacion
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
      GROUP BY p.id
      ORDER BY p.nombre ASC
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''');
  }

  /// Buscar productos por código o nombre
  Future<List<Map<String, dynamic>>> buscarProductos(String query) async {
    final db = await database;
    final searchTerm = '%$query%';
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.cod_articulo,
        p.cod_barras,
        p.nombre,
        p.precio,
        p.tipo_impuesto,
        p.unidad_medida,
        COALESCE(e.stock, 0.0) as stock
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
      WHERE p.cod_articulo LIKE ? 
         OR p.cod_barras LIKE ? 
         OR p.nombre LIKE ?
      GROUP BY p.id
      ORDER BY p.nombre ASC
      LIMIT 50
    ''', [searchTerm, searchTerm, searchTerm]);
  }

  /// Obtener un producto por código
  Future<Map<String, dynamic>?> obtenerProductoPorCodigo(String codigo) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        p.id,
        p.cod_articulo,
        p.cod_barras,
        p.nombre,
        p.precio,
        p.tipo_impuesto,
        p.unidad_medida,
        COALESCE(e.stock, 0.0) as stock
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
      WHERE p.cod_articulo = ? OR p.cod_barras = ?
      GROUP BY p.id
      LIMIT 1
    ''', [codigo, codigo]);
    
    return results.isNotEmpty ? results.first : null;
  }

  /// Actualizar stock de un producto
  Future<int> actualizarStock(int productoId, double nuevoStock) async {
    final db = await database;
    return await db.update(
      'existencias',
      {
        'stock': nuevoStock,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'producto_id = ?',
      whereArgs: [productoId],
    );
  }

  /// Reducir stock después de una venta
  Future<bool> reducirStock(int productoId, double cantidad) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Obtener stock actual
        final result = await txn.query(
          'existencias',
          columns: ['stock'],
          where: 'producto_id = ?',
          whereArgs: [productoId],
        );
        
        if (result.isEmpty) return;
        
        final stockActual = result.first['stock'] as double;
        final nuevoStock = stockActual - cantidad;
        
        // Actualizar stock
        await txn.update(
          'existencias',
          {
            'stock': nuevoStock,
            'ultima_actualizacion': DateTime.now().toIso8601String(),
          },
          where: 'producto_id = ?',
          whereArgs: [productoId],
        );
      });
      return true;
    } catch (e) {
      debugPrint('Error reduciendo stock: $e');
      return false;
    }
  }

  /// Crear un nuevo producto
  /// 
  /// Retorna el ID del producto creado
  Future<int> crearProducto({
    required String codArticulo,
    required String codBarras,
    required String nombre,
    required String descripcion,
    required double precio,
    String tipoImpuesto = 'G',
    String unidadMedida = 'und',
  }) async {
    final db = await database;
    
    try {
      debugPrint('📦 Creando producto: $nombre');
      
      final productoId = await db.insert('productos', {
        'cod_articulo': codArticulo,
        'cod_barras': codBarras.isEmpty ? null : codBarras,
        'nombre': nombre,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'precio': precio,
        'tipo_impuesto': tipoImpuesto,
        'unidad_medida': unidadMedida,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ Producto creado con ID: $productoId');
      debugPrint('   Tipo impuesto: ${tipoImpuesto == "E" ? "Exento" : "General 16%"}');
      SyncTrigger.instance.onProductoCreado(productoId).catchError(
        (e) => debugPrint('⚠️ Sync producto en background falló: $e'),
      );
      return productoId;
    } catch (e) {
      debugPrint('❌ Error creando producto: $e');
      rethrow;
    }
  }

  /// Crear existencia inicial para un producto
  /// 
  /// Retorna el ID de la existencia creada
  Future<int> crearExistencia({
    required int productoId,
    required double cantidad,
  }) async {
    final db = await database;
    
    try {
      debugPrint('📊 Creando existencia para producto ID: $productoId');
      
      // Obtener código de artículo del producto
      final producto = await db.query(
        'productos',
        columns: ['cod_articulo'],
        where: 'id = ?',
        whereArgs: [productoId],
        limit: 1,
      );
      
      if (producto.isEmpty) {
        throw Exception('Producto no encontrado con ID: $productoId');
      }
      
      final codArticulo = producto.first['cod_articulo'] as String;
      
      final existenciaId = await db.insert('existencias', {
        'producto_id': productoId,
        'cod_articulo': codArticulo,
        'stock': cantidad,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ Existencia creada con ID: $existenciaId (Stock: $cantidad)');
      return existenciaId;
    } catch (e) {
      debugPrint('❌ Error creando existencia: $e');
      rethrow;
    }
  }

  /// Buscar producto por código de artículo o código de barras
  /// 
  /// Retorna el producto si existe, null si no se encuentra
  Future<Map<String, dynamic>?> buscarProductoPorCodigo(String codigo) async {
    final db = await database;
    
    try {
      final results = await db.rawQuery('''
        SELECT 
          p.id,
          p.cod_articulo,
          p.cod_barras,
          p.nombre,
          p.descripcion,
          p.precio,
          p.tipo_impuesto,
          e.stock
        FROM productos p
        LEFT JOIN existencias e ON p.id = e.producto_id
        WHERE p.cod_articulo = ? OR p.cod_barras = ?
        LIMIT 1
      ''', [codigo, codigo]);
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('❌ Error buscando producto por código: $e');
      return null;
    }
  }

  /// Actualizar un producto existente
  /// 
  /// Retorna true si se actualizó correctamente
  Future<bool> actualizarProducto({
    required int productoId,
    required String codBarras,
    required String nombre,
    required String descripcion,
    required double precio,
    required double stock,
    String tipoImpuesto = 'G',
    String unidadMedida = 'und',
  }) async {
    final db = await database;
    
    try {
      debugPrint('📝 Actualizando producto ID: $productoId');
      
      await db.transaction((txn) async {
        // Actualizar producto
        await txn.update(
          'productos',
          {
            'cod_barras': codBarras.isEmpty ? null : codBarras,
            'nombre': nombre,
            'descripcion': descripcion.isEmpty ? null : descripcion,
            'precio': precio,
            'tipo_impuesto': tipoImpuesto,
            'unidad_medida': unidadMedida,
          },
          where: 'id = ?',
          whereArgs: [productoId],
        );
        
        // Actualizar stock
        await txn.update(
          'existencias',
          {
            'stock': stock,
            'ultima_actualizacion': DateTime.now().toIso8601String(),
          },
          where: 'producto_id = ?',
          whereArgs: [productoId],
        );
      });
      
      debugPrint('✅ Producto actualizado correctamente');
      SyncTrigger.instance.onProductoActualizado(productoId).catchError(
        (e) => debugPrint('⚠️ Sync producto actualizado falló: $e'),
      );
      SyncTrigger.instance.onExistenciaActualizada(productoId).catchError(
        (e) => debugPrint('⚠️ Sync existencia actualizada falló: $e'),
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando producto: $e');
      return false;
    }
  }

  /// Eliminar un producto
  /// 
  /// Verifica si el producto está en facturas antes de eliminar
  /// Retorna un Map con 'success' y 'message'
  Future<Map<String, dynamic>> eliminarProducto(int productoId) async {
    final db = await database;
    
    try {
      debugPrint('🗑️ Verificando si se puede eliminar producto ID: $productoId');
      
      // Verificar si el producto está en alguna factura
      final facturas = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM factura_detalle
        WHERE producto_id = ?
      ''', [productoId]);
      
      final count = Sqflite.firstIntValue(facturas) ?? 0;
      
      if (count > 0) {
        debugPrint('⚠️ No se puede eliminar: producto usado en $count factura(s)');
        return {
          'success': false,
          'message': 'No se puede eliminar este producto porque está registrado en $count factura(s). '
                    'Los productos con historial de ventas deben mantenerse en el sistema.',
        };
      }
      
      // Si no está en facturas, proceder a eliminar
      // Obtener cod_articulo antes de eliminar (para sync)
      final productoRows = await db.query('productos',
          columns: ['cod_articulo'], where: 'id = ?', whereArgs: [productoId]);
      final codArticulo = productoRows.isNotEmpty
          ? productoRows.first['cod_articulo'] as String
          : null;

      await db.transaction((txn) async {
        // Eliminar existencias primero
        await txn.delete(
          'existencias',
          where: 'producto_id = ?',
          whereArgs: [productoId],
        );
        
        // Eliminar producto
        await txn.delete(
          'productos',
          where: 'id = ?',
          whereArgs: [productoId],
        );
      });
      
      debugPrint('✅ Producto eliminado correctamente');
      if (codArticulo != null) {
        SyncTrigger.instance.onProductoEliminado(codArticulo).catchError(
          (e) => debugPrint('⚠️ Sync eliminación falló: $e'),
        );
      }
      return {
        'success': true,
        'message': 'Producto eliminado exitosamente',
      };
    } catch (e) {
      debugPrint('❌ Error eliminando producto: $e');
      return {
        'success': false,
        'message': 'Error al eliminar el producto: $e',
      };
    }
  }

  // ============================================================================
  // MÉTODOS CRUD PARA CLIENTES
  // ============================================================================

  /// Insertar un nuevo cliente
  Future<int> insertarCliente(Map<String, dynamic> cliente) async {
    final db = await database;
    final id = await db.insert('clientes', {
      ...cliente,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    SyncTrigger.instance.onClienteCreado(id).catchError(
      (e) => debugPrint('⚠️ Sync cliente creado falló: $e'),
    );
    return id;
  }

  /// Actualizar un cliente existente
  Future<int> actualizarCliente(int id, Map<String, dynamic> datos) async {
    final db = await database;
    final count = await db.update(
      'clientes',
      datos,
      where: 'id = ?',
      whereArgs: [id],
    );
    SyncTrigger.instance.onClienteActualizado(id).catchError(
      (e) => debugPrint('⚠️ Sync cliente actualizado falló: $e'),
    );
    return count;
  }

  /// Obtener todos los clientes
  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    final db = await database;
    return await db.query('clientes', orderBy: 'nombre ASC');
  }

  /// Buscar cliente por identificación
  Future<Map<String, dynamic>?> buscarClientePorId(String identificacion) async {
    final db = await database;
    final results = await db.query(
      'clientes',
      where: 'identificacion = ?',
      whereArgs: [identificacion],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Buscar clientes por nombre
  Future<List<Map<String, dynamic>>> buscarClientesPorNombre(String nombre) async {
    final db = await database;
    return await db.query(
      'clientes',
      where: 'nombre LIKE ?',
      whereArgs: ['%$nombre%'],
      orderBy: 'nombre ASC',
      limit: 50,
    );
  }

  // ============================================================================
  // MÉTODOS CRUD PARA FACTURAS
  // ============================================================================

  /// Crear una nueva factura con sus detalles
  /// 
  /// IMPORTANTE: El número de control se genera automáticamente si no se proporciona.
  /// Solo proporciona un número de control manualmente en casos especiales (migraciones, etc.)
  Future<int> crearFactura({
    required int clienteId,
    required int usuarioId,
    String? numeroControl, // Opcional - se genera automáticamente si es null
    String tipoDocumento = 'Factura',
    required double baseImponible,
    required double montoIva,
    double retencionIva = 0.0,
    required double tasaUsd,
    required double tasaEur,
    required double total,
    required List<Map<String, dynamic>> detalles,
    required String metodoPago,
    String? referenciaPago,
    required double montoBs,
    required double montoUsd,
    String? ubiiReference,
    String? ubiiAuthCode,
    String? ubiiCardType,
    String? ubiiTerminal,
    String? ubiiLote,
    String? ubiiResponseCode,
    String? ubiiResponseMessage,
  }) async {
    final db = await database;
    int facturaId = 0;

    // Generar número de control con verificación de unicidad incorporada
    // (generarNumeroControl ya salta números que existan por el pull)
    String numeroControlFinal = numeroControl ?? await generarNumeroControl();

    debugPrint('📄 Creando factura con número de control: $numeroControlFinal');

    // Retry: si por alguna condición de carrera el número ya existe, regenerar
    int intentos = 0;
    while (intentos < 5) {
      try {
        await db.transaction((txn) async {
      
      // Insertar cabecera de factura
      facturaId = await txn.insert('factura', {
        'numero_control': numeroControlFinal,
        'fecha_creacion': DateTime.now().toIso8601String(),
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
      });

      // Insertar detalles y actualizar stock
      for (var detalle in detalles) {
        await txn.insert('factura_detalle', {
          'factura_id': facturaId,
          'producto_id': detalle['producto_id'],
          'cantidad': detalle['cantidad'],
          'precio_unitario': detalle['precio_unitario'],
          'subtotal': detalle['subtotal'],
        });

        // Reducir stock
        await txn.rawUpdate('''
          UPDATE existencias 
          SET stock = stock - ?,
              ultima_actualizacion = ?
          WHERE producto_id = ?
        ''', [
          detalle['cantidad'],
          DateTime.now().toIso8601String(),
          detalle['producto_id'],
        ]);
      }
        }); // fin transaction
        break; // éxito — salir del retry loop
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() && intentos < 4) {
          intentos++;
          debugPrint('⚠️ Número de control $numeroControlFinal ya existe, reintentando ($intentos/5)...');
          numeroControlFinal = await generarNumeroControl();
          debugPrint('🔢 Nuevo número de control: $numeroControlFinal');
        } else {
          rethrow;
        }
      }
    }

    // Sincronizar con Supabase en segundo plano (no bloquea la UI)
    SyncTrigger.instance.onFacturaCreada(facturaId).catchError(
      (e) => debugPrint('⚠️ Sync factura en background falló: $e'),
    );

    return facturaId;
  }

  // [TEST] Cierre Z simulado: marcar facturas del día como cerradas
  // TODO: REVERTIR - eliminar este método cuando ya no se necesite
  Future<int> cerrarFacturasDelDia() async {
    final db = await database;
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).toIso8601String();
    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59).toIso8601String();

    final count = await db.rawUpdate('''
      UPDATE factura
      SET estado = 'cerrado'
      WHERE estado = 'activo'
        AND fecha_creacion >= ?
        AND fecha_creacion <= ?
    ''', [inicio, fin]);

    debugPrint('🔒 [TEST] Facturas cerradas del día: $count');
    return count;
  }

  /// Obtener facturas con filtros opcionales
  Future<List<Map<String, dynamic>>> obtenerFacturas({
    DateTime? desde,
    DateTime? hasta,
    int? limit,
  }) async {
    final db = await database;
    
    String whereClause = "f.estado = 'activo'";
    List<dynamic> whereArgs = [];
    
    if (desde != null) {
      whereClause += ' AND f.fecha_creacion >= ?';
      whereArgs.add(desde.toIso8601String());
    }
    
    if (hasta != null) {
      whereClause += ' AND f.fecha_creacion <= ?';
      whereArgs.add(hasta.toIso8601String());
    }
    
    return await db.rawQuery('''
      SELECT 
        f.*,
        c.nombre as cliente_nombre,
        c.identificacion as cliente_identificacion,
        u.nombre as usuario_nombre
      FROM factura f
      INNER JOIN clientes c ON f.cliente_id = c.id
      INNER JOIN usuarios u ON f.usuario_id = u.id
      WHERE $whereClause
      ORDER BY f.fecha_creacion DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', whereArgs);
  }

  /// Obtener detalles de productos de una factura
  Future<List<Map<String, dynamic>>> obtenerDetallesFactura(int facturaId) async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT 
        fd.*,
        p.nombre as producto_nombre,
        p.cod_articulo as producto_codigo
      FROM factura_detalle fd
      INNER JOIN productos p ON fd.producto_id = p.id
      WHERE fd.factura_id = ?
      ORDER BY fd.id ASC
    ''', [facturaId]);
  }

  /// Obtener detalle de una factura
  Future<Map<String, dynamic>?> obtenerDetalleFactura(int facturaId) async {
    final db = await database;
    
    // Obtener cabecera
    final facturas = await db.rawQuery('''
      SELECT 
        f.*,
        c.nombre as cliente_nombre,
        c.identificacion as cliente_id,
        u.nombre as usuario_nombre
      FROM factura f
      INNER JOIN clientes c ON f.cliente_id = c.id
      INNER JOIN usuarios u ON f.usuario_id = u.id
      WHERE f.id = ?
    ''', [facturaId]);
    
    if (facturas.isEmpty) return null;
    
    final factura = Map<String, dynamic>.from(facturas.first);
    
    // Obtener detalles
    final detalles = await db.rawQuery('''
      SELECT 
        fd.*,
        p.nombre as producto_nombre,
        p.cod_articulo
      FROM factura_detalle fd
      INNER JOIN productos p ON fd.producto_id = p.id
      WHERE fd.factura_id = ?
    ''', [facturaId]);
    
    factura['detalles'] = detalles;
    
    return factura;
  }

  // ============================================================================
  // MÉTODOS CRUD PARA USUARIOS
  // ============================================================================

  /// Insertar un nuevo usuario
  Future<int> insertarUsuario(Map<String, dynamic> usuario) async {
    final db = await database;
    return await db.insert('usuarios', {
      ...usuario,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  /// Verificar credenciales de usuario
  Future<Map<String, dynamic>?> verificarUsuario(String usuario, String clave) async {
    final db = await database;
    final claveHash = _hashPassword(clave);
    final results = await db.query(
      'usuarios',
      where: 'usuario = ? AND clave = ?',
      whereArgs: [usuario, claveHash],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Hashear contraseña (método público para uso externo)
  String hashPassword(String password) {
    return _hashPassword(password);
  }

  /// Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> obtenerUsuarios() async {
    final db = await database;
    return await db.query('usuarios', orderBy: 'nombre ASC');
  }

  /// Actualizar contraseña de un usuario
  Future<bool> actualizarClaveUsuario(String usuario, String nuevaClaveHash) async {
    try {
      final db = await database;
      final count = await db.update(
        'usuarios',
        {'clave': nuevaClaveHash},
        where: 'usuario = ?',
        whereArgs: [usuario],
      );
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error actualizando clave de usuario: $e');
      return false;
    }
  }

  // ============================================================================
  // MÉTODOS DE UTILIDAD
  // ============================================================================

  /// Obtener estadísticas generales
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await database;
    
    final productos = await db.rawQuery('SELECT COUNT(*) as count FROM productos');
    final clientes = await db.rawQuery('SELECT COUNT(*) as count FROM clientes');
    final facturas = await db.rawQuery('SELECT COUNT(*) as count FROM factura');
    final totalVentas = await db.rawQuery('SELECT SUM(total) as total FROM factura');
    
    return {
      'productos': Sqflite.firstIntValue(productos) ?? 0,
      'clientes': Sqflite.firstIntValue(clientes) ?? 0,
      'facturas': Sqflite.firstIntValue(facturas) ?? 0,
      'total_ventas': (totalVentas.first['total'] as double?) ?? 0.0,
    };
  }

  /// Limpiar toda la base de datos (útil para testing)
  Future<void> limpiarBaseDatos() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('factura_detalle');
      await txn.delete('factura');
      await txn.delete('cierres_lote');
      await txn.delete('existencias');
      await txn.delete('productos');
      await txn.delete('clientes');
      await txn.delete('usuarios');
    });
  }

  // ============================================================================
  // MÉTODOS CRUD PARA CIERRES DE LOTE
  // ============================================================================

  /// Registrar un cierre de lote
  Future<int> registrarCierreLote({
    required int usuarioId,
    required String tipoCierre,
    required Map<String, dynamic> ubiiData,
  }) async {
    final db = await database;
    
    try {
      final datosCompletos = ubiiData.toString();

      // Calcular totales reales desde las facturas locales del día
      final totalesLocales = await obtenerTotalesDelDia();
      final totalFacturasLocales = totalesLocales['total_facturas'] ?? 0;
      final montoTotalLocal = (totalesLocales['total_usd'] as num?)?.toDouble() ?? 0.0;

      // Usar valores locales si Ubii no devuelve datos confiables
      final totalTransacciones = (ubiiData['totalTransactions'] != null && ubiiData['totalTransactions'] != 0)
          ? ubiiData['totalTransactions']
          : totalFacturasLocales;
      final montoTotal = (ubiiData['totalAmount'] != null && ubiiData['totalAmount'] != 0)
          ? (double.tryParse(ubiiData['totalAmount'].toString()) ?? montoTotalLocal)
          : montoTotalLocal;

      final cierreId = await db.insert('cierres_lote', {
        'fecha_creacion': DateTime.now().toIso8601String(),
        'usuario_id': usuarioId,
        'tipo_cierre': tipoCierre,
        'ubii_response_code': ubiiData['code'],
        'ubii_response_message': ubiiData['message'],
        'ubii_terminal': ubiiData['terminal'],
        'ubii_lote': ubiiData['lote'],
        'ubii_fecha': ubiiData['date'],
        'ubii_hora': ubiiData['time'],
        'total_transacciones': totalTransacciones,
        'monto_total': montoTotal,
        'datos_completos': datosCompletos,
      });
      
      debugPrint('✅ Cierre de lote registrado con ID: $cierreId');
      debugPrint('   Transacciones: $totalTransacciones');
      debugPrint('   Monto total: $montoTotal');
      SyncTrigger.instance.onCierreLoteCreado(cierreId).catchError(
        (e) => debugPrint('⚠️ Sync cierre lote falló: $e'),
      );
      return cierreId;
    } catch (e) {
      debugPrint('❌ Error registrando cierre de lote: $e');
      rethrow;
    }
  }

  /// Obtener todos los cierres de lote con filtros opcionales
  Future<List<Map<String, dynamic>>> obtenerCierresLote({
    DateTime? desde,
    DateTime? hasta,
    int? limit,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (desde != null) {
      whereClause += 'c.fecha_creacion >= ?';
      whereArgs.add(desde.toIso8601String());
    }
    
    if (hasta != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'c.fecha_creacion <= ?';
      whereArgs.add(hasta.toIso8601String());
    }
    
    return await db.rawQuery('''
      SELECT 
        c.*,
        u.nombre as usuario_nombre
      FROM cierres_lote c
      INNER JOIN usuarios u ON c.usuario_id = u.id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY c.fecha_creacion DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', whereArgs);
  }

  /// Obtener el último cierre de lote
  Future<Map<String, dynamic>?> obtenerUltimoCierre() async {
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT 
        c.*,
        u.nombre as usuario_nombre
      FROM cierres_lote c
      INNER JOIN usuarios u ON c.usuario_id = u.id
      ORDER BY c.fecha_creacion DESC
      LIMIT 1
    ''');
    
    return results.isNotEmpty ? results.first : null;
  }

  /// Obtener cierres de lote de hoy
  Future<List<Map<String, dynamic>>> obtenerCierresDeHoy() async {
    final hoy = DateTime.now();
    final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDelDia = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    
    return await obtenerCierresLote(
      desde: inicioDelDia,
      hasta: finDelDia,
    );
  }

  /// Verificar si ya se hizo cierre hoy
  Future<bool> yaSeHizoCierreHoy() async {
    final cierresHoy = await obtenerCierresDeHoy();
    return cierresHoy.isNotEmpty;
  }

  /// Obtener estadísticas de cierres
  Future<Map<String, dynamic>> obtenerEstadisticasCierres() async {
    final db = await database;
    
    final totalCierres = await db.rawQuery('SELECT COUNT(*) as count FROM cierres_lote');
    final montoTotal = await db.rawQuery('SELECT SUM(monto_total) as total FROM cierres_lote');
    final ultimoCierre = await obtenerUltimoCierre();
    
    return {
      'total_cierres': Sqflite.firstIntValue(totalCierres) ?? 0,
      'monto_total_acumulado': (montoTotal.first['total'] as double?) ?? 0.0,
      'ultimo_cierre': ultimoCierre,
    };
  }

  /// Obtener totales de facturas activas del día actual
  Future<Map<String, dynamic>> obtenerTotalesDelDia() async {
    final db = await database;
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).toIso8601String();
    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_facturas,
        COALESCE(SUM(total), 0) as total_usd,
        COALESCE(SUM(monto_bs), 0) as total_bs,
        COALESCE(SUM(base_imponible), 0) as base_imponible,
        COALESCE(SUM(monto_iva), 0) as total_iva,
        COALESCE(SUM(retencion_iva), 0) as total_retencion
      FROM factura
      WHERE estado = 'activo'
        AND fecha_creacion >= ?
        AND fecha_creacion <= ?
    ''', [inicio, fin]);

    return result.isNotEmpty ? result.first : {
      'total_facturas': 0,
      'total_usd': 0.0,
      'total_bs': 0.0,
      'base_imponible': 0.0,
      'total_iva': 0.0,
      'total_retencion': 0.0,
    };
  }
}

