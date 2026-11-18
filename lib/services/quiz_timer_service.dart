/// Deadline-based accurate countdown timer service for the quiz.
///
/// Prevents drift from frame delays or app pausing by calculating
/// `deadline - now`.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

class QuizTimerService extends ChangeNotifier {
  QuizTimerService({this.durationSeconds = 60});

  final int durationSeconds;

  DateTime? _deadline;
  Timer? _ticker;
  bool _isRunning = false;
  bool _isExpired = false;
  int _remainingSeconds = 60;

  bool get isRunning => _isRunning;
  bool get isExpired => _isExpired;
  int get remainingSeconds => _remainingSeconds;

  /// Timer visual progress from 1.0 (full) to 0.0 (expired).
  double get progress {
    if (durationSeconds <= 0) return 0.0;
    return (_remainingSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  /// Whether time is running low (<= 15 seconds)
  bool get isWarning => _remainingSeconds <= 15 && _remainingSeconds > 5;

  /// Whether time is critically low (<= 5 seconds)
  bool get isUrgent => _remainingSeconds <= 5 && _remainingSeconds > 0;

  VoidCallback? onTimeout;

  /// Start or restart timer for a new question.
  void startTimer({VoidCallback? timeoutCallback}) {
    stopTimer();
    onTimeout = timeoutCallback;
    _isExpired = false;
    _remainingSeconds = durationSeconds;
    _deadline = DateTime.now().add(Duration(seconds: durationSeconds));
    _isRunning = true;
    notifyListeners();

    // Periodic ticker to recalculate monotonic remaining time
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isRunning || _deadline == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final difference = _deadline!.difference(now);
      final remaining = (difference.inMilliseconds / 1000).ceil();

      if (remaining <= 0) {
        _remainingSeconds = 0;
        _isExpired = true;
        _isRunning = false;
        timer.cancel();
        notifyListeners();
        onTimeout?.call();
      } else {
        if (_remainingSeconds != remaining) {
          _remainingSeconds = remaining;
          notifyListeners();
        }
      }
    });
  }

  /// Stop and cancel active timer (e.g. when participant answers).
  void stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
  }

  /// Check status upon app resume / foregrounding.
  void handleAppResume() {
    if (!_isRunning || _deadline == null) return;
    final now = DateTime.now();
    if (now.isAfter(_deadline!)) {
      _remainingSeconds = 0;
      _isExpired = true;
      _isRunning = false;
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      onTimeout?.call();
    } else {
      _remainingSeconds = (_deadline!.difference(now).inMilliseconds / 1000).ceil();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
