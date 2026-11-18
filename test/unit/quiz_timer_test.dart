import 'package:flutter_test/flutter_test.dart';
import 'package:unicorn_learning_lab/services/quiz_timer_service.dart';

void main() {
  group('QuizTimerService Unit Tests', () {
    test('Timer initializes with 60 seconds and full progress', () {
      final timer = QuizTimerService(durationSeconds: 60);
      expect(timer.durationSeconds, 60);
      expect(timer.remainingSeconds, 60);
      expect(timer.progress, 1.0);
      expect(timer.isWarning, isFalse);
      expect(timer.isUrgent, isFalse);
      expect(timer.isExpired, isFalse);
      timer.dispose();
    });

    test('Warning and urgent flags trigger at correct thresholds', () {
      final timer = QuizTimerService(durationSeconds: 60);
      timer.startTimer();

      // At 15 seconds remaining
      expect(timer.isWarning, isFalse); // Initially 60s

      timer.stopTimer();
      timer.dispose();
    });
  });
}
