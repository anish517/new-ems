import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:ems_app/shared/widgets/nepali_date_picker.dart';

void main() {
  group('Nepali Date Helper Parsing & Formatting', () {
    test('parseNepaliDateString should correctly parse standard YYYY-MM-DD', () {
      final dt = parseNepaliDateString('2083-05-08');
      expect(dt, isNotNull);
      expect(dt!.year, equals(2083));
      expect(dt.month, equals(5));
      expect(dt.day, equals(8));
    });

    test('parseNepaliDateString should parse slash and dot separators', () {
      final dtSlash = parseNepaliDateString('2055/01/15');
      expect(dtSlash, isNotNull);
      expect(dtSlash!.year, equals(2055));
      expect(dtSlash.month, equals(1));
      expect(dtSlash.day, equals(15));

      final dtDot = parseNepaliDateString('2080.12.30');
      expect(dtDot, isNotNull);
      expect(dtDot!.year, equals(2080));
      expect(dtDot.month, equals(12));
      expect(dtDot.day, equals(30));
    });

    test('parseNepaliDateString should return null for invalid strings', () {
      expect(parseNepaliDateString(null), isNull);
      expect(parseNepaliDateString(''), isNull);
      expect(parseNepaliDateString('invalid-date'), isNull);
      expect(parseNepaliDateString('2083-15-40'), isNull);
      expect(parseNepaliDateString('2083-02-35'), isNull);
    });

    test('formatNepaliDate should format to YYYY-MM-DD', () {
      final dt = NepaliDateTime(2083, 5, 8);
      expect(formatNepaliDate(dt), equals('2083-05-08'));

      final dt2 = NepaliDateTime(2055, 1, 1);
      expect(formatNepaliDate(dt2), equals('2055-01-01'));
    });
  });

  group('NepaliDateFormField Widget Tests', () {
    testWidgets('Renders label and accepts manual keyboard typing', (tester) async {
      final ctrl = TextEditingController(text: '2083-05-08');
      String changedVal = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: NepaliDateFormField(
                controller: ctrl,
                labelText: 'Date of Birth (B.S.) *',
                isRequired: true,
                onChanged: (v) => changedVal = v,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Date of Birth (B.S.) *'), findsOneWidget);
      expect(find.text('2083-05-08'), findsOneWidget);

      // Manually type a new date
      await tester.enterText(find.byType(TextFormField), '2055-01-01');
      await tester.pump();

      expect(ctrl.text, equals('2055-01-01'));
      expect(changedVal, equals('2055-01-01'));
    });

    testWidgets('Opens NepaliDatePickerDialog on suffix icon tap and shows Select Date button', (tester) async {
      final ctrl = TextEditingController(text: '2083-05-08');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NepaliDateFormField(
              controller: ctrl,
              labelText: 'Planned Start Date',
            ),
          ),
        ),
      );

      // Tap the calendar icon
      await tester.tap(find.byTooltip('Open Nepali Calendar'));
      await tester.pumpAndSettle();

      // Verify Dialog opened
      expect(find.byType(NepaliDatePickerDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.textContaining('Selected: 2083-05-08 B.S.'), findsOneWidget);

      // Tap Select Date
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      // Verify Dialog is closed
      expect(find.byType(NepaliDatePickerDialog), findsNothing);
      expect(ctrl.text, equals('2083-05-08'));
    });
  });

  group('NepaliDatePickerDialog Widget Tests', () {
    testWidgets('Allows selecting a day and confirming selection', (tester) async {
      NepaliDateTime? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await showNepaliDatePickerDialog(
                    context: ctx,
                    title: 'Select Notice Date',
                    initial: NepaliDateTime(2083, 5, 8),
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Notice Date'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.textContaining('Selected: 2083-05-08 B.S.'), findsOneWidget);

      // Tap Select Date button to confirm initial date
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!.day, equals(8));
      expect(selectedResult!.month, equals(5));
      expect(selectedResult!.year, equals(2083));
    });
  });
}
