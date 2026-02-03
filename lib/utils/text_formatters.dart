import 'package:flutter/services.dart';

/// Text input formatter that converts text to Title Case
class TitleCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.isEmpty) {
      return newValue;
    }
    
    // Convert to title case
    final titleCase = text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    
    return TextEditingValue(
      text: titleCase,
      selection: newValue.selection,
    );
  }
}
