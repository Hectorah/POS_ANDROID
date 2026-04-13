import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
    locale: 'es_VE',
  );

  static final NumberFormat _bsFormat = NumberFormat.currency(
    symbol: 'Bs.',
    decimalDigits: 2,
    locale: 'es_VE',
  );

  static String formatUSD(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatBS(double amount, double exchangeRate) {
    final bsAmount = amount * exchangeRate;
    return _bsFormat.format(bsAmount);
  }

  static String formatNumber(double number) {
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    return formatter.format(number);
  }
}

// Formateador para campos de texto numéricos
class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  DecimalTextInputFormatter({this.decimalDigits = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Solo permite números y un punto decimal
    final regExp = RegExp(r'^\d*\.?\d{0,' + decimalDigits.toString() + r'}$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}

// Formateador para RIF (solo números)
class RifInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Solo permite números y guión
    final regExp = RegExp(r'^[0-9-]*$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}

// Formateador para teléfono
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Solo permite números, guión y paréntesis
    final regExp = RegExp(r'^[0-9\-\(\)\+\s]*$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}

// Formateador para convertir a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
