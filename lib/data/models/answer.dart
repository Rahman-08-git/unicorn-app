/// Answer record model for tracking question outcomes.
library;

import 'package:uuid/uuid.dart';

class Answer {
  Answer({
    String? id,
    required this.attemptId,
    required this.questionId,
    this.selectedAnswerId,
    required this.correctAnswerId,
    required this.isCorrect,
    this.isTimeout = false,
    this.timeTakenSeconds = 0,
    required this.questionSequence,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedAnswerId;
  final String correctAnswerId;
  final bool isCorrect;
  final bool isTimeout;
  final int timeTakenSeconds;
  final int questionSequence;

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['id'] as String,
      attemptId: map['attempt_id'] as String,
      questionId: map['question_id'] as String,
      selectedAnswerId: map['selected_answer_id'] as String?,
      correctAnswerId: map['correct_answer_id'] as String,
      isCorrect: (map['is_correct'] as int? ?? 0) == 1,
      isTimeout: (map['is_timeout'] as int? ?? 0) == 1,
      timeTakenSeconds: map['time_taken_seconds'] as int? ?? 0,
      questionSequence: map['question_sequence'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attempt_id': attemptId,
      'question_id': questionId,
      'selected_answer_id': selectedAnswerId,
      'correct_answer_id': correctAnswerId,
      'is_correct': isCorrect ? 1 : 0,
      'is_timeout': isTimeout ? 1 : 0,
      'time_taken_seconds': timeTakenSeconds,
      'question_sequence': questionSequence,
    };
  }
}
