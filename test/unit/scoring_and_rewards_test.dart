import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/services/export_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';

void main() {
  group('ScoringService Unit Tests', () {
    const scoring = ScoringService();

    test('Score calculation for 0 through 5 correct answers', () {
      expect(scoring.calculateScore([]), 0);
      expect(scoring.calculateScore([false, false, false, false, false]), 0);
      expect(scoring.calculateScore([true, false, false, false, false]), 1);
      expect(scoring.calculateScore([true, true, false, false, false]), 2);
      expect(scoring.calculateScore([true, true, true, false, false]), 3);
      expect(scoring.calculateScore([true, true, true, true, false]), 4);
      expect(scoring.calculateScore([true, true, true, true, true]), 5);
      // Clamps to max 5
      expect(scoring.calculateScore([true, true, true, true, true, true]), 5);
    });

    test('Result titles for all scores', () {
      expect(scoring.getTitleForScore(5), AppConstants.titleScore5); // DISCOVERY CHAMPION
      expect(scoring.getTitleForScore(4), AppConstants.titleScore4); // PROBLEM SOLVER
      expect(scoring.getTitleForScore(3), AppConstants.titleScore3); // PATTERN EXPLORER
      expect(scoring.getTitleForScore(2), AppConstants.titleScore0To2); // CURIOUS EXPLORER
      expect(scoring.getTitleForScore(1), AppConstants.titleScore0To2);
      expect(scoring.getTitleForScore(0), AppConstants.titleScore0To2);
    });

    test('Default score → gift table: 0–1 Explorer, 2–3 Achiever, 4–5 Champion', () {
      expect(AppConstants.defaultScoreGifts, [
        AppConstants.giftExplorer,
        AppConstants.giftExplorer,
        AppConstants.giftAchiever,
        AppConstants.giftAchiever,
        AppConstants.giftChampion,
        AppConstants.giftChampion,
      ]);
      expect(AppConstants.defaultGiftNames[AppConstants.giftExplorer], 'UNICORN EXPLORER GIFT');
      expect(AppConstants.defaultGiftNames[AppConstants.giftAchiever], 'UNICORN ACHIEVER GIFT');
      expect(AppConstants.defaultGiftNames[AppConstants.giftChampion], 'UNICORN CHAMPION GIFT');
    });

    test('Stored score → gift table is decoded safely', () {
      expect(DatabaseHelper.decodeScoreGiftMap(null), AppConstants.defaultScoreGifts);
      expect(DatabaseHelper.decodeScoreGiftMap('not json'), AppConstants.defaultScoreGifts);
      final custom = DatabaseHelper.decodeScoreGiftMap('["A","B","C","D","E","F"]');
      expect(custom, ['A', 'B', 'C', 'D', 'E', 'F']);
      // Short or broken entries fall back to the default for that score.
      final partial = DatabaseHelper.decodeScoreGiftMap('["A", 3]');
      expect(partial[0], 'A');
      expect(partial[1], AppConstants.giftExplorer);
      expect(partial[5], AppConstants.giftChampion);
    });

    test('Export labels which scores win a gift', () {
      final map = ['X', 'X', 'Y', 'Z', 'Y', 'Y'];
      expect(ExportService.scoresLabel(map, 'X'), 'Score 0-1');
      expect(ExportService.scoresLabel(map, 'Y'), 'Score 2, 4-5');
      expect(ExportService.scoresLabel(map, 'Z'), 'Score 3');
      expect(ExportService.scoresLabel(map, 'Q'), 'Not given for any score');
    });

    test('Outcome evaluation produces complete result structure', () {
      final res = scoring.evaluateOutcome(5);
      expect(res.score, 5);
      expect(res.maxScore, 5);
      expect(res.title, AppConstants.titleScore5);
      expect(res.message, isNotEmpty);
    });
  });
}
