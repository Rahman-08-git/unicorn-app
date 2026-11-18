/// Reward inventory tracking stock levels for physical campaign gifts.
library;

import 'package:uuid/uuid.dart';

class RewardInventory {
  RewardInventory({
    String? id,
    required this.rewardType,
    required this.rewardIdentifier,
    String? displayName,
    required this.configuredStock,
    this.assignedCount = 0,
    this.collectedCount = 0,
    DateTime? lastUpdated,
  })  : id = id ?? const Uuid().v4(),
        displayName = (displayName == null || displayName.trim().isEmpty)
            ? prettifyIdentifier(rewardIdentifier)
            : displayName.trim(),
        lastUpdated = lastUpdated ?? DateTime.now();

  final String id;

  /// Reward tier this gift belongs to (PREMIUM_GIFT, SCRATCH_CARD, SPIN_WHEEL, STICKER).
  final String rewardType;

  /// Stable internal key, referenced by assigned rewards. Never changes.
  final String rewardIdentifier;

  /// Operator-editable gift name shown in the dashboard.
  final String displayName;

  /// Total units ever loaded (units in stock + units already won).
  final int configuredStock;
  final int assignedCount;
  final int collectedCount;
  final DateTime lastUpdated;

  /// Units physically left to give away. Goes down by one each time this gift is won.
  int get availableStock {
    final v = configuredStock - assignedCount;
    return v < 0 ? 0 : v;
  }

  bool get isExhausted => availableStock <= 0;

  static String prettifyIdentifier(String id) {
    return id
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  factory RewardInventory.fromMap(Map<String, dynamic> map) {
    return RewardInventory(
      id: map['id'] as String,
      rewardType: map['reward_type'] as String,
      rewardIdentifier: map['reward_identifier'] as String,
      displayName: map['display_name'] as String?,
      configuredStock: map['configured_stock'] as int? ?? 0,
      assignedCount: map['assigned_count'] as int? ?? 0,
      collectedCount: map['collected_count'] as int? ?? 0,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reward_type': rewardType,
      'reward_identifier': rewardIdentifier,
      'display_name': displayName,
      'configured_stock': configuredStock,
      'assigned_count': assignedCount,
      'collected_count': collectedCount,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
