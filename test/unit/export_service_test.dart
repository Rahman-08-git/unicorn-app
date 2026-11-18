import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/services/export_service.dart';

void main() {
  group('ExportService Unit Tests', () {
    test('RFC 4180 CSV escaping for commas, quotes, and newlines', () {
      expect(ExportService.escapeCsvValue('SimpleText'), 'SimpleText');
      expect(ExportService.escapeCsvValue('Hello, World'), '"Hello, World"');
      expect(ExportService.escapeCsvValue('Quote "Test"'), '"Quote ""Test"""');
      expect(ExportService.escapeCsvValue('Multi\nLine'), '"Multi\nLine"');
    });

    test('CSV row formatting produces valid CSV output', () {
      final rows = [
        ['participant_id', 'audience', 'score'],
        ['p_001', 'PARENT', 5],
        ['p_002', 'STUDENT, CLASS 5', 4],
      ];

      final csv = ExportService.formatCsv(rows);
      expect(csv, contains('participant_id,audience,score'));
      expect(csv, contains('p_001,PARENT,5'));
      expect(csv, contains('"STUDENT, CLASS 5"'));
    });
  });
}
