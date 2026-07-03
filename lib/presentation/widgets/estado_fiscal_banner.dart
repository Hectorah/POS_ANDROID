import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/fiscal_provider.dart';
import '../../core/constants/app_colors.dart';

class EstadoFiscalBanner extends StatelessWidget {
  const EstadoFiscalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<FiscalProvider>(
      builder: (context, fiscalProvider, child) {
        if (fiscalProvider.isLoading) {
          return const LinearProgressIndicator(
            minHeight: 4,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          );
        }

        final sesion = fiscalProvider.sesionActual;
        final bool isOpen = fiscalProvider.haySesionAbierta;

        final Color bgColor = isOpen 
            ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
            : (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50);
            
        final Color borderColor = isOpen ? Colors.green : Colors.red;
        final Color textColor = isOpen 
            ? (isDark ? Colors.green.shade100 : Colors.green.shade800)
            : (isDark ? Colors.red.shade100 : Colors.red.shade800);
            
        final IconData icon = isOpen ? Icons.check_circle_outline : Icons.warning_amber_rounded;
        
        final String text = isOpen
            ? 'SESIÓN FISCAL ABIERTA - Desde: ${DateFormat('dd/MM/yyyy HH:mm').format(sesion!.fechaApertura)}'
            : 'SESIÓN FISCAL CERRADA - Se requiere apertura para facturar';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: borderColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isOpen)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/apertura-fiscal');
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Abrir'),
                  style: TextButton.styleFrom(
                    foregroundColor: borderColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
