/// Reward service: picks the gift for a score from the operator's score → gift
/// table, checks stock, falls back when a gift runs out, and saves the result.
library;

import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';

class RewardAssignmentResult {
  const RewardAssignmentResult({
    required this.reward,
    required this.inventoryExhausted,
    this.fallbackMessage,
  });

  final Reward reward;
  final bool inventoryExhausted;
  final String? fallbackMessage;
}

class RewardService {
  RewardService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// The gift identifier for each score 0–5, as set in the Inventory tab.
  Future<List<String>> getScoreGiftMap() async {
    try {
      return await _dbHelper.getScoreGiftMap();
    } catch (_) {
      return List<String>.of(AppConstants.defaultScoreGifts);
    }
  }

  /// Assign the gift for [score] to an attempt.
  ///
  /// The gift comes from the score → gift table. If that gift is out of stock,
  /// the visitor gets the in-stock gift mapped to the nearest lower score, then
  /// any other in-stock gift. If nothing is left, the mapped gift is still
  /// recorded so the operator can see who is owed one.
  Future<RewardAssignmentResult> assignRewardForAttempt({
    required String attemptId,
    required int score,
  }) async {
    // Idempotency: never assign twice for the same attempt.
    final existing = await _dbHelper.getRewardForAttempt(attemptId);
    if (existing != null) {
      return RewardAssignmentResult(reward: existing, inventoryExhausted: false);
    }

    final clamped = score.clamp(0, AppConstants.maxScore);
    final map = await getScoreGiftMap();
    final mappedId = map[clamped];

    List<RewardInventory> inventory;
    try {
      inventory = await _dbHelper.getAllInventory();
    } catch (_) {
      inventory = const [];
    }
    final byId = {for (final i in inventory) i.rewardIdentifier: i};

    bool inStock(String id) {
      final item = byId[id];
      // A gift that isn't in the inventory list at all (e.g. no database on the
      // web preview) is treated as available so the visitor still sees it.
      return item == null ? inventory.isEmpty : !item.isExhausted;
    }

    String chosenId = mappedId;
    bool exhausted = false;
    String? fallbackMessage;

    if (!inStock(mappedId)) {
      exhausted = true;
      String? fallback;
      for (var s = clamped - 1; s >= 0 && fallback == null; s--) {
        if (inStock(map[s])) fallback = map[s];
      }
      fallback ??= inventory.where((i) => !i.isExhausted).map((i) => i.rewardIdentifier).firstOrNull;
      if (fallback != null) {
        chosenId = fallback;
        final mappedName = byId[mappedId]?.displayName ?? RewardInventory.prettifyIdentifier(mappedId);
        final newName = byId[fallback]?.displayName ?? RewardInventory.prettifyIdentifier(fallback);
        fallbackMessage = 'All the $mappedName gifts have been claimed, so you have been awarded the $newName instead!';
      } else {
        fallbackMessage = 'All gifts have been claimed for now. Please speak to campaign staff about your reward.';
      }
    }

    final newReward = Reward(
      attemptId: attemptId,
      rewardType: AppConstants.rewardGift,
      rewardIdentifier: chosenId,
      collectionStatus: AppConstants.statusAssigned,
    );

    await _dbHelper.assignRewardTransaction(
      reward: newReward,
      inventoryIdentifier: chosenId,
    );

    return RewardAssignmentResult(
      reward: newReward,
      inventoryExhausted: exhausted,
      fallbackMessage: fallbackMessage,
    );
  }

  /// Mark an assigned reward as collected by participant.
  Future<bool> markCollected(String rewardId, {String? operatorNote}) async {
    return await _dbHelper.markRewardCollected(rewardId, operatorNote: operatorNote);
  }

  /// Fetch all inventory items.
  Future<List<RewardInventory>> getInventory() async {
    return await _dbHelper.getAllInventory();
  }

  /// Update stock for an inventory item.
  Future<void> updateStock(String rewardIdentifier, int newStock) async {
    await _dbHelper.updateInventoryStock(rewardIdentifier, newStock);
  }
}
