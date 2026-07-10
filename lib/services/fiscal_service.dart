import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../core/app_config.dart';
import '../models/fiscal_models.dart';
import '../sync/enums/sync_status.dart';
import '../sync/repositories/sesiones_fiscales_repository.dart';
import '../sync/repositories/reportes_cierre_repository.dart';
import '../sync/services/sync_trigger.dart';
import 'thermal_printer_service.dart';
import 'exchange_rate_service.dart';

class FiscalService {
  static final FiscalService instance = FiscalService._();
  FiscalService._();

  /// Obtiene la sesión fiscal actualmente abierta.
  /// Retorna [SesionFiscal] o [null] si no hay ninguna.
  Future<SesionFiscal?> obtenerSesionActual() async {
    try {
      final db = await DbHelper.instance.database;
      final results = await db.query(
        'sesiones_fiscales',
        where: "estado = 'ABIERTA'",
        limit: 1,
      );
      if (results.isEmpty) return null;
      return SesionFiscal.fromLocalMap(results.first);
    } catch (e) {
      debugPrint('❌ Error obteniendo sesión fiscal actual: $e');
      return null;
    }
  }

  /// Indica si hay una sesión fiscal activa/abierta.
  Future<bool> haySesionAbierta() async {
    final sesion = await obtenerSesionActual();
    return sesion != null;
  }

  /// Realiza la Apertura Fiscal del día.
  /// Lanza excepción si ya existe una sesión abierta.
  Future<SesionFiscal> abrirSesion(int usuarioId, String usuarioNombre,
      {double fondoCajaInicial = 0.0}) async {
    final sesionActual = await obtenerSesionActual();
    if (sesionActual != null) {
      throw Exception(
          'Ya existe una sesión fiscal abierta (${sesionActual.numeroSesion})');
    }

    final db = await DbHelper.instance.database;
    final ahora = DateTime.now();

    // Generar número de sesión correlativo numérico estándar de 6 dígitos: 000000
    final resultCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sesiones_fiscales');
    final count = Sqflite.firstIntValue(resultCount) ?? 0;
    final secuencia = (count + 1).toString().padLeft(6, '0');
    final numeroSesion = secuencia;

    final nuevaSesion = SesionFiscal(
      numeroSesion: numeroSesion,
      fechaApertura: ahora,
      usuarioAperturaId: usuarioId,
      usuarioAperturaNombre: usuarioNombre,
      estado: EstadoSesionFiscal.abierta,
      fondoCajaInicial: fondoCajaInicial,
      createdAt: ahora,
      updatedAt: ahora,
      lastModified: ahora,
      syncStatus: SyncStatus.pendingUpload,
    );

    final localId =
        await SesionesFiscalesRepository.instance.insertLocal(nuevaSesion);

    // Disparar sincronización offline-first
    SyncTrigger.instance.onSesionFiscalCreada(localId).catchError(
          (e) => debugPrint('⚠️ Sync fiscal_sesion falló: $e'),
        );

    debugPrint('✅ Sesión fiscal abierta: $numeroSesion (ID Local: $localId)');

    // Crear objeto final con el ID local asignado
    return SesionFiscal(
      id: localId,
      numeroSesion: nuevaSesion.numeroSesion,
      fechaApertura: nuevaSesion.fechaApertura,
      usuarioAperturaId: nuevaSesion.usuarioAperturaId,
      usuarioAperturaNombre: nuevaSesion.usuarioAperturaNombre,
      estado: nuevaSesion.estado,
      fondoCajaInicial: nuevaSesion.fondoCajaInicial,
      createdAt: nuevaSesion.createdAt,
      updatedAt: nuevaSesion.updatedAt,
      lastModified: nuevaSesion.lastModified,
      syncStatus: nuevaSesion.syncStatus,
      serverId: localId.toString(),
    );
  }

  /// Realiza el arqueo de caja (Cierre X).
  Future<ArqueoCaja> realizarArqueo({
    required int sesionId,
    required int usuarioId,
    required String usuarioNombre,
    required ConteoEfectivo conteo,
    required double totalTarjetaDeclarado,
    required double totalPagoMovilDeclarado,
    required double totalOtrosDeclarado,
    String? observaciones,
  }) async {
    final db = await DbHelper.instance.database;
    final ahora = DateTime.now();

    // 1. OBTENER TOTALES Y TASAS DEL SISTEMA
    final rates = await ExchangeRateService.getCurrentRates();
    final double tasaUsd = rates['USD'] ?? 36.50;
    final double tasaEur = rates['EUR'] ?? 40.00;
    final double tasaCop = rates['COP'] ?? 0.012;

    final totales = await calcularTotalesSesion(sesionId);
    final facturas = totales['facturas'];
    final ncs = totales['notas_credito'];

    // Considerar fondo inicial
    final sesionResult = await db
        .query('sesiones_fiscales', where: 'id = ?', whereArgs: [sesionId]);
    final double fondoInicial =
        (sesionResult.first['fondo_caja_inicial'] as num? ?? 0.0).toDouble();

    final double efectivoSistema =
        (facturas['efectivo'] as num? ?? 0.0).toDouble();
    final double tarjetaSistema =
        (facturas['tarjeta'] as num? ?? 0.0).toDouble();
    final double pagoMovilSistema =
        (facturas['pago_movil'] as num? ?? 0.0).toDouble();
    final double otrosSistema = (facturas['otros'] as num? ?? 0.0).toDouble();

    final double efectivoTeorico = fondoInicial + efectivoSistema;

    // 2. CALCULAR CONVERSIÓN DE DECLARACIONES
    // Convertir montos a USD (moneda base del sistema)
    final double efectivoDeclarado = conteo.efectivoUsd +
        (conteo.efectivoBs / tasaUsd) +
        (conteo.efectivoEur * (tasaEur / tasaUsd)) +
        (conteo.efectivoCop * (tasaCop / tasaUsd));

    // 3. CALCULAR DIFERENCIAS
    // Solo el efectivo requiere conteo físico manual.
    // Tarjeta, Pago Móvil y Otros son pagos electrónicos registrados
    // automáticamente por el sistema y no generan diferencia.
    final double diferenciaEfectivo = efectivoDeclarado - efectivoTeorico;
    final double diferenciaTarjeta = totalTarjetaDeclarado - tarjetaSistema;
    final double diferenciaPagoMovil =
        totalPagoMovilDeclarado - pagoMovilSistema;
    // La diferencia total del cuadre se basa únicamente en el efectivo
    final double diferenciaTotal = diferenciaEfectivo;

    // 4. GENERAR NÚMERO DE ARQUEO ESTÁNDAR DE 6 DÍGITOS
    final resultCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM arqueos_caja');
    final count = Sqflite.firstIntValue(resultCount) ?? 0;
    final secuencia = (count + 1).toString().padLeft(6, '0');
    final numeroArqueo = secuencia;

    final arqueo = ArqueoCaja(
      sesionFiscalId: sesionId,
      numeroArqueo: numeroArqueo,
      fechaArqueo: ahora,
      usuarioArqueoId: usuarioId,
      usuarioArqueoNombre: usuarioNombre,
      conteo: conteo,
      totalEfectivoDeclarado: efectivoDeclarado,
      totalTarjetaDeclarado: totalTarjetaDeclarado,
      totalPagoMovilDeclarado: totalPagoMovilDeclarado,
      totalOtrosDeclarado: totalOtrosDeclarado,
      totalEfectivoSistema: efectivoTeorico,
      totalTarjetaSistema: tarjetaSistema,
      totalPagoMovilSistema: pagoMovilSistema,
      totalOtrosSistema: otrosSistema,
      diferenciaEfectivo: diferenciaEfectivo,
      diferenciaTarjeta: diferenciaTarjeta,
      diferenciaPagoMovil: diferenciaPagoMovil,
      diferenciaTotal: diferenciaTotal,
      cuadrado: diferenciaTotal.abs() < 0.01,
      observaciones: observaciones,
      fondoCajaInicial: fondoInicial,
      createdAt: ahora,
      updatedAt: ahora,
      serverId: null,
      lastModified: ahora,
      syncStatus: SyncStatus.pendingUpload,
    );

    // 5. GUARDAR EN BD
    final arqueoId = await db.insert('arqueos_caja', arqueo.toLocalMap());

    // Vincular con la sesión
    await db.update(
        'sesiones_fiscales',
        {
          'arqueo_realizado': 1,
          'arqueo_id': arqueoId,
          'updated_at': ahora.toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [sesionId]);

    debugPrint('✅ Arqueo de caja realizado: $numeroArqueo');

    // 6. RECOPILAR DATOS DEL CIERRE X FISCAL
    final double totalNc = (ncs['total_nc'] as num? ?? 0.0).toDouble();
    final int cantidadNc = ncs['cantidad_nc'] as int? ?? 0;

    final anulacionesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_anuladas,
        COALESCE(SUM(total), 0) as total_anuladas
      FROM factura
      WHERE sesion_fiscal_id = ? AND estado = 'anulado'
    ''', [sesionId]);
    final int cantidadAnuladas = anulacionesResult.first['cantidad_anuladas'] as int? ?? 0;
    final double totalAnuladas = (anulacionesResult.first['total_anuladas'] as num? ?? 0.0).toDouble();

    final divisasResult = await db.rawQuery('''
      SELECT COALESCE(SUM(monto_usd), 0) as total_usd_pagado
      FROM factura
      WHERE sesion_fiscal_id = ? AND estado != 'anulado'
    ''', [sesionId]);
    final double totalPagosDivisas = (divisasResult.first['total_usd_pagado'] as num? ?? 0.0).toDouble();

    final impuestosResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN tasa_iva = 16.0 THEN monto_base_imponible ELSE 0 END), 0) as base_g,
        COALESCE(SUM(CASE WHEN tasa_iva = 16.0 THEN monto_iva ELSE 0 END), 0) as iva_g,
        COALESCE(SUM(CASE WHEN tasa_iva = 8.0 THEN monto_base_imponible ELSE 0 END), 0) as base_a,
        COALESCE(SUM(CASE WHEN tasa_iva = 8.0 THEN monto_iva ELSE 0 END), 0) as iva_a,
        COALESCE(SUM(CASE WHEN tasa_iva = 31.0 THEN monto_base_imponible ELSE 0 END), 0) as base_r,
        COALESCE(SUM(CASE WHEN tasa_iva = 31.0 THEN monto_iva ELSE 0 END), 0) as iva_r,
        COALESCE(SUM(monto_exento), 0) as exento
      FROM factura
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura' AND estado != 'anulado'
    ''', [sesionId]);

    final facturasEmitidas = facturas['cantidad_facturas'] as int? ?? 0;
    final String facturaInicial = facturas['factura_inicial'] as String? ?? '000000';
    final String facturaFinal = facturas['factura_final'] as String? ?? '000000';

    // Obtener última nota de crédito emitida en esta sesión
    final ultimaNcResult = await db.rawQuery('''
      SELECT MAX(numero_control) as ultima_nc
      FROM nota_credito
      WHERE factura_id IN (SELECT id FROM factura WHERE sesion_fiscal_id = ?)
    ''', [sesionId]);
    final String ultimaNc = ultimaNcResult.first['ultima_nc'] as String? ?? '00000000';

    final Map<String, dynamic> datosFiscales = {
      'cajero': usuarioNombre,
      'base_g': (impuestosResult.first['base_g'] as num? ?? 0.0).toDouble() * tasaUsd,
      'iva_g': (impuestosResult.first['iva_g'] as num? ?? 0.0).toDouble() * tasaUsd,
      'base_a': (impuestosResult.first['base_a'] as num? ?? 0.0).toDouble() * tasaUsd,
      'iva_a': (impuestosResult.first['iva_a'] as num? ?? 0.0).toDouble() * tasaUsd,
      'base_r': (impuestosResult.first['base_r'] as num? ?? 0.0).toDouble() * tasaUsd,
      'iva_r': (impuestosResult.first['iva_r'] as num? ?? 0.0).toDouble() * tasaUsd,
      'exento': (impuestosResult.first['exento'] as num? ?? 0.0).toDouble() * tasaUsd,
      'total_ventas': (facturas['total_ventas'] as num? ?? 0.0).toDouble() * tasaUsd,
      'devoluciones': totalNc * tasaUsd,
      'anulaciones': totalAnuladas * tasaUsd,
      'pagos_divisas': totalPagosDivisas, // Ya está expresado en dólares (USD)
      'total_comprobantes': facturasEmitidas + cantidadNc + cantidadAnuladas,
      'primer_ticket': facturaInicial.replaceAll('FAC-', ''),
      'ultimo_ticket': facturaFinal.replaceAll('FAC-', ''),
      // Contadores de auditoría SENIAT
      'cantidad_facturas': facturasEmitidas,
      'cantidad_nc': cantidadNc,
      'ultima_nc': ultimaNc.replaceAll('NC-', ''),
      'cantidad_ndb': 0, // Notas de débito no implementadas aún
      'ultima_ndb': '00000000',
    };

    try {
      final resumen = await obtenerResumenFiscalSesion(sesionId);
      datosFiscales['resumen_fiscal'] = resumen;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo resumen fiscal para arqueo: $e');
    }

    // Imprimir Reporte Cierre X
    await ThermalPrinterService.printArqueoCaja(
      arqueo.copyWithSyncFields(serverId: arqueoId.toString()),
      tasaCambio: tasaUsd,
      datosFiscales: datosFiscales,
    );

    return arqueo.copyWithSyncFields(serverId: arqueoId.toString());
  }

  /// Consolida los totales, genera la firma, registra reporte Z, cierra sesión e imprime.
  Future<ReporteCierre> cerrarSesion(
      int usuarioId, String usuarioNombre) async {
    final sesion = await obtenerSesionActual();
    if (sesion == null) {
      throw Exception('No hay ninguna sesión fiscal activa para cerrar');
    }

    final db = await DbHelper.instance.database;
    final ahora = DateTime.now();

    // 1. CONSOLIDACIÓN DE TRANSACCIONES

    // Facturas
    final facturasResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_facturas,
        COALESCE(SUM(total), 0) as total_ventas,
        COALESCE(SUM(CASE WHEN metodo_pago = 'cash' THEN total ELSE 0 END), 0) as efectivo,
        COALESCE(SUM(CASE WHEN metodo_pago = 'card' THEN total ELSE 0 END), 0) as tarjeta,
        COALESCE(SUM(CASE WHEN metodo_pago = 'pago_movil' THEN total ELSE 0 END), 0) as pago_movil,
        COALESCE(SUM(CASE WHEN metodo_pago NOT IN ('cash', 'card', 'pago_movil') THEN total ELSE 0 END), 0) as otros,
        COALESCE(SUM(monto_base_imponible), 0) as base_imponible,
        COALESCE(SUM(monto_iva), 0) as iva,
        COALESCE(SUM(monto_exento), 0) as exento,
        MIN(numero_control) as factura_inicial,
        MAX(numero_control) as factura_final
      FROM factura
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura' AND estado = 'activo'
    ''', [sesion.id]);

    final facturasData = facturasResult.first;
    final int cantidadFacturas = facturasData['cantidad_facturas'] as int? ?? 0;
    final double totalVentas =
        (facturasData['total_ventas'] as num? ?? 0.0).toDouble();
    final double totalEfectivo =
        (facturasData['efectivo'] as num? ?? 0.0).toDouble();
    final double totalTarjeta =
        (facturasData['tarjeta'] as num? ?? 0.0).toDouble();
    final double totalPagoMovil =
        (facturasData['pago_movil'] as num? ?? 0.0).toDouble();
    final double totalOtros = (facturasData['otros'] as num? ?? 0.0).toDouble();
    final double baseImponible =
        (facturasData['base_imponible'] as num? ?? 0.0).toDouble();
    final double totalIvaFacturas =
        (facturasData['iva'] as num? ?? 0.0).toDouble();
    final double totalExentoFacturas =
        (facturasData['exento'] as num? ?? 0.0).toDouble();
    final String? facturaInicial = facturasData['factura_inicial'] as String?;
    final String? facturaFinal = facturasData['factura_final'] as String?;

    // Notas de Crédito procesadas
    final ncResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_nc,
        COALESCE(SUM(monto_total), 0) as total_nc,
        COALESCE(SUM(iva), 0) as iva_nc,
        MIN(numero_control) as nc_inicial,
        MAX(numero_control) as nc_final
      FROM nota_credito
      WHERE factura_id IN (SELECT id FROM factura WHERE sesion_fiscal_id = ?) AND estado = 'procesada'
    ''', [sesion.id]);

    final ncData = ncResult.first;
    final int cantidadNc = ncData['cantidad_nc'] as int? ?? 0;
    final double totalNc = (ncData['total_nc'] as num? ?? 0.0).toDouble();
    final double totalIvaNc = (ncData['iva_nc'] as num? ?? 0.0).toDouble();
    final String? ncInicial = ncData['nc_inicial'] as String?;
    final String? ncFinal = ncData['nc_final'] as String?;

    // Totales Consolidados
    final double totalNeto = totalVentas - totalNc;
    final double ivaTotal = totalIvaFacturas - totalIvaNc;
    final double exento =
        totalExentoFacturas; // Las NC no suelen tener productos exentos en esta lógica, pero se asume neto

    // 2. GENERAR REPORTE DE CIERRE (REPORTE Z) ESTÁNDAR DE 6 DÍGITOS
    final resultCountRep = await db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_cierre');
    final countRep = Sqflite.firstIntValue(resultCountRep) ?? 0;
    final secuenciaRep = (countRep + 1).toString().padLeft(6, '0');
    final numeroReporte = secuenciaRep;

    // Generar Hash de Integridad (SHA-256)
    final String rawStringToHash =
        '$numeroReporte|$totalVentas|$totalNeto|${ahora.toIso8601String()}';
    final String hashIntegridad =
        sha256.convert(utf8.encode(rawStringToHash)).toString();

    final nuevoReporte = ReporteCierre(
      sesionFiscalId: sesion.id!,
      numeroReporte: numeroReporte,
      fechaReporte: ahora,
      facturasEmitidas: cantidadFacturas,
      notasCreditoEmitidas: cantidadNc,
      totalVentas: totalVentas,
      totalNotasCredito: totalNc,
      totalNeto: totalNeto,
      iva16: ivaTotal, // Se asume IVA General 16%
      iva8: 0.0,
      ivaTotal: ivaTotal,
      exento: exento,
      desgloseEfectivo: totalEfectivo,
      desgloseTarjeta: totalTarjeta,
      desglosePagoMovil: totalPagoMovil,
      desgloseOtros: totalOtros,
      rifComercio: AppConfig.rifComercio,
      nombreComercio: AppConfig.nombreComercio,
      direccionComercio: AppConfig.direccionComercio,
      hashIntegridad: hashIntegridad,
      createdAt: ahora,
      updatedAt: ahora,
      lastModified: ahora,
      syncStatus: SyncStatus.pendingUpload,
    );

    final reporteId =
        await ReportesCierreRepository.instance.insertLocal(nuevoReporte);

    // 3. ACTUALIZAR SESIÓN FISCAL A CERRADA
    final sesionActualizada = SesionFiscal(
      id: sesion.id,
      numeroSesion: sesion.numeroSesion,
      fechaApertura: sesion.fechaApertura,
      fechaCierre: ahora,
      usuarioAperturaId: sesion.usuarioAperturaId,
      usuarioAperturaNombre: sesion.usuarioAperturaNombre,
      usuarioCierreId: usuarioId,
      usuarioCierreNombre: usuarioNombre,
      estado: EstadoSesionFiscal.cerrada,
      totalVentas: totalVentas,
      totalNotasCredito: totalNc,
      totalEfectivo: totalEfectivo,
      totalTarjeta: totalTarjeta,
      totalPagoMovil: totalPagoMovil,
      totalOtrosMetodos: totalOtros,
      totalBaseImponible: baseImponible,
      totalIva: totalIvaFacturas,
      totalExento: totalExentoFacturas,
      totalGeneral: totalVentas,
      cantidadFacturas: cantidadFacturas,
      cantidadNotasCredito: cantidadNc,
      cantidadTransacciones: cantidadFacturas + cantidadNc,
      facturaInicial: facturaInicial,
      facturaFinal: facturaFinal,
      ncInicial: ncInicial,
      ncFinal: ncFinal,
      arqueoRealizado: sesion.arqueoRealizado,
      arqueoId: sesion.arqueoId,
      fondoCajaInicial: sesion.fondoCajaInicial,
      createdAt: sesion.createdAt,
      updatedAt: ahora,
      serverId: sesion.serverId,
      lastModified: ahora,
      syncStatus: SyncStatus.pendingUpdate,
    );

    await SesionesFiscalesRepository.instance.updateLocal(sesionActualizada);

    // 4. MARCAR FACTURAS ASOCIADAS COMO CERRADAS
    await db.update(
      'factura',
      {'estado': 'cerrado'},
      where: 'sesion_fiscal_id = ? AND estado = ?',
      whereArgs: [sesion.id, 'activo'],
    );

    // Disparar sincronización de cierre en background
    SyncTrigger.instance.onReporteCierreCreado(reporteId).catchError(
          (e) => debugPrint('⚠️ Sync reporte_cierre falló: $e'),
        );
    SyncTrigger.instance.onSesionFiscalActualizada(sesion.id!).catchError(
          (e) => debugPrint('⚠️ Sync sesion_fiscal_actualizada falló: $e'),
        );

    // 5. IMPRESIÓN OBLIGATORIA
    double tasaCambio = 36.50; // Fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      tasaCambio = prefs.getDouble('tasa_usd') ?? 36.50;
    } catch (_) {}

    final reporteConId = ReporteCierre(
      id: reporteId,
      sesionFiscalId: nuevoReporte.sesionFiscalId,
      numeroReporte: nuevoReporte.numeroReporte,
      fechaReporte: nuevoReporte.fechaReporte,
      facturasEmitidas: nuevoReporte.facturasEmitidas,
      notasCreditoEmitidas: nuevoReporte.notasCreditoEmitidas,
      totalVentas: nuevoReporte.totalVentas,
      totalNotasCredito: nuevoReporte.totalNotasCredito,
      totalNeto: nuevoReporte.totalNeto,
      iva16: nuevoReporte.iva16,
      iva8: nuevoReporte.iva8,
      ivaTotal: nuevoReporte.ivaTotal,
      exento: nuevoReporte.exento,
      desgloseEfectivo: nuevoReporte.desgloseEfectivo,
      desgloseTarjeta: nuevoReporte.desgloseTarjeta,
      desglosePagoMovil: nuevoReporte.desglosePagoMovil,
      desgloseOtros: nuevoReporte.desgloseOtros,
      rifComercio: nuevoReporte.rifComercio,
      nombreComercio: nuevoReporte.nombreComercio,
      direccionComercio: nuevoReporte.direccionComercio,
      hashIntegridad: nuevoReporte.hashIntegridad,
      createdAt: nuevoReporte.createdAt,
      updatedAt: nuevoReporte.updatedAt,
      lastModified: nuevoReporte.lastModified,
      syncStatus: nuevoReporte.syncStatus,
    );

    Map<String, dynamic>? resumenFiscal;
    try {
      resumenFiscal = await obtenerResumenFiscalSesion(sesion.id!);
    } catch (e) {
      debugPrint('⚠️ Error obteniendo resumen fiscal para cierre: $e');
    }

    await ThermalPrinterService.printReporteCierre(reporteConId,
        tasaCambio: tasaCambio, resumenFiscal: resumenFiscal);

    debugPrint('🔒 Sesión fiscal cerrada e impresa: ${sesion.numeroSesion}');
    return reporteConId;
  }

  Future<String> generarNumeroFactura() async {
    final db = await DbHelper.instance.database;

    // Generar número de factura numérico estándar de 6 dígitos: 000000
    final resultCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM factura');
    final count = Sqflite.firstIntValue(resultCount) ?? 0;
    final secuencia = (count + 1).toString().padLeft(6, '0');
    return secuencia;
  }

  Future<String> generarNumeroNotaCredito() async {
    final db = await DbHelper.instance.database;

    // Generar número de nota de crédito numérico estándar de 6 dígitos: 000000
    final resultCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM nota_credito');
    final count = Sqflite.firstIntValue(resultCount) ?? 0;
    final secuencia = (count + 1).toString().padLeft(6, '0');
    return secuencia;
  }

  /// Obtiene los totales de un día específico.
  Future<Map<String, dynamic>> obtenerResumenDiario(DateTime fecha) async {
    final db = await DbHelper.instance.database;
    final fechaStr = fecha.toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_facturas,
        COALESCE(SUM(total), 0) as total_ventas,
        COALESCE(SUM(base_imponible), 0) as base_imponible,
        COALESCE(SUM(monto_iva), 0) as total_iva,
        COALESCE(SUM(monto_exento), 0) as total_exento
      FROM factura
      WHERE fecha_creacion LIKE ? AND tipo_documento = 'Factura' AND estado != 'anulado'
    ''', ['$fechaStr%']);

    return result.first;
  }

  /// Calcula y retorna los totales fiscales para actualizar o visualizar una sesión.
  Future<Map<String, dynamic>> calcularTotalesSesion(int sesionId) async {
    final db = await DbHelper.instance.database;

    // Verificar cuántas facturas existen para esta sesión, independientemente del estado
    final totalEnSesion = await db.rawQuery(
        'SELECT COUNT(*) as count FROM factura WHERE sesion_fiscal_id = ?',
        [sesionId]);
    debugPrint(
        '📊 [DEBUG] Facturas encontradas para sesión $sesionId: ${Sqflite.firstIntValue(totalEnSesion)}');

    final facturas = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_facturas,
        COALESCE(SUM(total), 0) as total_ventas,
        COALESCE(SUM(CASE WHEN metodo_pago = 'cash' THEN total ELSE 0 END), 0) as efectivo,
        COALESCE(SUM(CASE WHEN metodo_pago = 'card' THEN total ELSE 0 END), 0) as tarjeta,
        COALESCE(SUM(CASE WHEN metodo_pago = 'pago_movil' THEN total ELSE 0 END), 0) as pago_movil,
        COALESCE(SUM(CASE WHEN metodo_pago NOT IN ('cash', 'card', 'pago_movil') THEN total ELSE 0 END), 0) as otros,
        COALESCE(SUM(monto_base_imponible), 0) as base_imponible,
        COALESCE(SUM(monto_iva), 0) as iva,
        COALESCE(SUM(monto_exento), 0) as exento,
        MIN(numero_control) as factura_inicial,
        MAX(numero_control) as factura_final
      FROM factura
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura'
    ''', [sesionId]);

    final ncs = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_nc,
        COALESCE(SUM(monto_total), 0) as total_nc,
        COALESCE(SUM(iva), 0) as iva_nc
      FROM nota_credito
      WHERE factura_id IN (SELECT id FROM factura WHERE sesion_fiscal_id = ?)
    ''', [sesionId]);

    debugPrint('📊 [DEBUG] Totales calculados: ${facturas.first}');

    return {
      'facturas': facturas.first,
      'notas_credito': ncs.first,
    };
  }

  /// Obtiene un resumen fiscal detallado para una sesión fiscal específica.
  /// Retorna un mapa con desgloses de facturas, notas de crédito, contadores acumulados, secuenciales e información del hardware.
  Future<Map<String, dynamic>> obtenerResumenFiscalSesion(int sesionId) async {
    final db = await DbHelper.instance.database;

    // --- CONTADORES ACUMULADOS HISTÓRICOS ---
    final contNoFiscalHistRes = await db.rawQuery('SELECT COUNT(*) as cant FROM arqueos_caja');
    final int contNoFiscalHist = Sqflite.firstIntValue(contNoFiscalHistRes) ?? 0;

    final contFactHistRes = await db.rawQuery("SELECT COUNT(*) as cant FROM factura WHERE tipo_documento = 'Factura' AND estado != 'anulado'");
    final int contFactHist = Sqflite.firstIntValue(contFactHistRes) ?? 0;

    final contNcHistRes = await db.rawQuery("SELECT COUNT(*) as cant FROM nota_credito WHERE estado = 'procesada'");
    final int contNcHist = Sqflite.firstIntValue(contNcHistRes) ?? 0;

    // --- CONTADORES DE LA SESIÓN ACTUAL ---
    final noFiscalSesionRes = await db.rawQuery('SELECT COUNT(*) as cant FROM arqueos_caja WHERE sesion_fiscal_id = ?', [sesionId]);
    final int noFiscalSesion = Sqflite.firstIntValue(noFiscalSesionRes) ?? 0;

    // --- FACTURAS DE VENTA ---
    final facturasResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cantidad_facturas,
        COALESCE(SUM(total), 0) as total_ventas,
        COALESCE(SUM(monto_base_imponible), 0) as base_imponible,
        COALESCE(SUM(monto_exento), 0) as exento,
        COALESCE(SUM(CASE WHEN tasa_iva = 16.0 THEN monto_base_imponible ELSE 0 END), 0) as base_16,
        COALESCE(SUM(CASE WHEN tasa_iva = 16.0 THEN monto_iva ELSE 0 END), 0) as iva_16,
        COALESCE(SUM(CASE WHEN tasa_iva = 8.0 THEN monto_base_imponible ELSE 0 END), 0) as base_8,
        COALESCE(SUM(CASE WHEN tasa_iva = 8.0 THEN monto_iva ELSE 0 END), 0) as iva_8,
        MIN(numero_control) as factura_inicial,
        MAX(numero_control) as factura_final
      FROM factura
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura' AND estado != 'anulado'
    ''', [sesionId]);
    
    final fData = facturasResult.first;

    // --- NOTAS DE CRÉDITO ---
    final ncResult = await db.rawQuery('''
      SELECT 
        nc.id,
        nc.tipo,
        nc.monto_total,
        nc.iva,
        nc.numero_control,
        f.tasa_iva,
        f.monto_exento as factura_exento
      FROM nota_credito nc
      INNER JOIN factura f ON nc.factura_id = f.id
      WHERE f.sesion_fiscal_id = ? AND nc.estado = 'procesada'
    ''', [sesionId]);

    double subtotalDevoluciones = 0.0;
    double baseImponible16Nc = 0.0;
    double baseImponible8Nc = 0.0;
    double baseExentaNc = 0.0;
    double iva16Nc = 0.0;
    double iva8Nc = 0.0;
    double totalNc = 0.0;
    int cantidadNc = ncResult.length;
    
    String? ncInicial;
    String? ncFinal;

    if (ncResult.isNotEmpty) {
      final ncsSorted = List<Map<String, dynamic>>.from(ncResult);
      ncsSorted.sort((a, b) => (a['numero_control'] as String).compareTo(b['numero_control'] as String));
      ncInicial = ncsSorted.first['numero_control'] as String;
      ncFinal = ncsSorted.last['numero_control'] as String;

      for (var row in ncResult) {
        final tipo = row['tipo'] as String;
        final montoTotal = (row['monto_total'] as num).toDouble();
        final iva = (row['iva'] as num).toDouble();
        final tasaIva = (row['tasa_iva'] as num? ?? 16.0).toDouble();

        if (tipo == 'total') {
          final facturaExento = (row['factura_exento'] as num? ?? 0.0).toDouble();
          baseExentaNc += facturaExento;
          subtotalDevoluciones += montoTotal; // monto_total en NC total ya es la base imponible que incluye exento
          if (tasaIva == 16.0) {
            baseImponible16Nc += (montoTotal - facturaExento);
            iva16Nc += iva;
          } else if (tasaIva == 8.0) {
            baseImponible8Nc += (montoTotal - facturaExento);
            iva8Nc += iva;
          }
        } else {
          // parcial se asume siempre al 16% según la lógica de creación
          subtotalDevoluciones += montoTotal;
          baseImponible16Nc += montoTotal;
          iva16Nc += iva;
        }
      }
      totalNc = subtotalDevoluciones + iva16Nc + iva8Nc;
    }

    // --- CONTADORES ACUMULADOS DEL MES ---
    final sesionResult = await db.query('sesiones_fiscales', where: 'id = ?', whereArgs: [sesionId], limit: 1);
    final String fechaSesionStr = sesionResult.first['fecha_apertura'] as String;
    final String mesFiltro = fechaSesionStr.substring(0, 7); // 'YYYY-MM'

    final facturasMesResult = await db.rawQuery('''
      SELECT COUNT(*) as cant 
      FROM factura 
      WHERE fecha_creacion LIKE ? AND tipo_documento = 'Factura' AND estado != 'anulado'
    ''', ['$mesFiltro%']);
    final int facturasMes = Sqflite.firstIntValue(facturasMesResult) ?? 0;

    final ncMesResult = await db.rawQuery('''
      SELECT COUNT(*) as cant 
      FROM nota_credito 
      WHERE fecha_emision LIKE ? AND estado = 'procesada'
    ''', ['$mesFiltro%']);
    final int ncMes = Sqflite.firstIntValue(ncMesResult) ?? 0;

    // --- ÚLTIMOS DOCUMENTOS DE LA SESIÓN ---
    final ultFactResult = await db.rawQuery('''
      SELECT numero_control, fecha_creacion, total 
      FROM factura 
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura' AND estado != 'anulado'
      ORDER BY id DESC LIMIT 1
    ''', [sesionId]);
    Map<String, dynamic>? ultFactData = ultFactResult.isNotEmpty ? ultFactResult.first : null;

    final ultArqueoResult = await db.rawQuery('''
      SELECT numero_arqueo, fecha_arqueo 
      FROM arqueos_caja 
      WHERE sesion_fiscal_id = ? 
      ORDER BY id DESC LIMIT 1
    ''', [sesionId]);
    Map<String, dynamic>? ultArqueoData = ultArqueoResult.isNotEmpty ? ultArqueoResult.first : null;

    final ultZResult = await db.rawQuery('''
      SELECT numero_reporte, fecha_reporte 
      FROM reportes_cierre 
      ORDER BY id DESC LIMIT 1
    ''');
    Map<String, dynamic>? ultZData = ultZResult.isNotEmpty ? ultZResult.first : null;

    // --- ANULACIONES ---
    final anulacionesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cant,
        COALESCE(SUM(monto_base_imponible), 0) as base_anulada,
        COALESCE(SUM(monto_iva), 0) as iva_anulada,
        COALESCE(SUM(monto_exento), 0) as exento_anulada
      FROM factura 
      WHERE sesion_fiscal_id = ? AND tipo_documento = 'Factura' AND estado = 'anulado'
    ''', [sesionId]);
    final anulacionesData = anulacionesResult.first;

    // --- FORMAS DE PAGO CON CONTEO ---
    final formasPagoResult = await db.rawQuery('''
      SELECT metodo_pago, COUNT(*) as cant, COALESCE(SUM(total), 0) as total
      FROM factura
      WHERE sesion_fiscal_id = ? AND estado != 'anulado' AND tipo_documento = 'Factura'
      GROUP BY metodo_pago
    ''', [sesionId]);

    final Map<String, Map<String, dynamic>> desgloseFormasPago = {};
    for (var r in formasPagoResult) {
      desgloseFormasPago[r['metodo_pago'] as String] = {
        'cant': r['cant'] as int,
        'total': (r['total'] as num).toDouble(),
      };
    }

    return {
      // Contadores acumulados históricos
      'cont_no_fiscal_hist': contNoFiscalHist,
      'cont_fact_hist': contFactHist,
      'cont_nc_hist': contNcHist,
      
      // Contadores sesión actual
      'no_fiscal_sesion': noFiscalSesion,

      // Facturas
      'cant_facturas': fData['cantidad_facturas'] as int? ?? 0,
      'total_facturado': (fData['total_ventas'] as num? ?? 0.0).toDouble(),
      'base_16_facturas': (fData['base_16'] as num? ?? 0.0).toDouble(),
      'iva_16_facturas': (fData['iva_16'] as num? ?? 0.0).toDouble(),
      'base_8_facturas': (fData['base_8'] as num? ?? 0.0).toDouble(),
      'iva_8_facturas': (fData['iva_8'] as num? ?? 0.0).toDouble(),
      'exento_facturas': (fData['exento'] as num? ?? 0.0).toDouble(),
      'subtotal_ventas': (fData['base_imponible'] as num? ?? 0.0).toDouble() + (fData['exento'] as num? ?? 0.0).toDouble(),
      'base_imponible_facturas': (fData['base_imponible'] as num? ?? 0.0).toDouble() + (fData['exento'] as num? ?? 0.0).toDouble(),
      
      // NC
      'cant_nc': cantidadNc,
      'subtotal_devoluciones': subtotalDevoluciones,
      'base_imponible_nc': subtotalDevoluciones,
      'base_16_nc': baseImponible16Nc,
      'iva_16_nc': iva16Nc,
      'base_8_nc': baseImponible8Nc,
      'iva_8_nc': iva8Nc,
      'exento_nc': baseExentaNc,
      'total_nc': totalNc,

      // Totales Netos
      'total_ventas_netas': (fData['total_ventas'] as num? ?? 0.0).toDouble(),
      'total_nc_netas': totalNc,
      'total_general_neto': (fData['total_ventas'] as num? ?? 0.0).toDouble() - totalNc,

      // Contadores del día y mes
      'facturas_mes': facturasMes,
      'nc_mes': ncMes,
      'total_mes': facturasMes + ncMes,

      // Secuenciales
      'factura_inicial': fData['factura_inicial'] as String?,
      'factura_final': fData['factura_final'] as String?,
      'nc_inicial': ncInicial,
      'nc_final': ncFinal,

      // Últimos documentos
      'ult_fact': ultFactData,
      'ult_arqueo': ultArqueoData,
      'ult_z': ultZData,

      // Anulaciones
      'cant_anuladas': anulacionesData['cant'] as int? ?? 0,
      'base_anulada': (anulacionesData['base_anulada'] as num? ?? 0.0).toDouble(),
      'iva_anulada': (anulacionesData['iva_anulada'] as num? ?? 0.0).toDouble(),
      'exento_anulada': (anulacionesData['exento_anulada'] as num? ?? 0.0).toDouble(),

      // Desglose de formas de pago
      'formas_pago': desgloseFormasPago,
    };
  }
}

