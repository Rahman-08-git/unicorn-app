// Verifies the operator-dashboard changes reach the visitor's quiz screens:
//  1. a gift renamed in Inventory is the name shown on the results and reward screens,
//  2. a question/options edited in the Question Bank editor are what the quiz shows,
//  3. the CSV export is a readable per-visitor report,
//  4. every reward tier is revealed with the spin wheel (no scratch card).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/router.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/campaign_config.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/question_bank_editor.dart';
import 'package:unicorn_learning_lab/features/quiz/quiz_screen.dart';
import 'package:unicorn_learning_lab/features/results/results_screen.dart';
import 'package:unicorn_learning_lab/features/rewards/reward_reveal_screen.dart';
import 'package:unicorn_learning_lab/services/export_service.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

/// In-memory stand-in for the SQLite helper.
class FakeDb implements DatabaseHelper {
  final CampaignConfig config = CampaignConfig(tabletId: 'TABLET-07', campaignName: 'Test Campaign');
  final List<RewardInventory> inventory = [];
  final List<Participant> participants = [];
  final List<Attempt> attempts = [];
  final List<Answer> answers = [];
  final List<Reward> rewards = [];
  final Map<String, Map<String, Object?>> customQuestions = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CampaignConfig> getCampaignConfig() async => config;
  @override
  Future<void> insertParticipant(Participant participant) async => participants.add(participant);
  @override
  Future<List<Participant>> getAllParticipants() async => participants;
  @override
  Future<void> insertAttempt(Attempt attempt) async => attempts.add(attempt);
  @override
  Future<void> updateAttempt(Attempt attempt) async {
    attempts.removeWhere((a) => a.id == attempt.id);
    attempts.insert(0, attempt);
  }

  @override
  Future<List<Attempt>> getAllAttempts() async => attempts;
  @override
  Future<bool> insertAnswer(Answer answer) async {
    answers.add(answer);
    return true;
  }

  @override
  Future<List<Answer>> getAllAnswers() async => answers;
  @override
  Future<Reward?> getRewardForAttempt(String attemptId) async {
    for (final r in rewards) {
      if (r.attemptId == attemptId) return r;
    }
    return null;
  }

  @override
  Future<List<Reward>> getAllRewards() async => rewards;
  @override
  Future<bool> assignRewardTransaction({required Reward reward, required String inventoryIdentifier}) async {
    rewards.add(reward);
    return true;
  }

  @override
  Future<RewardInventory?> getInventoryItem(String rewardIdentifier) async {
    for (final i in inventory) {
      if (i.rewardIdentifier == rewardIdentifier) return i;
    }
    return null;
  }

  @override
  Future<List<RewardInventory>> getInventoryForType(String rewardType) async =>
      inventory.where((i) => i.rewardType == rewardType).toList();
  @override
  Future<List<RewardInventory>> getAllInventory() async => inventory;

  /// Mirrors the Inventory tab's "Edit gift" save.
  void renameGift(String id, String name) {
    final i = inventory.indexWhere((g) => g.rewardIdentifier == id);
    final g = inventory[i];
    inventory[i] = RewardInventory(
      id: g.id,
      rewardType: g.rewardType,
      rewardIdentifier: g.rewardIdentifier,
      displayName: name,
      configuredStock: g.configuredStock,
      assignedCount: g.assignedCount,
    );
  }

  @override
  Future<List<Map<String, Object?>>> getCustomQuestionRows() async => customQuestions.values.toList();
  @override
  Future<void> upsertCustomQuestion({
    required String id,
    required String audience,
    required String json,
    bool deleted = false,
  }) async {
    customQuestions[id] = {'id': id, 'audience': audience, 'json': json, 'deleted': deleted ? 1 : 0};
  }
}

FakeDb seededDb() {
  final db = FakeDb();
  db.inventory.addAll([
    RewardInventory(rewardType: AppConstants.rewardPremiumGift, rewardIdentifier: 'PREMIUM_DISCOVERY_KIT', displayName: 'Premium Discovery Kit', configuredStock: 5),
    RewardInventory(rewardType: AppConstants.rewardSpinWheel, rewardIdentifier: 'SPIN_WHEEL_GIFT', displayName: 'Spin Wheel Gift', configuredStock: 5),
    RewardInventory(rewardType: AppConstants.rewardSticker, rewardIdentifier: 'UNICORN_STICKER_PACK', displayName: 'Unicorn Sticker Pack', configuredStock: 5),
  ]);
  return db;
}

Widget app(SessionService session, QuestionBankService bank, FakeDb db, {Widget? home}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<QuestionBankService>.value(value: bank),
        Provider<ScoringService>(create: (_) => const ScoringService()),
        Provider<RewardService>(create: (_) => RewardService(dbHelper: db)),
        ChangeNotifierProvider<SessionService>.value(value: session),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home ?? const AppRouter()),
    );

/// Plays the demo quiz through the session, getting [correctCount] answers right.
Future<void> playQuiz(SessionService s, int correctCount) async {
  await s.startDemoQuiz();
  for (var i = 0; i < AppConstants.questionsPerAttempt; i++) {
    final q = s.currentQuestion!;
    final wrong = q.options.firstWhere((o) => o.id != q.correctAnswerId).id;
    await s.submitAnswer(i < correctCount ? q.correctAnswerId : wrong);
    await s.nextQuestionOrResults();
  }
}

/// Taps through chest → spin wheel → revealed card.
Future<void> revealReward(WidgetTester tester) async {
  await tester.tap(find.text('TAP TO OPEN'));
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('SPIN THE WHEEL!'), findsOneWidget, reason: 'every tier shows the spin wheel');
  expect(find.text('SCRATCH TO REVEAL!'), findsNothing);
  await tester.tap(find.text('SPIN THE WHEEL'));
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('YOU EARNED IT!'), findsOneWidget);
}

void main() {
  group('Renamed gifts show on every reward screen (spin wheel for all tiers)', () {
    for (final c in [
      (score: 5, id: 'PREMIUM_DISCOVERY_KIT', name: 'Robotics Starter Kit'),
      (score: 4, id: 'SPIN_WHEEL_GIFT', name: 'Science Puzzle Box'),
      (score: 3, id: 'SPIN_WHEEL_GIFT', name: 'Science Puzzle Box'),
      (score: 1, id: 'UNICORN_STICKER_PACK', name: 'Galaxy Sticker Sheet'),
    ]) {
      testWidgets('score ${c.score} → "${c.name}"', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        final db = seededDb()..renameGift(c.id, c.name);
        final bank = QuestionBankService(dbHelper: db);
        final session = SessionService(dbHelper: db, questionBankService: bank, rewardService: RewardService(dbHelper: db));
        addTearDown(() {
          session.timerService.stopTimer();
          session.dispose();
        });

        await playQuiz(session, c.score);
        expect(session.assignedReward!.rewardIdentifier, c.id);

        await tester.pumpWidget(app(session, bank, db));
        await tester.pump(const Duration(seconds: 3));
        expect(find.byType(ResultsScreen), findsOneWidget);
        expect(find.text(c.name), findsOneWidget, reason: 'results screen shows the renamed gift');

        session.goToRewardReveal();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(RewardRevealScreen), findsOneWidget);
        await revealReward(tester);
        expect(find.text(c.name), findsOneWidget, reason: 'reward card shows the renamed gift');
        expect(find.textContaining(c.name), findsNWidgets(2), reason: 'claim box mentions the renamed gift too');
        // Let the confetti finish so no timers are left pending.
        await tester.pump(const Duration(seconds: 6));
      });
    }
  });

  testWidgets('Question and options edited in the Question Bank editor appear in the quiz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = seededDb();
    final bank = QuestionBankService(dbHelper: db);
    final session = SessionService(dbHelper: db, questionBankService: bank, rewardService: RewardService(dbHelper: db));
    addTearDown(() {
      session.timerService.stopTimer();
      session.dispose();
    });

    final original = bank.getAllQuestionsForAudience('DEMO').first;
    await tester.pumpWidget(app(session, bank, db, home: const QuestionBankEditorScreen(audienceCode: 'DEMO')));
    await tester.pump(const Duration(milliseconds: 300));

    // Open the first question and change its text and option B (making B correct).
    await tester.tap(find.text(original.question));
    await tester.pump(const Duration(milliseconds: 400));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Which robot sorts recycling fastest?');
    await tester.enterText(fields.at(3), 'The one that follows a clear step-by-step plan');
    await tester.tap(find.byType(Radio<String>).at(1));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(db.customQuestions.containsKey(original.id), isTrue, reason: 'edit saved to the tablet');

    // Now a visitor plays the demo quiz: the edited question must be the one shown.
    await session.startDemoQuiz();
    final live = session.activeQuestions.firstWhere((q) => q.id == original.id);
    expect(live.question, 'Which robot sorts recycling fastest?');
    expect(live.options.firstWhere((o) => o.id == 'B').text, 'The one that follows a clear step-by-step plan');
    expect(live.correctAnswerId, 'B');

    await tester.pumpWidget(app(session, bank, db));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(QuizScreen), findsOneWidget);
    var seen = false;
    for (var i = 0; i < AppConstants.questionsPerAttempt; i++) {
      final q = session.currentQuestion!;
      if (q.id == original.id) {
        expect(find.text('Which robot sorts recycling fastest?'), findsOneWidget);
        expect(find.text('The one that follows a clear step-by-step plan'), findsOneWidget);
        // Picking the edited option is scored as correct.
        await tester.tap(find.text('The one that follows a clear step-by-step plan'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(session.recordedAnswers.last.isCorrect, isTrue);
        seen = true;
        break;
      }
      await session.submitAnswer(q.correctAnswerId);
      await session.nextQuestionOrResults();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(seen, isTrue);
    session.timerService.stopTimer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('CSV export is a readable per-visitor report', () async {
    final db = seededDb()..renameGift('SPIN_WHEEL_GIFT', 'Science Puzzle Box');
    final bank = QuestionBankService(dbHelper: db);
    final session = SessionService(dbHelper: db, questionBankService: bank, rewardService: RewardService(dbHelper: db));
    await Future<void>.delayed(Duration.zero);

    await session.registerParentOrGuardian(
      category: AudienceCategory.parent,
      phoneNumber: '9876543210',
      name: 'Priya Sharma',
      consentGiven: true,
    );
    for (var i = 0; i < AppConstants.questionsPerAttempt; i++) {
      final q = session.currentQuestion!;
      final wrong = q.options.firstWhere((o) => o.id != q.correctAnswerId).id;
      await session.submitAnswer(i < 4 ? q.correctAnswerId : wrong);
      await session.nextQuestionOrResults();
    }
    session.resetSessionToWelcome();
    await session.registerStudent(classLevel: 'CLASS_5');
    for (var i = 0; i < AppConstants.questionsPerAttempt; i++) {
      await session.submitAnswer(session.currentQuestion!.correctAnswerId);
      await session.nextQuestionOrResults();
    }
    session.resetSessionToWelcome();
    session.selectAudience(AudienceCategory.student);
    session.submitStudentName('Aarav Kumar');
    await session.registerStudent(classLevel: 'PRE_PRIMARY');
    for (var i = 0; i < AppConstants.questionsPerAttempt; i++) {
      await session.submitAnswer(session.currentQuestion!.correctAnswerId);
      await session.nextQuestionOrResults();
    }
    session.timerService.stopTimer();

    final files = await ExportService(dbHelper: db, questionBank: bank).buildCsvFiles();
    final report = files.entries.firstWhere((e) => e.key.startsWith('Quiz_Report_')).value;
    final lines = report.split('\r\n');

    expect(lines.first, startsWith('No.,Date,Start Time,End Time,Time Taken,Visitor Type,Name,Phone Number,Class'));
    expect(lines.first, contains('Q1 Question,Q1 Visitor Answer,Q1 Correct Answer,Q1 Result'));
    expect(report, contains('Priya Sharma'));
    expect(report, contains('9876543210'));
    expect(report, contains('Parent'));
    expect(report, contains('Class 5'));
    expect(report, contains('Pre-Primary'));
    expect(report, contains('Aarav Kumar'), reason: 'student name from the name screen');
    expect(report, isNot(contains('PRE_PRIMARY')));
    expect(lines.first, isNot(contains('Consent')));
    expect(report, contains('4/5'));
    expect(report, contains('5/5'));
    expect(report, contains(AppConstants.titleScore4));
    expect(report, contains('Science Puzzle Box'));
    expect(report, contains('Not collected yet'));
    final parentQ = bank.getAllQuestionsForAudience('PARENT').first;
    expect(report, contains(parentQ.question), reason: 'question text, not its id');
    expect(report, contains('Correct'));
    expect(report, contains('Wrong'));
    // No raw database ids/codes in the report.
    expect(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(report), isFalse, reason: 'no UUIDs');
    expect(report, isNot(contains('CLASS_5')));
    expect(report, isNot(contains('SPIN_WHEEL')));
    expect(report, isNot(contains('PARENT,')));

    final summary = files.entries.firstWhere((e) => e.key.startsWith('Summary_')).value;
    expect(summary, contains('Total Visitors,3'));
    expect(summary, contains('Quizzes Completed,3'));
    expect(summary, contains('Students - Pre-Primary,1'));

    session.dispose();
  });
}
