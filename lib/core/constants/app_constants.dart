/// App-wide constants for Unicorn Learning Lab - Education 4.0.
library;

class AppConstants {
  AppConstants._();

  // ── Brand Info ──────────────────────────────────────────────────────────
  static const String appName = 'Unicorn Learning Lab';
  static const String appTagline = 'EDUCATION 4.0';
  static const String appPhilosophy = 'THINK. EXPLORE. DISCOVER.';
  static const String appVersion = '1.0.0';
  static const String defaultTabletId = 'TABLET-01';
  static const String defaultCampaignId = 'ULL-CAMPAIGN-2026';
  static const String defaultCampaignName = 'Education 4.0 Launch Campaign';

  // ── Database ──────────────────────────────────────────────────────────
  static const String databaseName = 'unicorn_learning_lab.db';
  static const int databaseVersion = 4;

  // ── Quiz Settings ─────────────────────────────────────────────────────
  static const int questionsPerAttempt = 5;
  static const int defaultTimerDurationSeconds = 60;
  static const int defaultSessionResetSeconds = 45;
  static const int maxScore = 5;

  // ── Default Operator Security ─────────────────────────────────────────
  static const String defaultOperatorPin = '1234';
  static const int maxPinAttempts = 5;
  static const int pinLockoutSeconds = 60;

  // ── Result Titles ─────────────────────────────────────────────────────
  static const String titleScore5 = 'DISCOVERY CHAMPION';
  static const String titleScore4 = 'PROBLEM SOLVER';
  static const String titleScore3 = 'PATTERN EXPLORER';
  static const String titleScore0To2 = 'CURIOUS EXPLORER';

  // ── Reward Types ──────────────────────────────────────────────────────
  /// Every gift now uses this type. Which gift a visitor wins is decided by the
  /// operator's score → gift table (see [defaultScoreGifts]), not by the type.
  static const String rewardGift = 'GIFT';

  /// Legacy tiers (before the score → gift table). Old reward records may still
  /// carry them; they are only used to label those records.
  static const String rewardPremiumGift = 'PREMIUM_GIFT';
  /// Legacy tier: the scratch card was removed. Old records may still carry it;
  /// it is treated as the score 3–4 tier everywhere.
  static const String rewardScratchCard = 'SCRATCH_CARD';
  static const String rewardSpinWheel = 'SPIN_WHEEL';
  static const String rewardSticker = 'STICKER';

  // ── Default gifts and score → gift table ──────────────────────────────
  static const String giftExplorer = 'UNICORN_EXPLORER_GIFT';
  static const String giftAchiever = 'UNICORN_ACHIEVER_GIFT';
  static const String giftChampion = 'UNICORN_CHAMPION_GIFT';

  static const Map<String, String> defaultGiftNames = {
    giftExplorer: 'UNICORN EXPLORER GIFT',
    giftAchiever: 'UNICORN ACHIEVER GIFT',
    giftChampion: 'UNICORN CHAMPION GIFT',
  };

  /// Starting stock for the default gifts on a new install / upgrade.
  static const Map<String, int> defaultGiftStock = {
    giftExplorer: 500,
    giftAchiever: 200,
    giftChampion: 50,
  };

  /// Default gift for each score (index = score 0–5). Editable in the
  /// operator dashboard's Inventory tab.
  static const List<String> defaultScoreGifts = [
    giftExplorer, // 0
    giftExplorer, // 1
    giftAchiever, // 2
    giftAchiever, // 3
    giftChampion, // 4
    giftChampion, // 5
  ];

  /// app_settings key holding the operator's score → gift table (JSON).
  static const String settingScoreGiftMap = 'score_gift_map';

  // ── Reward Collection Statuses ────────────────────────────────────────
  static const String statusAssigned = 'ASSIGNED';
  static const String statusCollected = 'COLLECTED';
  static const String statusUnavailable = 'UNAVAILABLE';
  static const String statusManuallyAdjusted = 'MANUALLY_ADJUSTED';

  // ── Audience Categories ───────────────────────────────────────────────
  static const String audienceParent = 'PARENT';
  static const String audienceGuardian = 'GUARDIAN';
  static const String audienceStudent = 'STUDENT';

  // ── Class Levels ──────────────────────────────────────────────────────
  static const List<String> studentClassLevels = [
    'PRE_PRIMARY',
    'CLASS_1',
    'CLASS_2',
    'CLASS_3',
    'CLASS_4',
    'CLASS_5',
    'CLASS_6',
    'CLASS_7',
    'CLASS_8',
    'CLASS_9',
    'CLASS_10',
    'CLASS_11',
    'CLASS_12',
    'COLLEGE',
  ];

  // ── Assets ────────────────────────────────────────────────────────────
  static const String questionsAssetPath = 'assets/questions/';
}
