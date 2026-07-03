import 'package:flutter_test/flutter_test.dart';
import 'package:pos_android/models/fiscal_models.dart';
import 'package:pos_android/sync/enums/sync_status.dart';

void main() {
  final ahora = DateTime.now();

  group('Módulo Fiscal - Modelos', () {
    test('SesionFiscal - Instanciación, toMap y fromMap', () {
      final sesion = SesionFiscal(
        id: 1,
        numeroSesion: 'SES-20260608-001',
        fechaApertura: ahora,
        usuarioAperturaId: 10,
        usuarioAperturaNombre: 'Juan Perez',
        estado: EstadoSesionFiscal.abierta,
        createdAt: ahora,
        updatedAt: ahora,
        lastModified: ahora,
        syncStatus: SyncStatus.pendingUpload,
      );

      expect(sesion.numeroSesion, 'SES-20260608-001');
      expect(sesion.isAbierta, true);

      final localMap = sesion.toLocalMap();
      expect(localMap['id'], 1);
      expect(localMap['numero_sesion'], 'SES-20260608-001');
      expect(localMap['estado'], 'ABIERTA');

      final deserializada = SesionFiscal.fromLocalMap(localMap);
      expect(deserializada.id, 1);
      expect(deserializada.numeroSesion, 'SES-20260608-001');
      expect(deserializada.usuarioAperturaNombre, 'Juan Perez');
      expect(deserializada.estado, EstadoSesionFiscal.abierta);
    });

    test('ReporteCierre - Instanciación, toMap y fromMap', () {
      final reporte = ReporteCierre(
        id: 2,
        sesionFiscalId: 1,
        numeroReporte: 'REP-Z-20260608-001',
        fechaReporte: ahora,
        facturasEmitidas: 5,
        notasCreditoEmitidas: 1,
        totalVentas: 150.0,
        totalNotasCredito: 25.0,
        totalNeto: 125.0,
        iva16: 20.0,
        iva8: 0.0,
        ivaTotal: 20.0,
        exento: 10.0,
        desgloseEfectivo: 50.0,
        desgloseTarjeta: 75.0,
        rifComercio: 'J-12345678-9',
        nombreComercio: 'TIENDA RETAIL C.A.',
        direccionComercio: 'CARACAS VENEZUELA',
        hashIntegridad: 'hash_test_123',
        createdAt: ahora,
        updatedAt: ahora,
        lastModified: ahora,
        syncStatus: SyncStatus.pendingUpload,
      );

      expect(reporte.numeroReporte, 'REP-Z-20260608-001');
      expect(reporte.totalNeto, 125.0);

      final localMap = reporte.toLocalMap();
      expect(localMap['id'], 2);
      expect(localMap['numero_reporte'], 'REP-Z-20260608-001');
      expect(localMap['hash_integridad'], 'hash_test_123');

      final deserializada = ReporteCierre.fromLocalMap(localMap);
      expect(deserializada.id, 2);
      expect(deserializada.sesionFiscalId, 1);
      expect(deserializada.totalNeto, 125.0);
    });

    test('ArqueoCaja - Validación de totales y cuadre', () {
      const conteo = ConteoEfectivo(
        efectivoUsd: 145.0,
      ); // Total: 145 USD

      expect(conteo.totalUsd, 145.0);

      final arqueo = ArqueoCaja(
        id: 1,
        sesionFiscalId: 1,
        numeroArqueo: 'ARQ-20260608-001',
        fechaArqueo: ahora,
        usuarioArqueoId: 10,
        usuarioArqueoNombre: 'Juan Perez',
        conteo: conteo,
        totalEfectivoDeclarado: 145.0,
        totalTarjetaDeclarado: 500.0,
        totalPagoMovilDeclarado: 200.0,
        totalOtrosDeclarado: 0.0,
        totalEfectivoSistema: 145.0,
        totalTarjetaSistema: 500.0,
        totalPagoMovilSistema: 200.0,
        totalOtrosSistema: 0.0,
        diferenciaEfectivo: 0.0,
        diferenciaTarjeta: 0.0,
        diferenciaPagoMovil: 0.0,
        diferenciaTotal: 0.0,
        cuadrado: true,
        createdAt: ahora,
        updatedAt: ahora,
        lastModified: ahora,
        syncStatus: SyncStatus.pendingUpload,
      );

      expect(arqueo.estaCuadrado, true);
      expect(arqueo.totalDeclarado, 845.0);
    });
  });
}
