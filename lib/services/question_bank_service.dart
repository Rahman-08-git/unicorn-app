/// Question bank service managing question banks, shuffling, validation, and JSON import/export.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/data/question_banks/default_questions.dart';

class QuestionBankValidationResult {
  const QuestionBankValidationResult({
    required this.isValid,
    required this.activeCount,
    required this.errors,
  });

  final bool isValid;
  final int activeCount;
  final List<String> errors;
}

class QuestionBankService extends ChangeNotifier {
  /// [dbHelper] is used to persist operator edits. Pass `loadCustomEdits: false`
  /// (e.g. in unit tests) to use only the built-in questions.
  QuestionBankService({DatabaseHelper? dbHelper, bool loadCustomEdits = true})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    _loadDefaultQuestions();
    if (loadCustomEdits) {
      loadCustomEditsFromStorage();
    }
  }

  final DatabaseHelper _dbHelper;
  final Map<String, List<Question>> _questionBanks = {};
  String _activeVersion = DefaultQuestions.version;

  /// IDs of the built-in questions, used to tell "edited" from "added".
  final Set<String> _builtInIds = {};

  String get activeVersion => _activeVersion;

  void _loadDefaultQuestions() {
    _questionBanks.clear();
    _builtInIds.clear();
    for (final q in DefaultQuestions.allQuestions) {
      final aud = q.audience.toUpperCase();
      _questionBanks.putIfAbsent(aud, () => []).add(q);
      _builtInIds.add(q.id);
    }
    notifyListeners();
  }

  /// Re-apply operator edits saved on this tablet over the built-in bank.
  Future<void> loadCustomEditsFromStorage() async {
    List<Map<String, Object?>> rows;
    try {
      rows = await _dbHelper.getCustomQuestionRows();
    } catch (e) {
      debugPrint('Custom questions unavailable: $e');
      return;
    }
    _loadDefaultQuestions();
    for (final row in rows) {
      final id = row['id'] as String;
      final deleted = (row['deleted'] as int? ?? 0) == 1;
      _removeFromBanks(id);
      if (deleted) continue;
      try {
        final q = Question.fromJson(json.decode(row['json'] as String) as Map<String, dynamic>);
        _questionBanks.putIfAbsent(q.audience.toUpperCase(), () => []).add(q);
      } catch (e) {
        debugPrint('Skipping malformed custom question $id: $e');
      }
    }
    notifyListeners();
  }

  void _removeFromBanks(String id) {
    for (final list in _questionBanks.values) {
      list.removeWhere((q) => q.id == id);
    }
  }

  /// All questions (active and inactive) for an audience, for the editor.
  List<Question> getAllQuestionsForAudience(String audienceCode) {
    return List.unmodifiable(_questionBanks[audienceCode.toUpperCase()] ?? const []);
  }

  bool isBuiltIn(String questionId) => _builtInIds.contains(questionId);

  /// Generate a new unique question id for an audience.
  String newQuestionId(String audienceCode) {
    final prefix = audienceCode.toLowerCase();
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '${prefix}_custom_$stamp';
  }

  /// Add a new question or replace an existing one (matched by id). Persists to the tablet.
  /// Throws [ArgumentError] if the question is malformed.
  Future<void> saveQuestion(Question question) async {
    if (!question.isValid()) {
      throw ArgumentError('Question needs text, 4 options with unique IDs, and a correct answer.');
    }
    final aud = question.audience.toUpperCase();
    final list = _questionBanks.putIfAbsent(aud, () => []);
    final idx = list.indexWhere((q) => q.id == question.id);
    if (idx >= 0) {
      list[idx] = question;
    } else {
      _removeFromBanks(question.id); // in case the audience changed
      list.add(question);
    }
    notifyListeners();
    try {
      await _dbHelper.upsertCustomQuestion(
        id: question.id,
        audience: aud,
        json: json.encode(question.toJson()),
      );
    } catch (e) {
      debugPrint('Could not persist question ${question.id}: $e');
    }
  }

  /// Delete a question. Built-in questions are hidden via a tombstone so they stay deleted.
  Future<void> deleteQuestion(Question question) async {
    _removeFromBanks(question.id);
    notifyListeners();
    try {
      if (isBuiltIn(question.id)) {
        await _dbHelper.upsertCustomQuestion(
          id: question.id,
          audience: question.audience.toUpperCase(),
          json: json.encode(question.toJson()),
          deleted: true,
        );
      } else {
        await _dbHelper.deleteCustomQuestionRow(question.id);
      }
    } catch (e) {
      debugPrint('Could not persist deletion of ${question.id}: $e');
    }
  }

  /// Undo all edits for one built-in question (restores the original version).
  Future<void> restoreBuiltIn(String questionId) async {
    try {
      await _dbHelper.deleteCustomQuestionRow(questionId);
    } catch (_) {}
    await loadCustomEditsFromStorage();
  }

  /// Get active questions for an audience category code (e.g. 'PARENT', 'CLASS_5', etc.)
  List<Question> getActiveQuestionsForAudience(String audienceCode) {
    final list = _questionBanks[audienceCode.toUpperCase()] ?? [];
    return list.where((q) => q.active && q.isValid()).toList();
  }

  /// Total count of all questions in memory.
  int get totalQuestionCount {
    int total = 0;
    for (final list in _questionBanks.values) {
      total += list.length;
    }
    return total;
  }

  /// Get audience categories registered in the question bank.
  List<String> get configuredAudienceCategories => _questionBanks.keys.toList();

  /// Validate an audience category question bank.
  /// Minimum 5 active valid questions required.
  QuestionBankValidationResult validateAudienceBank(String audienceCode) {
    final questions = _questionBanks[audienceCode.toUpperCase()] ?? [];
    final errors = <String>[];
    int activeValidCount = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (!q.isValid()) {
        errors.add('Question #${i + 1} (${q.id}) is malformed (missing text, invalid options, or unmatched correct answer).');
      } else if (q.active) {
        activeValidCount++;
      }
    }

    if (activeValidCount < 5) {
      errors.add('Audience "$audienceCode" has only $activeValidCount valid active questions. Minimum required is 5.');
    }

    return QuestionBankValidationResult(
      isValid: errors.isEmpty,
      activeCount: activeValidCount,
      errors: errors,
    );
  }

  /// Select 5 randomised questions for a quiz attempt, with shuffled options.
  /// Guarantees that answer shuffling does not alter correctness identification.
  List<Question> selectQuestionsForAttempt(String audienceCode, {int count = 5}) {
    final pool = List<Question>.from(getActiveQuestionsForAudience(audienceCode));
    if (pool.length < count) {
      throw StateError(
        'Insufficient active questions for category "$audienceCode". Available: ${pool.length}, required: $count.',
      );
    }

    final random = Random();
    pool.shuffle(random);
    final selected = pool.take(count).toList();

    // Now shuffle options for each question without altering correct option ID
    final preparedQuestions = <Question>[];
    for (final q in selected) {
      final shuffledOptions = List<QuestionOption>.from(q.options)..shuffle(random);
      preparedQuestions.add(
        Question(
          id: q.id,
          audience: q.audience,
          question: q.question,
          description: q.description,
          options: shuffledOptions,
          correctAnswerId: q.correctAnswerId, // Stable identifier
          explanation: q.explanation,
          difficulty: q.difficulty,
          topic: q.topic,
          active: q.active,
          version: q.version,
        ),
      );
    }

    return preparedQuestions;
  }

  /// Export all current question banks to a JSON string.
  String exportToJson() {
    final allList = <Map<String, dynamic>>[];
    for (final list in _questionBanks.values) {
      for (final q in list) {
        allList.add(q.toJson());
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'version': _activeVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'questions': allList,
    });
  }

  /// Import questions from a validated JSON string.
  /// Rejects import if any category has fewer than 5 active questions or contains malformed data.
  bool importFromJson(String jsonString) {
    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      final questionsRaw = decoded['questions'] as List<dynamic>? ?? [];
      final version = decoded['version'] as String? ?? 'custom';

      final tempBanks = <String, List<Question>>{};

      for (final item in questionsRaw) {
        final q = Question.fromJson(item as Map<String, dynamic>);
        if (!q.isValid()) {
          // Reject entire import if any question is malformed
          return false;
        }
        tempBanks.putIfAbsent(q.audience.toUpperCase(), () => []).add(q);
      }

      // Check minimum 5 active questions per category in the new bank
      for (final entry in tempBanks.entries) {
        final activeCount = entry.value.where((q) => q.active).length;
        if (activeCount < 5) {
          return false; // Insufficient active questions in imported category
        }
      }

      // Safe update
      _questionBanks.clear();
      _questionBanks.addAll(tempBanks);
      _activeVersion = version;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
