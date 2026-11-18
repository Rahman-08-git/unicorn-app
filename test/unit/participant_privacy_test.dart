import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';

void main() {
  group('Participant Privacy Unit Tests', () {
    test('Phone masking hides all digits except the last 4', () {
      final p1 = Participant(
        audienceCategory: AudienceCategory.parent,
        phoneNumber: '+919876543210',
      );
      expect(p1.maskedPhone, '********3210');

      final p2 = Participant(
        audienceCategory: AudienceCategory.student,
        phoneNumber: null,
      );
      expect(p2.maskedPhone, 'N/A');
    });

    test('Students do not require phone number or name', () {
      final student = Participant(
        audienceCategory: AudienceCategory.student,
        classLevel: 'CLASS_10',
      );
      expect(student.phoneNumber, isNull);
      expect(student.name, isNull);
      expect(student.classLevel, 'CLASS_10');
      expect(student.audienceCategory, AudienceCategory.student);
    });

    test('Parent and Guardian audience categories remain strictly distinct', () {
      final parent = Participant(
        audienceCategory: AudienceCategory.parent,
        phoneNumber: '+919876543210',
      );
      final guardian = Participant(
        audienceCategory: AudienceCategory.guardian,
        phoneNumber: '+919876543210',
      );

      expect(parent.audienceCategory.code, 'PARENT');
      expect(guardian.audienceCategory.code, 'GUARDIAN');
      expect(parent.audienceCategory, isNot(equals(guardian.audienceCategory)));
    });
  });
}
