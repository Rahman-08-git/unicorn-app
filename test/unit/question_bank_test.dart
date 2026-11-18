import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/data/question_banks/default_questions.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';

void main() {
  group('QuestionBankService Unit Tests', () {
    late QuestionBankService qService;

    setUp(() {
      qService = QuestionBankService();
    });

    test('All 17 audience categories exist and have at least 5 active valid questions', () {
      final expectedCategories = [
        'PARENT',
        'GUARDIAN',
        'PRE_PRIMARY',
        'CLASS_1',
        'CLASS_2',
        'CLASS_3',
        'CLASS_4',
        'CLASS_5',
        'CLASS_6',
        'CLASS_7',
        'CLASS_8',
        'CLASS_9',
        'CLASS_10',
        'CLASS_11',
        'CLASS_12',
        'COLLEGE',
        'DEMO',
      ];

      for (final cat in expectedCategories) {
        final validation = qService.validateAudienceBank(cat);
        expect(validation.isValid, isTrue, reason: 'Category $cat should be valid');
        expect(validation.activeCount, greaterThanOrEqualTo(5),
            reason: 'Category $cat should have at least 5 questions');
      }
    });

    test('Every default question passes validity checks', () {
      for (final q in DefaultQuestions.allQuestions) {
        expect(q.isValid(), isTrue, reason: 'Question ${q.id} failed validity check');
        expect(q.options.length, 4, reason: 'Question ${q.id} must have 4 options');
        final ids = q.options.map((o) => o.id).toSet();
        expect(ids.contains(q.correctAnswerId), isTrue,
            reason: 'Question ${q.id} correctAnswerId not found in options');
      }
    });

    test('selectQuestionsForAttempt selects exactly 5 questions and preserves correctAnswerId', () {
      final questions = qService.selectQuestionsForAttempt('CLASS_5', count: 5);
      expect(questions.length, 5);

      for (final q in questions) {
        expect(q.options.length, 4);
        // Correct answer option must still be present and identifiable
        final matchingOption = q.options.where((o) => o.id == q.correctAnswerId);
        expect(matchingOption.length, 1);
      }
    });

    test('Malformed question is correctly rejected', () {
      const malformed = Question(
        id: 'bad_01',
        audience: 'TEST',
        question: 'Is this valid?',
        options: [
          QuestionOption(id: 'A', text: 'Option A'),
          QuestionOption(id: 'B', text: 'Option B'),
        ], // Only 2 options instead of 4
        correctAnswerId: 'C',
      );
      expect(malformed.isValid(), isFalse);
    });

    test('JSON export and re-import round-trip works reliably', () {
      final exportedJson = qService.exportToJson();
      expect(exportedJson, isNotEmpty);

      final newService = QuestionBankService();
      final importSuccess = newService.importFromJson(exportedJson);
      expect(importSuccess, isTrue);
      expect(newService.totalQuestionCount, qService.totalQuestionCount);
    });
  });
}
