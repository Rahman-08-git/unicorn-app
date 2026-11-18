/// Reward model tracking participant reward outcomes and physical collection.
library;

import 'package:uuid/uuid.dart';

class Reward {
  Reward({
    String? id,
    required this.attemptId,
    required this.rewardType,
    required this.rewardIdentifier,
    DateTime? assignedAt,
    this.collectionStatus = 'ASSIGNED',
    this.collectedAt,
    this.operatorNote,
  })  : id = id ?? const Uuid().v4(),
        assignedAt = assignedAt ?? DateTime.now();

  final String id;
  final String attemptId;
  final String rewardType;
  final String rewardIdentifier;
  final DateTime assignedAt;
  final String collectionStatus;
  final DateTime? collectedAt;
  final String? operatorNote;

  bool get isCollected => collectionStatus == 'COLLECTED';

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'] as String,
      attemptId: map['attempt_id'] as String,
      rewardType: map['reward_type'] as String,
      rewardIdentifier: map['reward_identifier'] as String,
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      collectionStatus: map['collection_status'] as String? ?? 'ASSIGNED',
      collectedAt: map['collected_at'] != null
          ? DateTime.parse(map['collected_at'] as String)
          : null,
      operatorNote: map['operator_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attempt_id': attemptId,
      'reward_type': rewardType,
      'reward_identifier': rewardIdentifier,
      'assigned_at': assignedAt.toIso8601String(),
      'collection_status': collectionStatus,
      'collected_at': collectedAt?.toIso8601String(),
      'operator_note': operatorNote,
    };
  }
}
