/// Reward service managing inventory checks, physical reward allocation,
/// fallback handling, and persistence.
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

  /// Assign a reward for an attempt based on the mapped reward type.
  /// Checks stock levels and falls back gracefully if physical inventory is exhausted.
  Future<RewardAssignmentResult> assignRewardForAttempt({
    required String attemptId,
    required String requestedRewardType,
  }) async {
    // Check if a reward is already assigned to this attempt (idempotency check)
    final existing = await _dbHelper.getRewardForAttempt(attemptId);
    if (existing != null) {
      return RewardAssignmentResult(
        reward: existing,
        inventoryExhausted: false,
      );
    }

    String actualRewardType = requestedRewardType;
    bool exhausted = false;
    String? fallbackMessage;

    // Pick a gift from the requested tier that still has units in stock.
    String? targetInventoryId = await _pickInStockGift(requestedRewardType);
    if (targetInventoryId == null) {
      exhausted = true;
      if (requestedRewardType == AppConstants.rewardPremiumGift) {
        // Fallback for exhausted premium gift: allocate a score 3–4 gift, else a sticker
        actualRewardType = AppConstants.rewardSpinWheel;
        fallbackMessage =
            'Premium Gift inventory is currently exhausted. You have been awarded an exclusive educational activity reward!';
      } else {
        actualRewardType = AppConstants.rewardSticker;
        fallbackMessage =
            'Inventory item depleted. Awarded an official Unicorn Learning Lab sticker pack!';
      }
      targetInventoryId = await _pickInStockGift(actualRewardType);
      if (targetInventoryId == null && actualRewardType != AppConstants.rewardSticker) {
        actualRewardType = AppConstants.rewardSticker;
        targetInventoryId = await _pickInStockGift(actualRewardType);
      }
      // Nothing left anywhere: still record the outcome against the default item.
      targetInventoryId ??= await _anyGiftForType(actualRewardType) ??
          _defaultIdentifierFor(actualRewardType);
    }

    final newReward = Reward(
      attemptId: attemptId,
      rewardType: actualRewardType,
      rewardIdentifier: targetInventoryId,
      collectionStatus: AppConstants.statusAssigned,
    );

    // Transactionally persist reward and update inventory
    await _dbHelper.assignRewardTransaction(
      reward: newReward,
      inventoryIdentifier: targetInventoryId,
    );

    return RewardAssignmentResult(
      reward: newReward,
      inventoryExhausted: exhausted,
      fallbackMessage: fallbackMessage,
    );
  }

  static String _defaultIdentifierFor(String rewardType) {
    switch (rewardType) {
      case AppConstants.rewardPremiumGift:
        return 'PREMIUM_DISCOVERY_KIT';
      case AppConstants.rewardSpinWheel:
        return 'SPIN_WHEEL_GIFT';
      case AppConstants.rewardScratchCard:
        return 'SCRATCH_CARD_STATIONERY';
      case AppConstants.rewardSticker:
      default:
        return 'UNICORN_STICKER_PACK';
    }
  }

  /// Returns the identifier of an in-stock gift for this tier, preferring the
  /// built-in default gift, then operator-added gifts in the order they were added.
  /// Returns null when every gift in the tier is out of stock.
  Future<String?> _pickInStockGift(String rewardType) async {
    final items = await _dbHelper.getInventoryForType(rewardType);
    if (items.isEmpty) {
      // Legacy behaviour: if the tier has no configured gifts, use the default identifier
      // unless it exists under another tier and is exhausted.
      final fallback = await _dbHelper.getInventoryItem(_defaultIdentifierFor(rewardType));
      if (fallback == null) return _defaultIdentifierFor(rewardType);
      return fallback.isExhausted ? null : fallback.rewardIdentifier;
    }
    final defaultId = _defaultIdentifierFor(rewardType);
    final inStock = items.where((i) => !i.isExhausted).toList();
    if (inStock.isEmpty) return null;
    final preferred = inStock.where((i) => i.rewardIdentifier == defaultId);
    return preferred.isNotEmpty ? preferred.first.rewardIdentifier : inStock.first.rewardIdentifier;
  }

  Future<String?> _anyGiftForType(String rewardType) async {
    final items = await _dbHelper.getInventoryForType(rewardType);
    return items.isEmpty ? null : items.first.rewardIdentifier;
  }

  /// Mark an assigned reward as collected by participant.
  Future<bool> markCollected(String rewardId, {String? operatorNote}) async {
    return await _dbHelper.markRewardCollected(rewardId,
        operatorNote: operatorNote);
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
