/// Session service managing the overall quiz flow, state transitions,
/// answer recording, reward allocation, and safe session reset.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/campaign_config.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/quiz_timer_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';

enum SessionStage {
  welcome,
  audienceSelection,
  parentRegistration,
  guardianRegistration,
  studentNameEntry,
  studentClassSelection,
  quiz,
  results,
  rewardReveal,
  educationIntro,
  thankYou,
}

class SessionService extends ChangeNotifier {
  SessionService({
    DatabaseHelper? dbHelper,
    ScoringService? scoringService,
    RewardService? rewardService,
    QuestionBankService? questionBankService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _scoringService = scoringService ?? const ScoringService(),
        _rewardService = rewardService ?? RewardService(dbHelper: dbHelper),
        _questionBankService = questionBankService ?? QuestionBankService() {
    _init();
  }

  final DatabaseHelper _dbHelper;
  final ScoringService _scoringService;
  final RewardService _rewardService;
  final QuestionBankService _questionBankService;

  CampaignConfig _config = CampaignConfig();
  CampaignConfig get config => _config;

  SessionStage _currentStage = SessionStage.welcome;
  SessionStage get currentStage => _currentStage;

  Participant? _currentParticipant;
  Participant? get currentParticipant => _currentParticipant;

  Attempt? _currentAttempt;
  Attempt? get currentAttempt => _currentAttempt;

  List<Question> _activeQuestions = [];
  List<Question> get activeQuestions => _activeQuestions;

  int _currentQuestionIndex = 0;
  int get currentQuestionIndex => _currentQuestionIndex;

  Question? get currentQuestion =>
      (_currentQuestionIndex >= 0 && _currentQuestionIndex < _activeQuestions.length)
          ? _activeQuestions[_currentQuestionIndex]
          : null;

  final List<Answer> _recordedAnswers = [];
  List<Answer> get recordedAnswers => List.unmodifiable(_recordedAnswers);

  Reward? _assignedReward;
  Reward? get assignedReward => _assignedReward;

  String? _rewardFallbackMessage;
  String? get rewardFallbackMessage => _rewardFallbackMessage;

  /// Current name of the assigned gift, as set by the operator in the Inventory
  /// tab (looked up when the reward is assigned, so renames always show).
  String? _assignedRewardName;
  String? get assignedRewardName => _assignedRewardName;

  /// Human-readable reason the last quiz could not start (e.g. too few questions).
  String? _lastStartError;
  String? get lastStartError => _lastStartError;

  bool _isAdvancing = false;
  bool _isFinalizing = false;

  bool _isAnswerLocked = false;
  bool get isAnswerLocked => _isAnswerLocked;

  String? _selectedAnswerId;
  String? get selectedAnswerId => _selectedAnswerId;

  QuizTimerService _timerService = QuizTimerService(durationSeconds: 60);
  QuizTimerService get timerService => _timerService;

  VoidCallback? onTimeoutOccurred;

  Timer? _inactivityResetTimer;
  int _inactivitySecondsRemaining = 45;
  int get inactivitySecondsRemaining => _inactivitySecondsRemaining;

  void _onTimerTick() {
    notifyListeners();
  }

  void _setupTimerService(int durationSeconds) {
    _timerService.removeListener(_onTimerTick);
    _timerService.dispose();
    _timerService = QuizTimerService(durationSeconds: durationSeconds);
    _timerService.addListener(_onTimerTick);
  }

  Future<void> _init() async {
    _timerService.addListener(_onTimerTick);
    try {
      _config = await _dbHelper.getCampaignConfig();
      _setupTimerService(_config.timerDurationSeconds);
      notifyListeners();
    } catch (_) {
      // In headless test environments, fallback safely to default config
    }
  }

  Future<void> refreshConfig() async {
    try {
      _config = await _dbHelper.getCampaignConfig();
      _setupTimerService(_config.timerDurationSeconds);
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Flow Navigation & State Transitions
  // ═══════════════════════════════════════════════════════════════════════

  void goToAudienceSelection() {
    _currentStage = SessionStage.audienceSelection;
    notifyListeners();
  }

  void selectAudience(AudienceCategory category) {
    if (category == AudienceCategory.parent) {
      _currentStage = SessionStage.parentRegistration;
    } else if (category == AudienceCategory.guardian) {
      _currentStage = SessionStage.guardianRegistration;
    } else {
      _pendingStudentName = null;
      _currentStage = SessionStage.studentNameEntry;
    }
    notifyListeners();
  }

  /// Name the student typed on the name screen, used when they pick a class.
  String? _pendingStudentName;
  String? get pendingStudentName => _pendingStudentName;

  /// Student name screen → class selection. Pass null/empty to skip the name.
  void submitStudentName(String? name) {
    final trimmed = name?.trim();
    _pendingStudentName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _currentStage = SessionStage.studentClassSelection;
    notifyListeners();
  }

  /// Class selection → back to the student name screen (keeps the typed name).
  void goToStudentNameEntry() {
    _currentStage = SessionStage.studentNameEntry;
    notifyListeners();
  }

  Future<bool> registerParentOrGuardian({
    required AudienceCategory category,
    required String phoneNumber,
    String? name,
    bool consentGiven = false,
  }) async {
    final trimmedName = name?.trim();
    final participant = Participant(
      audienceCategory: category,
      phoneNumber: phoneNumber.trim(),
      name: (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName,
      consentGiven: consentGiven,
    );
    try {
      await _dbHelper.insertParticipant(participant);
    } catch (_) {}
    _currentParticipant = participant;
    return _startQuizSession(audienceCode: category.code);
  }

  Future<bool> registerStudent({required String classLevel, String? name}) async {
    final trimmedName = (name ?? _pendingStudentName)?.trim();
    final participant = Participant(
      audienceCategory: AudienceCategory.student,
      classLevel: classLevel,
      phoneNumber: null, // Privacy: no phone for student
      name: (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName,
    );
    try {
      await _dbHelper.insertParticipant(participant);
    } catch (_) {}
    _currentParticipant = participant;
    return _startQuizSession(audienceCode: classLevel);
  }

  Future<bool> startDemoQuiz() async {
    final participant = Participant(
      audienceCategory: AudienceCategory.student,
      classLevel: 'DEMO',
      phoneNumber: null,
      name: 'Demo Explorer',
    );
    try {
      await _dbHelper.insertParticipant(participant);
    } catch (_) {}
    _currentParticipant = participant;
    return _startQuizSession(audienceCode: 'DEMO');
  }

  Future<bool> _startQuizSession({required String audienceCode}) async {
    try {
      _config = await _dbHelper.getCampaignConfig();
    } catch (_) {}
    _lastStartError = null;
    // Validate the bank BEFORE starting: never begin a quiz that cannot finish.
    try {
      _activeQuestions = _questionBankService.selectQuestionsForAttempt(
        audienceCode,
        count: AppConstants.questionsPerAttempt,
      );
    } on StateError {
      _lastStartError =
          'This challenge is not ready yet. Please ask a staff member for help.';
      _activeQuestions = [];
      notifyListeners();
      return false;
    }
    _isAdvancing = false;
    _isFinalizing = false;
    _rewardFallbackMessage = null;
    _assignedRewardName = null;
    _currentQuestionIndex = 0;
    _recordedAnswers.clear();
    _assignedReward = null;
    _isAnswerLocked = false;
    _selectedAnswerId = null;

    final attempt = Attempt(
      participantId: _currentParticipant?.id ?? 'demo_p_id',
      campaignId: _config.campaignId,
      tabletId: _config.tabletId,
      audienceCategory: _currentParticipant?.audienceCategory.code ?? 'STUDENT',
      classLevel: _currentParticipant?.classLevel,
      questionBankVersion: _questionBankService.activeVersion,
    );
    try {
      await _dbHelper.insertAttempt(attempt);
    } catch (_) {}
    _currentAttempt = attempt;

    _currentStage = SessionStage.quiz;
    _startCurrentQuestionTimer();
    notifyListeners();
    return true;
  }

  void _startCurrentQuestionTimer() {
    _isAnswerLocked = false;
    _selectedAnswerId = null;
    _timerService.startTimer(timeoutCallback: () {
      handleTimeout();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Quiz Interaction
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> submitAnswer(String answerId) async {
    if (_isAnswerLocked || _timerService.isExpired || currentQuestion == null) {
      return; // Lock prevents duplicate submissions
    }
    _isAnswerLocked = true;
    _selectedAnswerId = answerId;
    _timerService.stopTimer();

    final q = currentQuestion!;
    final isCorrect = (answerId.trim().toUpperCase() == q.correctAnswerId.trim().toUpperCase());
    final timeTaken = _config.timerDurationSeconds - _timerService.remainingSeconds;

    final answer = Answer(
      attemptId: _currentAttempt!.id,
      questionId: q.id,
      selectedAnswerId: answerId,
      correctAnswerId: q.correctAnswerId,
      isCorrect: isCorrect,
      isTimeout: false,
      timeTakenSeconds: timeTaken,
      questionSequence: _currentQuestionIndex + 1,
    );

    try {
      await _dbHelper.insertAnswer(answer);
    } catch (_) {}
    _recordedAnswers.add(answer);
    notifyListeners();
  }

  Future<void> handleTimeout() async {
    if (_isAnswerLocked || currentQuestion == null) return;
    _isAnswerLocked = true;
    _selectedAnswerId = null;
    _timerService.stopTimer();

    final q = currentQuestion!;
    final answer = Answer(
      attemptId: _currentAttempt?.id ?? 'attempt_test',
      questionId: q.id,
      selectedAnswerId: null,
      correctAnswerId: q.correctAnswerId,
      isCorrect: false,
      isTimeout: true,
      timeTakenSeconds: _config.timerDurationSeconds,
      questionSequence: _currentQuestionIndex + 1,
    );

    try {
      await _dbHelper.insertAnswer(answer);
    } catch (_) {}
    _recordedAnswers.add(answer);
    notifyListeners();
    onTimeoutOccurred?.call();
  }

  /// Advance to next question or to results.
  Future<void> nextQuestionOrResults() async {
    // Guard: only advance once per answered question (prevents double-tap skips).
    if (_isAdvancing || !_isAnswerLocked || _currentStage != SessionStage.quiz) return;
    if (_recordedAnswers.length < _currentQuestionIndex + 1) return;
    _isAdvancing = true;
    try {
      if (_currentQuestionIndex + 1 < _activeQuestions.length) {
        _currentQuestionIndex++;
        _startCurrentQuestionTimer();
        notifyListeners();
      } else {
        await _finalizeAttempt();
      }
    } finally {
      _isAdvancing = false;
    }
  }

  Future<void> _finalizeAttempt() async {
    if (_isFinalizing) return;
    _isFinalizing = true;
    _timerService.stopTimer();
    final correctList = _recordedAnswers.map((a) => a.isCorrect).toList();
    final finalScore = _scoringService.calculateScore(correctList);

    // Update attempt
    final updatedAttempt = Attempt(
      id: _currentAttempt!.id,
      participantId: _currentAttempt!.participantId,
      campaignId: _currentAttempt!.campaignId,
      tabletId: _currentAttempt!.tabletId,
      audienceCategory: _currentAttempt!.audienceCategory,
      classLevel: _currentAttempt!.classLevel,
      startedAt: _currentAttempt!.startedAt,
      completedAt: DateTime.now(),
      score: finalScore,
      totalQuestions: AppConstants.questionsPerAttempt,
      questionBankVersion: _currentAttempt!.questionBankVersion,
      status: AttemptStatus.completed,
    );
    try {
      await _dbHelper.updateAttempt(updatedAttempt);
    } catch (_) {}
    _currentAttempt = updatedAttempt;

    // Persist reward BEFORE reveal screen
    try {
      final rewardResult = await _rewardService.assignRewardForAttempt(
        attemptId: _currentAttempt!.id,
        score: finalScore,
      );
      _assignedReward = rewardResult.reward;
      _rewardFallbackMessage = rewardResult.fallbackMessage;
    } catch (_) {}
    _assignedRewardName = await _lookUpGiftName(_assignedReward?.rewardIdentifier);

    _currentStage = SessionStage.results;
    notifyListeners();
  }

  /// The operator-edited display name of a gift, or null if it can't be found.
  Future<String?> _lookUpGiftName(String? rewardIdentifier) async {
    if (rewardIdentifier == null) return null;
    try {
      final item = await _dbHelper.getInventoryItem(rewardIdentifier);
      final name = item?.displayName.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (_) {
      return null;
    }
  }

  void goToRewardReveal() {
    _currentStage = SessionStage.rewardReveal;
    notifyListeners();
  }

  void goToEducationIntro() {
    _currentStage = SessionStage.educationIntro;
    notifyListeners();
  }

  void goToThankYou() {
    _currentStage = SessionStage.thankYou;
    _startInactivityTimer();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Inactivity Auto-Reset & Safe Session Teardown
  // ═══════════════════════════════════════════════════════════════════════

  void _startInactivityTimer() {
    _inactivityResetTimer?.cancel();
    _inactivitySecondsRemaining = _config.sessionResetSeconds;

    _inactivityResetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_inactivitySecondsRemaining > 1) {
        _inactivitySecondsRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        resetSessionToWelcome();
      }
    });
  }

  /// Wipes all in-memory participant, answers, and attempt references
  /// so that the next user starts completely fresh with no visible prior data.
  void resetSessionToWelcome() {
    _inactivityResetTimer?.cancel();
    _inactivityResetTimer = null;
    _timerService.stopTimer();

    _currentParticipant = null;
    _pendingStudentName = null;
    _currentAttempt = null;
    _activeQuestions.clear();
    _recordedAnswers.clear();
    _assignedReward = null;
    _rewardFallbackMessage = null;
    _assignedRewardName = null;
    _lastStartError = null;
    _isAnswerLocked = false;
    _isAdvancing = false;
    _isFinalizing = false;
    _selectedAnswerId = null;
    _currentQuestionIndex = 0;

    _currentStage = SessionStage.welcome;
    notifyListeners();
  }

  @override
  void dispose() {
    _inactivityResetTimer?.cancel();
    _timerService.removeListener(_onTimerTick);
    _timerService.dispose();
    super.dispose();
  }
}
