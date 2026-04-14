import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
      final adminPassword = _hashPassword('1');
      
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
      version: 3, // Actualizado a versión 3 para agregar tabla de cierres de lote
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
        fecha_creacion $dateType
      )
    ''');

    // 2. TABLA PRODUCTOS
    await db.execute('''
      CREATE TABLE productos (
        id $idType,
        cod_articulo $textType UNIQUE,
        cod_barras $textNull,
        nombre $textType,
        precio $numType,
        fecha_creacion $dateType
      )
    ''');

    // 3. TABLA EXISTENCIAS (Stock)
    await db.execute('''
      CREATE TABLE existencias (
        id $idType,
        producto_id INTEGER NOT NULL,
        cod_articulo $textType,
        stock $numType,
        ultima_actualizacion $dateType,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    // 4. TABLA CLIENTES
    await db.execute('''
      CREATE TABLE clientes (
        id $idType,
        identificacion $textType UNIQUE,
        nombre $textType,
        correo $textNull,
        direccion $textNull,
        fecha_creacion $dateType
      )
    ''');

    // 5. TABLA FACTURA (Cabecera)
    await db.execute('''
      CREATE TABLE factura (
        id $idType,
        fecha_creacion $dateType,
        cliente_id INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL,
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
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
      )
    ''');

    // ========================================================================
    // INSERTAR USUARIO ADMINISTRADOR POR DEFECTO
    // ========================================================================
    debugPrint('🔐 Creando usuario administrador por defecto...');
    
    final adminPassword = _hashPassword('1'); // Contraseña: 1
    
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
      'correo': 'PRUEBA@GMAIL.COM',
      'direccion': 'PRUEBA',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    
    debugPrint('✅ Cliente por defecto creado');
    debugPrint('   Identificación: V-00000000');
    debugPrint('   Nombre: CLIENTE GENERICO');
  }

  // Método para futuras actualizaciones sin perder datos
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Actualizando base de datos de v$oldVersion a v$newVersion');
    
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
        e.stock,
        p.fecha_creacion
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
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
        e.stock
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
      WHERE p.cod_articulo LIKE ? 
         OR p.cod_barras LIKE ? 
         OR p.nombre LIKE ?
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
        e.stock
      FROM productos p
      LEFT JOIN existencias e ON p.id = e.producto_id
      WHERE p.cod_articulo = ? OR p.cod_barras = ?
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

  // ============================================================================
  // MÉTODOS CRUD PARA CLIENTES
  // ============================================================================

  /// Insertar un nuevo cliente
  Future<int> insertarCliente(Map<String, dynamic> cliente) async {
    final db = await database;
    return await db.insert('clientes', {
      ...cliente,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
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
  Future<int> crearFactura({
    required int clienteId,
    required int usuarioId,
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
    
    await db.transaction((txn) async {
      // Insertar cabecera de factura
      facturaId = await txn.insert('factura', {
        'fecha_creacion': DateTime.now().toIso8601String(),
        'cliente_id': clienteId,
        'usuario_id': usuarioId,
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
    });

    return facturaId;
  }

  /// Obtener facturas con filtros opcionales
  Future<List<Map<String, dynamic>>> obtenerFacturas({
    DateTime? desde,
    DateTime? hasta,
    int? limit,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (desde != null) {
      whereClause += 'f.fecha_creacion >= ?';
      whereArgs.add(desde.toIso8601String());
    }
    
    if (hasta != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'f.fecha_creacion <= ?';
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
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
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
      // Convertir datos completos a JSON para almacenamiento
      final datosCompletos = ubiiData.toString();
      
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
        'total_transacciones': ubiiData['totalTransactions'] ?? 0,
        'monto_total': ubiiData['totalAmount'] ?? 0.0,
        'datos_completos': datosCompletos,
      });
      
      debugPrint('✅ Cierre de lote registrado con ID: $cierreId');
      debugPrint('   Usuario ID: $usuarioId');
      debugPrint('   Tipo: $tipoCierre');
      debugPrint('   Terminal: ${ubiiData['terminal']}');
      debugPrint('   Lote: ${ubiiData['lote']}');
      
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
}

