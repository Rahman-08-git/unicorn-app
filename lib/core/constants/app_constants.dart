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
  static const int databaseVersion = 3;

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
  static const String rewardPremiumGift = 'PREMIUM_GIFT';
  /// Legacy tier: the scratch card was removed. Old records may still carry it;
  /// it is treated as the score 3–4 tier everywhere.
  static const String rewardScratchCard = 'SCRATCH_CARD';
  static const String rewardSpinWheel = 'SPIN_WHEEL';
  static const String rewardSticker = 'STICKER';

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
