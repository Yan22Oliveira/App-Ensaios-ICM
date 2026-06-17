import 'package:flutter/services.dart';

class BrPhoneFormatter extends TextInputFormatter {
  static String onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String format(String input) {
    final d = onlyDigits(input).substring(0, onlyDigits(input).length.clamp(0, 11));
    if (d.isEmpty) return '';

    if (d.length <= 2) {
      return '(${d.padRight(2)})';
    } else if (d.length <= 6) { // (XX) XXXX
      final dd = d;
      return '(${dd.substring(0,2)}) ${dd.substring(2)}';
    } else if (d.length <= 10) { // (XX) XXXX-XXXX
      final dd = d;
      return '(${dd.substring(0,2)}) ${dd.substring(2,6)}-${dd.substring(6)}';
    } else { // 11 -> (XX) XXXXX-XXXX
      final dd = d;
      return '(${dd.substring(0,2)}) ${dd.substring(2,7)}-${dd.substring(7)}';
    }
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = format(newValue.text);
    // Mantém o cursor no fim de forma natural
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}