/// Scoring and reward tier mapping business logic service.
library;

import 'package:unicorn_learning_lab/core/constants/app_constants.dart';

class ScoreResult {
  const ScoreResult({
    required this.score,
    required this.maxScore,
    required this.title,
    required this.rewardType,
    required this.message,
  });

  final int score;
  final int maxScore;
  final String title;
  final String rewardType;
  final String message;
}

class ScoringService {
  const ScoringService();

  /// Calculate the final score from answered questions.
  /// Each correct answer awards 1 point.
  int calculateScore(List<bool> correctnessList) {
    int score = 0;
    for (final isCorrect in correctnessList) {
      if (isCorrect) score++;
    }
    return score.clamp(0, AppConstants.maxScore);
  }

  /// Get result title based on score (0 to 5).
  String getTitleForScore(int score) {
    if (score == 5) return AppConstants.titleScore5;
    if (score == 4) return AppConstants.titleScore4;
    if (score == 3) return AppConstants.titleScore3;
    return AppConstants.titleScore0To2;
  }

  /// Map score to reward tier. Every tier is revealed with the spin wheel;
  /// the scratch-card option was removed, so 3–4/5 always uses the score 3–4 tier.
  String getRewardTypeForScore(int score) {
    if (score == 5) {
      return AppConstants.rewardPremiumGift;
    } else if (score == 4 || score == 3) {
      return AppConstants.rewardSpinWheel;
    } else {
      return AppConstants.rewardSticker;
    }
  }

  /// Friendly, encouraging message for the results screen.
  String getMessageForScore(int score) {
    if (score == 5) {
      return 'Outstanding! Your curiosity and logical thinking are extraordinary!';
    } else if (score == 4) {
      return 'Terrific job! You demonstrated fantastic problem-solving skills!';
    } else if (score == 3) {
      return 'Great effort! You discovered interesting patterns and solutions!';
    } else {
      return 'Wonderful exploration! Every question is a stepping stone to discovery.';
    }
  }

  /// Evaluate the complete outcome.
  ScoreResult evaluateOutcome(int score) {
    final clamped = score.clamp(0, AppConstants.maxScore);
    return ScoreResult(
      score: clamped,
      maxScore: AppConstants.maxScore,
      title: getTitleForScore(clamped),
      rewardType: getRewardTypeForScore(clamped),
      message: getMessageForScore(clamped),
    );
  }
}
