import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
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

    test('Reward mapping for score 5: Premium Gift', () {
      expect(scoring.getRewardTypeForScore(5), AppConstants.rewardPremiumGift);
    });

    test('Reward mapping for score 3 and 4: spin wheel tier (scratch card removed)', () {
      expect(scoring.getRewardTypeForScore(4), AppConstants.rewardSpinWheel);
      expect(scoring.getRewardTypeForScore(3), AppConstants.rewardSpinWheel);
    });

    test('Reward mapping for score 0, 1, 2: Sticker', () {
      for (int s = 0; s <= 2; s++) {
        expect(scoring.getRewardTypeForScore(s), AppConstants.rewardSticker);
      }
    });

    test('Outcome evaluation produces complete result structure', () {
      final res = scoring.evaluateOutcome(5);
      expect(res.score, 5);
      expect(res.maxScore, 5);
      expect(res.title, AppConstants.titleScore5);
      expect(res.rewardType, AppConstants.rewardPremiumGift);
      expect(res.message, isNotEmpty);
    });
  });
}
