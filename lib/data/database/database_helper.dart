/// SQLite database helper for Unicorn Learning Lab.
///
/// Provides schema creation, migrations, seed data, transactions,
/// duplicate prevention, and CRUD operations for all entities.
library;

import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/campaign_config.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, AppConstants.databaseName);

    return openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. participants
    batch.execute('''
      CREATE TABLE participants (
        id                     TEXT PRIMARY KEY,
        audience_category      TEXT NOT NULL,
        class_level            TEXT,
        phone_number           TEXT,
        name                   TEXT,
        consent_given          INTEGER NOT NULL DEFAULT 0,
        registration_timestamp TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_participants_cat ON participants (audience_category)');

    // 2. attempts
    batch.execute('''
      CREATE TABLE attempts (
        id                     TEXT PRIMARY KEY,
        participant_id         TEXT NOT NULL,
        campaign_id            TEXT NOT NULL,
        tablet_id              TEXT NOT NULL,
        audience_category      TEXT NOT NULL,
        class_level            TEXT,
        started_at             TEXT NOT NULL,
        completed_at           TEXT,
        score                  INTEGER NOT NULL DEFAULT 0,
        total_questions        INTEGER NOT NULL DEFAULT 5,
        question_bank_version  TEXT NOT NULL DEFAULT '1.0',
        status                 TEXT NOT NULL,
        assigned_reward_id     TEXT,
        FOREIGN KEY (participant_id) REFERENCES participants (id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_attempts_participant ON attempts (participant_id)');
    batch.execute('CREATE INDEX idx_attempts_status ON attempts (status)');

    // 3. answers
    batch.execute('''
      CREATE TABLE answers (
        id                     TEXT PRIMARY KEY,
        attempt_id             TEXT NOT NULL,
        question_id            TEXT NOT NULL,
        selected_answer_id     TEXT,
        correct_answer_id      TEXT NOT NULL,
        is_correct             INTEGER NOT NULL,
        is_timeout             INTEGER NOT NULL DEFAULT 0,
        time_taken_seconds     INTEGER NOT NULL DEFAULT 0,
        question_sequence      INTEGER NOT NULL,
        UNIQUE (attempt_id, question_id),
        FOREIGN KEY (attempt_id) REFERENCES attempts (id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_answers_attempt ON answers (attempt_id)');

    // 4. rewards
    batch.execute('''
      CREATE TABLE rewards (
        id                     TEXT PRIMARY KEY,
        attempt_id             TEXT NOT NULL UNIQUE,
        reward_type            TEXT NOT NULL,
        reward_identifier      TEXT NOT NULL,
        assigned_at            TEXT NOT NULL,
        collection_status      TEXT NOT NULL DEFAULT 'ASSIGNED',
        collected_at           TEXT,
        operator_note          TEXT,
        FOREIGN KEY (attempt_id) REFERENCES attempts (id) ON DELETE CASCADE
      )
    ''');

    // 5. reward_inventory
    batch.execute('''
      CREATE TABLE reward_inventory (
        id                     TEXT PRIMARY KEY,
        reward_type            TEXT NOT NULL,
        reward_identifier      TEXT NOT NULL UNIQUE,
        display_name           TEXT,
        configured_stock       INTEGER NOT NULL DEFAULT 0,
        assigned_count         INTEGER NOT NULL DEFAULT 0,
        collected_count        INTEGER NOT NULL DEFAULT 0,
        last_updated           TEXT NOT NULL
      )
    ''');

    // 6. campaign_config
    batch.execute('''
      CREATE TABLE campaign_config (
        id                          TEXT PRIMARY KEY,
        campaign_id                 TEXT NOT NULL,
        campaign_name               TEXT NOT NULL,
        tablet_id                   TEXT NOT NULL,
        timer_duration_seconds      INTEGER NOT NULL DEFAULT 60,
        reward_mode                 TEXT NOT NULL DEFAULT 'spin_wheel',
        active_question_bank_version TEXT NOT NULL DEFAULT '1.0',
        session_reset_seconds       INTEGER NOT NULL DEFAULT 45,
        operator_pin                TEXT NOT NULL DEFAULT '1234',
        sound_enabled               INTEGER NOT NULL DEFAULT 1,
        haptic_enabled              INTEGER NOT NULL DEFAULT 1,
        updated_at                  TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
    await _createV2Tables(db);
    await _seedDefaults(db);
  }

  /// Tables added in schema v2: operator-edited questions and app settings.
  Future<void> _createV2Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_questions (
        id          TEXT PRIMARY KEY,
        audience    TEXT NOT NULL,
        json        TEXT NOT NULL,
        deleted     INTEGER NOT NULL DEFAULT 0,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key    TEXT PRIMARY KEY,
        value  TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = await db.rawQuery('PRAGMA table_info(reward_inventory)');
      final hasDisplayName = cols.any((c) => c['name'] == 'display_name');
      if (!hasDisplayName) {
        await db.execute('ALTER TABLE reward_inventory ADD COLUMN display_name TEXT');
      }
      for (final entry in legacyGiftNames.entries) {
        await db.update(
          'reward_inventory',
          {'display_name': entry.value},
          where: 'reward_identifier = ? AND display_name IS NULL',
          whereArgs: [entry.key],
        );
      }
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      await _migrateScratchCardToSpinWheel(db);
    }
    if (oldVersion < 4) {
      await _migrateToScoreGiftTable(db);
    }
  }

  /// v4: fixed reward tiers (premium / spin wheel / sticker) are replaced by an
  /// operator-editable score → gift table. Existing gifts keep their name, stock
  /// and history, but are no longer tied to a tier. The three new default gifts
  /// (Explorer 0–1, Achiever 2–3, Champion 4–5) are added and mapped.
  Future<void> _migrateToScoreGiftTable(DatabaseExecutor db) async {
    await db.update('reward_inventory', {'reward_type': AppConstants.rewardGift});
    await _insertDefaultGifts(db);
    await db.insert(
      'app_settings',
      {'key': AppConstants.settingScoreGiftMap, 'value': jsonEncode(AppConstants.defaultScoreGifts)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _insertDefaultGifts(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    for (final entry in AppConstants.defaultGiftNames.entries) {
      await db.insert(
        'reward_inventory',
        {
          'id': 'inv_${entry.key.toLowerCase()}',
          'reward_type': AppConstants.rewardGift,
          'reward_identifier': entry.key,
          'display_name': entry.value,
          'configured_stock': AppConstants.defaultGiftStock[entry.key] ?? 0,
          'assigned_count': 0,
          'collected_count': 0,
          'last_updated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// v3: the scratch-card reveal was removed. Gifts that were in the scratch-card
  /// tier keep their name and stock but move to the score 3–4 (spin wheel) tier,
  /// and the campaign's reward mode becomes the spin wheel.
  Future<void> _migrateScratchCardToSpinWheel(DatabaseExecutor db) async {
    await db.update(
      'reward_inventory',
      {'reward_type': AppConstants.rewardSpinWheel},
      where: 'reward_type = ?',
      whereArgs: [AppConstants.rewardScratchCard],
    );
    await db.update('campaign_config', {'reward_mode': 'spin_wheel'});
  }

  /// Names of the gifts seeded before v4 (used only by the v2 migration).
  static const Map<String, String> legacyGiftNames = {
    'PREMIUM_DISCOVERY_KIT': 'Premium Discovery Kit',
    'SCRATCH_CARD_STATIONERY': 'Stationery Set',
    'SPIN_WHEEL_GIFT': 'Spin Wheel Gift',
    'UNICORN_STICKER_PACK': 'Unicorn Sticker Pack',
  };

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Seed default campaign config
    await db.insert('campaign_config', {
      'id': 'default',
      'campaign_id': AppConstants.defaultCampaignId,
      'campaign_name': AppConstants.defaultCampaignName,
      'tablet_id': AppConstants.defaultTabletId,
      'timer_duration_seconds': AppConstants.defaultTimerDurationSeconds,
      'reward_mode': 'spin_wheel',
      'active_question_bank_version': '1.0',
      'session_reset_seconds': AppConstants.defaultSessionResetSeconds,
      'operator_pin': AppConstants.defaultOperatorPin,
      'sound_enabled': 1,
      'haptic_enabled': 1,
      'updated_at': now,
    });

    // Seed the default gifts and the score → gift table.
    await _insertDefaultGifts(db);
    await db.insert(
      'app_settings',
      {'key': AppConstants.settingScoreGiftMap, 'value': jsonEncode(AppConstants.defaultScoreGifts)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Participants CRUD
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> insertParticipant(Participant participant) async {
    final db = await database;
    await db.insert('participants', participant.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Participant?> getParticipant(String id) async {
    final db = await database;
    final results = await db.query('participants', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Participant.fromMap(results.first);
  }

  Future<void> updateParticipantName(String id, String? name) async {
    final db = await database;
    await db.update('participants', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Participant>> getAllParticipants() async {
    final db = await database;
    final results = await db.query('participants', orderBy: 'registration_timestamp DESC');
    return results.map((m) => Participant.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Attempts CRUD
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> insertAttempt(Attempt attempt) async {
    final db = await database;
    await db.insert('attempts', attempt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Attempt?> getAttempt(String id) async {
    final db = await database;
    final results = await db.query('attempts', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Attempt.fromMap(results.first);
  }

  Future<void> updateAttempt(Attempt attempt) async {
    final db = await database;
    await db.update('attempts', attempt.toMap(),
        where: 'id = ?', whereArgs: [attempt.id]);
  }

  Future<List<Attempt>> getAllAttempts() async {
    final db = await database;
    final results = await db.query('attempts', orderBy: 'started_at DESC');
    return results.map((m) => Attempt.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Answers CRUD
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> insertAnswer(Answer answer) async {
    final db = await database;
    try {
      // Abort if an answer already exists for this attempt and question (prevents duplicate submissions)
      final id = await db.insert('answers', answer.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort);
      return id > 0;
    } catch (_) {
      return false; // Already submitted
    }
  }

  /// Every recorded answer, grouped later by attempt (used by the CSV export).
  Future<List<Answer>> getAllAnswers() async {
    final db = await database;
    final results = await db.query('answers', orderBy: 'attempt_id ASC, question_sequence ASC');
    return results.map((m) => Answer.fromMap(m)).toList();
  }

  Future<List<Answer>> getAnswersForAttempt(String attemptId) async {
    final db = await database;
    final results = await db.query(
      'answers',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      orderBy: 'question_sequence ASC',
    );
    return results.map((m) => Answer.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Rewards CRUD & Inventory Transactions
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> assignRewardTransaction({
    required Reward reward,
    required String inventoryIdentifier,
  }) async {
    final db = await database;
    return await db.transaction<bool>((txn) async {
      // 1. Check if reward already exists for this attempt (idempotency)
      final existing = await txn.query('rewards',
          where: 'attempt_id = ?', whereArgs: [reward.attemptId]);
      if (existing.isNotEmpty) {
        return false; // Duplicate reward prevented
      }

      // 2. Insert reward
      await txn.insert('rewards', reward.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort);

      // 3. Increment assigned_count in inventory
      await txn.rawUpdate('''
        UPDATE reward_inventory
        SET assigned_count = assigned_count + 1,
            last_updated = ?
        WHERE reward_identifier = ?
      ''', [DateTime.now().toIso8601String(), inventoryIdentifier]);

      // 4. Update attempt with assigned reward ID
      await txn.update(
        'attempts',
        {'assigned_reward_id': reward.id},
        where: 'id = ?',
        whereArgs: [reward.attemptId],
      );

      return true;
    });
  }

  Future<Reward?> getRewardForAttempt(String attemptId) async {
    final db = await database;
    final results =
        await db.query('rewards', where: 'attempt_id = ?', whereArgs: [attemptId]);
    if (results.isEmpty) return null;
    return Reward.fromMap(results.first);
  }

  Future<List<Reward>> getAllRewards() async {
    final db = await database;
    final results = await db.query('rewards', orderBy: 'assigned_at DESC');
    return results.map((m) => Reward.fromMap(m)).toList();
  }

  Future<bool> markRewardCollected(String rewardId, {String? operatorNote}) async {
    final db = await database;
    return await db.transaction<bool>((txn) async {
      final rewards =
          await txn.query('rewards', where: 'id = ?', whereArgs: [rewardId]);
      if (rewards.isEmpty) return false;
      final reward = Reward.fromMap(rewards.first);
      if (reward.collectionStatus == AppConstants.statusCollected) return true;

      final now = DateTime.now().toIso8601String();
      await txn.update(
        'rewards',
        {
          'collection_status': AppConstants.statusCollected,
          'collected_at': now,
          'operator_note': operatorNote,
        },
        where: 'id = ?',
        whereArgs: [rewardId],
      );

      await txn.rawUpdate('''
        UPDATE reward_inventory
        SET collected_count = collected_count + 1,
            last_updated = ?
        WHERE reward_identifier = ?
      ''', [now, reward.rewardIdentifier]);

      return true;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Inventory CRUD
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<RewardInventory>> getAllInventory() async {
    final db = await database;
    final results = await db.query('reward_inventory', orderBy: 'rowid ASC');
    return results.map((m) => RewardInventory.fromMap(m)).toList();
  }

  Future<RewardInventory?> getInventoryItem(String rewardIdentifier) async {
    final db = await database;
    final results = await db.query('reward_inventory',
        where: 'reward_identifier = ?', whereArgs: [rewardIdentifier]);
    if (results.isEmpty) return null;
    return RewardInventory.fromMap(results.first);
  }

  /// Add a new gift to the inventory. Returns false if the identifier exists.
  Future<bool> insertInventoryItem(RewardInventory item) async {
    final db = await database;
    final id = await db.insert('reward_inventory', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id > 0;
  }

  /// Update a gift's name, reward tier and the number of units currently in stock.
  /// Stored as configured_stock = assigned + unitsInStock, so the remaining
  /// count keeps going down automatically every time the gift is won.
  Future<void> updateInventoryItem({
    required String rewardIdentifier,
    required String displayName,
    required String rewardType,
    required int unitsInStock,
  }) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE reward_inventory
      SET display_name = ?,
          reward_type = ?,
          configured_stock = assigned_count + ?,
          last_updated = ?
      WHERE reward_identifier = ?
    ''', [
      displayName,
      rewardType,
      unitsInStock < 0 ? 0 : unitsInStock,
      DateTime.now().toIso8601String(),
      rewardIdentifier,
    ]);
  }

  Future<void> deleteInventoryItem(String rewardIdentifier) async {
    final db = await database;
    await db.delete('reward_inventory',
        where: 'reward_identifier = ?', whereArgs: [rewardIdentifier]);
  }

  Future<void> updateInventoryStock(String rewardIdentifier, int newStock) async {
    final db = await database;
    await db.update(
      'reward_inventory',
      {
        'configured_stock': newStock,
        'last_updated': DateTime.now().toIso8601String(),
      },
      where: 'reward_identifier = ?',
      whereArgs: [rewardIdentifier],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Operator-edited Questions (applied on top of the built-in bank)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, Object?>>> getCustomQuestionRows() async {
    final db = await database;
    return db.query('custom_questions', orderBy: 'updated_at ASC');
  }

  Future<void> upsertCustomQuestion({
    required String id,
    required String audience,
    required String json,
    bool deleted = false,
  }) async {
    final db = await database;
    await db.insert(
      'custom_questions',
      {
        'id': id,
        'audience': audience,
        'json': json,
        'deleted': deleted ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomQuestionRow(String id) async {
    final db = await database;
    await db.delete('custom_questions', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  App Settings (key/value)
  // ═══════════════════════════════════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Score → gift table (operator-editable in the Inventory tab)
  // ═══════════════════════════════════════════════════════════════════════

  /// The gift identifier for each score 0–5 (index = score). Missing or broken
  /// entries fall back to [AppConstants.defaultScoreGifts].
  Future<List<String>> getScoreGiftMap() async {
    final raw = await getSetting(AppConstants.settingScoreGiftMap);
    return decodeScoreGiftMap(raw);
  }

  Future<void> setScoreGiftMap(List<String> giftIds) async {
    await setSetting(AppConstants.settingScoreGiftMap, jsonEncode(giftIds));
  }

  static List<String> decodeScoreGiftMap(String? raw) {
    final result = List<String>.of(AppConstants.defaultScoreGifts);
    if (raw == null || raw.isEmpty) return result;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (var i = 0; i < result.length && i < decoded.length; i++) {
          final v = decoded[i];
          if (v is String && v.isNotEmpty) result[i] = v;
        }
      }
    } catch (_) {}
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Campaign Config
  // ═══════════════════════════════════════════════════════════════════════

  Future<CampaignConfig> getCampaignConfig() async {
    final db = await database;
    final results = await db.query('campaign_config', where: "id = 'default'");
    if (results.isEmpty) {
      return CampaignConfig();
    }
    return CampaignConfig.fromMap(results.first);
  }

  Future<void> updateCampaignConfig(CampaignConfig config) async {
    final db = await database;
    await db.insert('campaign_config', config.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Operator Dashboard Statistics
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;

    final totalParticipantsResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM participants');
    final totalParticipants =
        Sqflite.firstIntValue(totalParticipantsResult) ?? 0;

    final completedAttemptsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM attempts WHERE status = 'COMPLETED'");
    final completedAttempts =
        Sqflite.firstIntValue(completedAttemptsResult) ?? 0;

    final incompleteAttemptsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM attempts WHERE status != 'COMPLETED'");
    final incompleteAttempts =
        Sqflite.firstIntValue(incompleteAttemptsResult) ?? 0;

    final avgScoreResult = await db.rawQuery(
        "SELECT AVG(score) as avg_score FROM attempts WHERE status = 'COMPLETED'");
    final avgScore = (avgScoreResult.first['avg_score'] as num?)?.toDouble() ?? 0.0;

    // Score distribution (0 through 5)
    final scoreDist = <int, int>{};
    for (int i = 0; i <= 5; i++) {
      scoreDist[i] = 0;
    }
    final scoreCounts = await db.rawQuery(
        "SELECT score, COUNT(*) as count FROM attempts WHERE status = 'COMPLETED' GROUP BY score");
    for (final row in scoreCounts) {
      final s = row['score'] as int? ?? 0;
      final c = row['count'] as int? ?? 0;
      scoreDist[s] = c;
    }

    // Audience breakdown
    final audienceCounts = await db.rawQuery(
        'SELECT audience_category, COUNT(*) as count FROM participants GROUP BY audience_category');
    final audienceBreakdown = <String, int>{};
    for (final row in audienceCounts) {
      final cat = row['audience_category'] as String? ?? 'OTHER';
      final c = row['count'] as int? ?? 0;
      audienceBreakdown[cat] = c;
    }

    // Class-wise participation for students
    final classCounts = await db.rawQuery(
        "SELECT class_level, COUNT(*) as count FROM participants WHERE audience_category = 'STUDENT' AND class_level IS NOT NULL GROUP BY class_level");
    final classBreakdown = <String, int>{};
    for (final row in classCounts) {
      final cl = row['class_level'] as String? ?? 'UNKNOWN';
      final c = row['count'] as int? ?? 0;
      classBreakdown[cl] = c;
    }

    // Reward assignment counts
    final rewardCounts = await db.rawQuery(
        'SELECT reward_type, collection_status, COUNT(*) as count FROM rewards GROUP BY reward_type, collection_status');

    return {
      'totalParticipants': totalParticipants,
      'completedAttempts': completedAttempts,
      'incompleteAttempts': incompleteAttempts,
      'averageScore': avgScore,
      'scoreDistribution': scoreDist,
      'audienceBreakdown': audienceBreakdown,
      'classBreakdown': classBreakdown,
      'rewardCounts': rewardCounts,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Destructive Maintenance
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> resetAllCampaignData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('answers');
      await txn.delete('rewards');
      await txn.delete('attempts');
      await txn.delete('participants');
      // Keep the physical units still on hand: gifts already won are gone.
      await txn.rawUpdate('''
        UPDATE reward_inventory
        SET configured_stock = MAX(configured_stock - assigned_count, 0),
            assigned_count = 0,
            collected_count = 0,
            last_updated = ?
      ''', [DateTime.now().toIso8601String()]);
    });
  }
}
