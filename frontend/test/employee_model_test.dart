import 'package:flutter_test/flutter_test.dart';

// Simulating the extension method often used in Flutter to display enums
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String formatEnum() {
    return split('_').map((word) => word.capitalize()).join(' ');
  }
}

void main() {
  group('Employee Model Parsing Logic', () {
    test('Should parse full_time to Full Time correctly', () {
      final backendJson = {
        'employee_type': 'full_time',
        'marital_status': 'single',
      };

      final empTypeStr = backendJson['employee_type'] as String;
      final maritalStatusStr = backendJson['marital_status'] as String;

      expect(empTypeStr.formatEnum(), 'Full Time');
      expect(maritalStatusStr.formatEnum(), 'Single');
    });
    
    test('Should parse part_time to Part Time correctly', () {
      final backendJson = {
        'employee_type': 'part_time',
        'marital_status': 'married',
      };

      expect((backendJson['employee_type'] as String).formatEnum(), 'Part Time');
      expect((backendJson['marital_status'] as String).formatEnum(), 'Married');
    });
  });
}
