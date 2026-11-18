/// Campaign configuration model.
library;

class CampaignConfig {
  CampaignConfig({
    this.id = 'default',
    this.campaignId = 'ULL-CAMPAIGN-2026',
    this.campaignName = 'Unicorn Learning Lab Campaign',
    this.tabletId = 'TABLET-01',
    this.timerDurationSeconds = 60,
    this.rewardMode = 'spin_wheel', // reward reveal is always the spin wheel
    this.activeQuestionBankVersion = '1.0',
    this.sessionResetSeconds = 45,
    this.operatorPin = '1234',
    this.soundEnabled = true,
    this.hapticEnabled = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String campaignId;
  final String campaignName;
  final String tabletId;
  final int timerDurationSeconds;
  final String rewardMode; // legacy column; always 'spin_wheel'
  final String activeQuestionBankVersion;
  final int sessionResetSeconds;
  final String operatorPin;
  final bool soundEnabled;
  final bool hapticEnabled;
  final DateTime updatedAt;

  factory CampaignConfig.fromMap(Map<String, dynamic> map) {
    return CampaignConfig(
      id: map['id'] as String? ?? 'default',
      campaignId: map['campaign_id'] as String? ?? 'ULL-CAMPAIGN-2026',
      campaignName: map['campaign_name'] as String? ?? 'Unicorn Learning Lab Campaign',
      tabletId: map['tablet_id'] as String? ?? 'TABLET-01',
      timerDurationSeconds: map['timer_duration_seconds'] as int? ?? 60,
      rewardMode: 'spin_wheel', // scratch card was removed; ignore any stored legacy value
      activeQuestionBankVersion: map['active_question_bank_version'] as String? ?? '1.0',
      sessionResetSeconds: map['session_reset_seconds'] as int? ?? 45,
      operatorPin: map['operator_pin'] as String? ?? '1234',
      soundEnabled: (map['sound_enabled'] as int? ?? 1) == 1,
      hapticEnabled: (map['haptic_enabled'] as int? ?? 1) == 1,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'campaign_name': campaignName,
      'tablet_id': tabletId,
      'timer_duration_seconds': timerDurationSeconds,
      'reward_mode': rewardMode,
      'active_question_bank_version': activeQuestionBankVersion,
      'session_reset_seconds': sessionResetSeconds,
      'operator_pin': operatorPin,
      'sound_enabled': soundEnabled ? 1 : 0,
      'haptic_enabled': hapticEnabled ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
