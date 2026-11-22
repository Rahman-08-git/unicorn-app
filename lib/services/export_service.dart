/// CSV export service producing compliant UTF-8 CSV reports for tablets.
///
/// Files can be saved to a folder the operator picks with the system file
/// explorer (Android), or to the app's private documents folder as a fallback.
library;

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/storage_bridge.dart';

class ExportResult {
  const ExportResult({
    required this.success,
    required this.exportedFiles,
    this.errorMessage,
    this.locationLabel,
    this.folderUri,
  });

  final bool success;
  final List<String> exportedFiles;
  final String? errorMessage;

  /// Where the files were saved, readable by a human.
  final String? locationLabel;

  /// Folder URI (Android picker) so the UI can open it in the file explorer.
  final String? folderUri;
}

class ExportService {
  ExportService({
    DatabaseHelper? dbHelper,
    StorageBridge storage = const StorageBridge(),
    QuestionBankService? questionBank,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _storage = storage,
        _questionBank = questionBank;

  final DatabaseHelper _dbHelper;
  final StorageBridge _storage;

  /// Used to turn question and option IDs into readable text in the report.
  final QuestionBankService? _questionBank;

  static const String exportFolderSettingKey = 'export_folder_uri';

  /// Escape a value for CSV per RFC 4180.
  static String escapeCsvValue(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Format a 2D list of data into a CSV string.
  static String formatCsv(List<List<dynamic>> rows) {
    const converter = ListToCsvConverter();
    return converter.convert(rows);
  }

  // ── Human-readable formatting helpers ─────────────────────────────────

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

  static String _visitorType(String audienceCode, String? classLevel) {
    if (classLevel == 'DEMO') return 'Demo';
    switch (audienceCode.toUpperCase()) {
      case 'PARENT':
        return 'Parent';
      case 'GUARDIAN':
        return 'Guardian';
      default:
        return 'Student';
    }
  }

  static String _classLabel(String? classLevel) {
    if (classLevel == null || classLevel.isEmpty || classLevel == 'DEMO') return '';
    if (classLevel == 'COLLEGE') return 'College';
    if (classLevel == 'PRE_PRIMARY') return 'Pre-Primary';
    if (classLevel.startsWith('CLASS_')) return 'Class ${classLevel.substring(6)}';
    return classLevel;
  }

  static String _duration(DateTime start, DateTime? end) {
    if (end == null) return '';
    final secs = end.difference(start).inSeconds;
    if (secs < 0) return '';
    final m = secs ~/ 60, s = secs % 60;
    return m > 0 ? '$m min $s sec' : '$s sec';
  }

  /// "Reward Tier" column: the score band for current gifts, or the old tier
  /// name for rewards recorded before the score → gift table existed.
  static String _tierLabel(String rewardType, int score) {
    switch (rewardType) {
      case AppConstants.rewardPremiumGift:
        return 'Premium gift (score 5/5)';
      case AppConstants.rewardScratchCard: // legacy tier, merged into the 3-4 tier
      case AppConstants.rewardSpinWheel:
        return 'Spin wheel gift (score 3-4/5)';
      case AppConstants.rewardSticker:
        return 'Sticker (score 0-2/5)';
      default:
        return 'Gift for score $score/${AppConstants.maxScore}';
    }
  }

  /// Which scores win [giftId], e.g. "Score 0-1" or "Score 2, 4-5".
  static String scoresLabel(List<String> scoreGiftMap, String giftId) {
    final scores = [for (var i = 0; i < scoreGiftMap.length; i++) if (scoreGiftMap[i] == giftId) i];
    if (scores.isEmpty) return 'Not given for any score';
    final parts = <String>[];
    var start = scores.first, prev = scores.first;
    for (final s in [...scores.skip(1), -10]) {
      if (s == prev + 1) {
        prev = s;
        continue;
      }
      parts.add(start == prev ? '$start' : '$start-$prev');
      start = prev = s;
    }
    return 'Score ${parts.join(', ')}';
  }

  static String _statusLabel(String status) {
    switch (status) {
      case AppConstants.statusAssigned:
        return 'Not collected yet';
      case AppConstants.statusCollected:
        return 'Collected';
      case AppConstants.statusUnavailable:
        return 'Unavailable';
      case AppConstants.statusManuallyAdjusted:
        return 'Manually adjusted';
      default:
        return status;
    }
  }

  /// "B. Exploring concepts…" for an option id, using the question bank when possible.
  static String _optionText(Question? q, String? optionId) {
    if (optionId == null || optionId.isEmpty) return '';
    final opt = q?.options.where((o) => o.id == optionId);
    if (opt == null || opt.isEmpty) return optionId;
    return '$optionId. ${opt.first.text}';
  }

  Question? _findQuestion(String id) {
    final bank = _questionBank;
    if (bank == null) return null;
    for (final aud in bank.configuredAudienceCategories) {
      for (final q in bank.getAllQuestionsForAudience(aud)) {
        if (q.id == id) return q;
      }
    }
    return null;
  }

  /// Build all campaign CSV files in memory: file name → CSV contents.
  ///
  /// The main file is the Quiz Report: one row per quiz attempt with the
  /// visitor's details, every question with the answer they gave and the
  /// correct answer, their score and the gift they won. Everything is in plain
  /// words (no internal IDs or codes) so it opens cleanly in Excel / Sheets.
  Future<Map<String, String>> buildCsvFiles() async {
    final config = await _dbHelper.getCampaignConfig();
    final tabletId = config.tabletId;
    final now = DateTime.now();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(now);

    final participants = await _dbHelper.getAllParticipants();
    final attempts = await _dbHelper.getAllAttempts(); // newest first
    final rewards = await _dbHelper.getAllRewards();
    final inventory = await _dbHelper.getAllInventory();
    final answers = await _dbHelper.getAllAnswers();
    List<String> scoreGiftMap;
    try {
      scoreGiftMap = await _dbHelper.getScoreGiftMap();
    } catch (_) {
      scoreGiftMap = List<String>.of(AppConstants.defaultScoreGifts);
    }

    final participantsById = {for (final pt in participants) pt.id: pt};
    final giftNames = {for (final i in inventory) i.rewardIdentifier: i.displayName};
    final rewardsByAttempt = {for (final r in rewards) r.attemptId: r};
    final answersByAttempt = <String, List<Answer>>{};
    for (final a in answers) {
      answersByAttempt.putIfAbsent(a.attemptId, () => []).add(a);
    }
    final questionCache = <String, Question?>{};
    Question? question(String id) => questionCache.putIfAbsent(id, () => _findQuestion(id));
    const scoring = ScoringService();
    const perAttempt = AppConstants.questionsPerAttempt;
    const perQuestionCols = 5;

    final files = <String, String>{};

    // 1. Quiz Report — one row per visitor attempt.
    final reportRows = <List<dynamic>>[
      [
        'No.',
        'Date',
        'Start Time',
        'End Time',
        'Time Taken',
        'Visitor Type',
        'Name',
        'Phone Number',
        'Class',
        'Quiz Status',
        'Score',
        'Result',
        'Correct Answers',
        'Wrong Answers',
        'Timed Out',
        for (var i = 1; i <= perAttempt; i++) ...[
          'Q$i Question',
          'Q$i Visitor Answer',
          'Q$i Correct Answer',
          'Q$i Result',
          'Q$i Time Taken (sec)',
        ],
        'Reward Tier',
        'Gift Won',
        'Gift Status',
        'Gift Collected At',
        'Tablet',
        'Campaign',
      ],
    ];
    final attemptedParticipants = <String>{};
    var no = 0;
    for (final a in attempts) {
      attemptedParticipants.add(a.participantId);
      final pt = participantsById[a.participantId];
      final r = rewardsByAttempt[a.id];
      final ans = answersByAttempt[a.id] ?? const <Answer>[];
      final completed = a.status == AttemptStatus.completed;
      final correct = ans.where((x) => x.isCorrect).length;
      final timedOut = ans.where((x) => x.isTimeout).length;
      final wrong = ans.length - correct - timedOut;
      final classLevel = a.classLevel ?? pt?.classLevel;

      final qCols = <dynamic>[];
      for (var i = 1; i <= perAttempt; i++) {
        final match = ans.where((e) => e.questionSequence == i);
        if (match.isEmpty) {
          qCols.addAll(['', '', '', completed ? '' : 'Not answered', '']);
          continue;
        }
        final answer = match.first;
        final q = question(answer.questionId);
        qCols.addAll([
          q?.question ?? answer.questionId,
          answer.isTimeout ? '(no answer - time ran out)' : _optionText(q, answer.selectedAnswerId),
          _optionText(q, answer.correctAnswerId),
          answer.isTimeout ? 'Timed out' : (answer.isCorrect ? 'Correct' : 'Wrong'),
          answer.timeTakenSeconds,
        ]);
      }

      no++;
      reportRows.add([
        no,
        _date.format(a.startedAt),
        _time.format(a.startedAt),
        a.completedAt == null ? '' : _time.format(a.completedAt!),
        _duration(a.startedAt, a.completedAt),
        _visitorType(a.audienceCategory, classLevel),
        pt?.name ?? '',
        pt?.phoneNumber ?? '',
        _classLabel(classLevel),
        completed ? 'Completed' : 'Did not finish',
        completed ? '${a.score}/${a.totalQuestions}' : '$correct/${a.totalQuestions} (unfinished)',
        completed ? scoring.getTitleForScore(a.score) : '',
        correct,
        wrong,
        timedOut,
        ...qCols,
        r == null ? '' : _tierLabel(r.rewardType, a.score),
        r == null ? '' : (giftNames[r.rewardIdentifier] ?? RewardInventory.prettifyIdentifier(r.rewardIdentifier)),
        r == null ? '' : _statusLabel(r.collectionStatus),
        r?.collectedAt == null ? '' : _dateTime.format(r!.collectedAt!),
        a.tabletId.isEmpty ? tabletId : a.tabletId,
        config.campaignName,
      ]);
    }
    // Visitors who registered but never started a quiz.
    for (final pt in participants.where((p) => !attemptedParticipants.contains(p.id))) {
      no++;
      reportRows.add([
        no,
        _date.format(pt.registrationTimestamp),
        _time.format(pt.registrationTimestamp),
        '',
        '',
        _visitorType(pt.audienceCategory.code, pt.classLevel),
        pt.name ?? '',
        pt.phoneNumber ?? '',
        _classLabel(pt.classLevel),
        'Registered, quiz not started',
        '',
        '',
        '',
        '',
        '',
        for (var i = 0; i < perAttempt * perQuestionCols; i++) '',
        '',
        '',
        '',
        '',
        tabletId,
        config.campaignName,
      ]);
    }
    files['Quiz_Report_${tabletId}_$stamp.csv'] = formatCsv(reportRows);

    // 2. Gift inventory
    final inventoryRows = <List<dynamic>>[
      ['Gift Name', 'Given For', 'Units In Stock', 'Units Given Out', 'Units Collected', 'Last Updated'],
    ];
    for (final i in inventory) {
      inventoryRows.add([
        i.displayName,
        scoresLabel(scoreGiftMap, i.rewardIdentifier),
        i.availableStock,
        i.assignedCount,
        i.collectedCount,
        _dateTime.format(i.lastUpdated),
      ]);
    }
    files['Gift_Inventory_${tabletId}_$stamp.csv'] = formatCsv(inventoryRows);

    // 3. Summary
    final completedAttempts = attempts.where((a) => a.status == AttemptStatus.completed).toList();
    final avg = completedAttempts.isEmpty
        ? 0.0
        : completedAttempts.fold<int>(0, (s, a) => s + a.score) / completedAttempts.length;
    int visitors(String type) =>
        participants.where((p) => _visitorType(p.audienceCategory.code, p.classLevel) == type).length;
    final summaryRows = <List<dynamic>>[
      ['Item', 'Value'],
      ['Campaign', config.campaignName],
      ['Tablet', tabletId],
      ['Exported On', _dateTime.format(now)],
      ['Total Visitors', participants.length],
      ['Parents', visitors('Parent')],
      ['Guardians', visitors('Guardian')],
      ['Students', visitors('Student')],
      for (final cls in AppConstants.studentClassLevels)
        [
          'Students - ${_classLabel(cls)}',
          participants.where((p) => p.audienceCategory.code == 'STUDENT' && p.classLevel == cls).length,
        ],
      ['Demo Plays', visitors('Demo')],
      ['Quizzes Completed', completedAttempts.length],
      ['Quizzes Not Finished', attempts.length - completedAttempts.length],
      ['Average Score (out of $perAttempt)', avg.toStringAsFixed(2)],
      for (var sc = perAttempt; sc >= 0; sc--)
        ['Visitors Scoring $sc/$perAttempt', completedAttempts.where((a) => a.score == sc).length],
      ['Gifts Given Out', rewards.length],
      ['Gifts Collected', rewards.where((r) => r.isCollected).length],
      ['Gifts Not Collected Yet', rewards.where((r) => !r.isCollected).length],
    ];
    files['Summary_${tabletId}_$stamp.csv'] = formatCsv(summaryRows);

    return files;
  }

  /// The export folder the operator chose last time (Android), if still accessible.
  Future<PickedFolder?> getSavedExportFolder() async {
    if (!_storage.isSupported) return null;
    final uri = await _dbHelper.getSetting(exportFolderSettingKey);
    if (uri == null || uri.isEmpty) return null;
    if (!await _storage.hasAccess(uri)) return null;
    return PickedFolder(uri: uri, label: await _storage.labelFor(uri));
  }

  /// Open the system file explorer to choose an export folder and remember it.
  Future<PickedFolder?> chooseExportFolder() async {
    final folder = await _storage.pickFolder();
    if (folder != null) {
      await _dbHelper.setSetting(exportFolderSettingKey, folder.uri);
    }
    return folder;
  }

  /// Export all CSV files into a folder picked via the system file explorer.
  Future<ExportResult> exportToFolder(PickedFolder folder) async {
    try {
      final files = await buildCsvFiles();
      final written = await _storage.writeTextFiles(folderUri: folder.uri, files: files);
      return ExportResult(
        success: true,
        exportedFiles: written,
        locationLabel: folder.label,
        folderUri: folder.uri,
      );
    } catch (e) {
      return ExportResult(success: false, exportedFiles: const [], errorMessage: e.toString());
    }
  }

  /// Export all tables to the app's private documents folder (fallback / non-Android).
  Future<ExportResult> exportAllCampaignData() async {
    try {
      final files = await buildCsvFiles();
      final exportDir = await getApplicationDocumentsDirectory();
      final exportedPaths = <String>[];
      for (final entry in files.entries) {
        final path = p.join(exportDir.path, entry.key);
        // UTF-8 BOM so Excel shows names and symbols correctly (matches the Android writer).
        await File(path).writeAsString('﻿${entry.value}', encoding: utf8);
        exportedPaths.add(path);
      }
      return ExportResult(
        success: true,
        exportedFiles: exportedPaths,
        locationLabel: exportDir.path,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        exportedFiles: [],
        errorMessage: e.toString(),
      );
    }
  }
}
