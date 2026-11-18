/// Quiz attempt model.
library;

import 'package:uuid/uuid.dart';

enum AttemptStatus {
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  abandoned('ABANDONED');

  const AttemptStatus(this.code);
  final String code;

  static AttemptStatus fromCode(String code) {
    return AttemptStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AttemptStatus.inProgress,
    );
  }
}

class Attempt {
  Attempt({
    String? id,
    required this.participantId,
    required this.campaignId,
    required this.tabletId,
    required this.audienceCategory,
    this.classLevel,
    DateTime? startedAt,
    this.completedAt,
    this.score = 0,
    this.totalQuestions = 5,
    this.questionBankVersion = '1.0',
    this.status = AttemptStatus.inProgress,
    this.assignedRewardId,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now();

  final String id;
  final String participantId;
  final String campaignId;
  final String tabletId;
  final String audienceCategory;
  final String? classLevel;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int score;
  final int totalQuestions;
  final String questionBankVersion;
  final AttemptStatus status;
  final String? assignedRewardId;

  factory Attempt.fromMap(Map<String, dynamic> map) {
    return Attempt(
      id: map['id'] as String,
      participantId: map['participant_id'] as String,
      campaignId: map['campaign_id'] as String? ?? '',
      tabletId: map['tablet_id'] as String? ?? '',
      audienceCategory: map['audience_category'] as String,
      classLevel: map['class_level'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      score: map['score'] as int? ?? 0,
      totalQuestions: map['total_questions'] as int? ?? 5,
      questionBankVersion: map['question_bank_version'] as String? ?? '1.0',
      status: AttemptStatus.fromCode(map['status'] as String? ?? 'IN_PROGRESS'),
      assignedRewardId: map['assigned_reward_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant_id': participantId,
      'campaign_id': campaignId,
      'tablet_id': tabletId,
      'audience_category': audienceCategory,
      'class_level': classLevel,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'score': score,
      'total_questions': totalQuestions,
      'question_bank_version': questionBankVersion,
      'status': status.code,
      'assigned_reward_id': assignedRewardId,
    };
  }
}
