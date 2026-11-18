import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/router.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/campaign_config.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';
import 'package:unicorn_learning_lab/features/quiz/quiz_screen.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class MockDatabaseHelper implements DatabaseHelper {
  final CampaignConfig _config = CampaignConfig();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CampaignConfig> getCampaignConfig() async => _config;

  @override
  Future<void> insertParticipant(Participant participant) async {}

  @override
  Future<void> insertAttempt(Attempt attempt) async {}

  @override
  Future<bool> insertAnswer(Answer answer) async => true;

  @override
  Future<void> updateAttempt(Attempt attempt) async {}

  @override
  Future<Reward?> getRewardForAttempt(String attemptId) async => null;

  @override
  Future<bool> assignRewardTransaction({
    required Reward reward,
    required String inventoryIdentifier,
  }) async => true;

  @override
  Future<RewardInventory?> getInventoryItem(String rewardIdentifier) async => null;

  @override
  Future<List<RewardInventory>> getInventoryForType(String rewardType) async => [];

  @override
  Future<List<Map<String, Object?>>> getCustomQuestionRows() async => [];
}

Widget createQuizTestApp(SessionService sessionService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<QuestionBankService>(
        create: (_) => QuestionBankService(),
      ),
      Provider<ScoringService>(
        create: (_) => const ScoringService(),
      ),
      Provider<RewardService>(
        create: (_) => RewardService(dbHelper: MockDatabaseHelper()),
      ),
      ChangeNotifierProvider<SessionService>.value(
        value: sessionService,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AppRouter(),
    ),
  );
}

void main() {
  group('Demo Quiz and Bug Fix Verification Tests', () {
    late SessionService sessionService;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      sessionService = SessionService(dbHelper: mockDb);
    });

    tearDown(() {
      sessionService.timerService.stopTimer();
      sessionService.dispose();
    });

    testWidgets('Demo Quiz button starts 5 demo questions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(createQuizTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DEMO QUIZ (5 Qs)'), findsOneWidget);

      // Start demo quiz
      await sessionService.startDemoQuiz();
      await tester.pump(const Duration(milliseconds: 200));

      // Quiz Screen should now be active
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('QUESTION 1 OF 5'), findsOneWidget);
      expect(sessionService.activeQuestions.length, 5);
      expect(sessionService.currentParticipant?.classLevel, 'DEMO');

      sessionService.timerService.stopTimer();
    });

    testWidgets('Welcome Screen renders safely in Portrait mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpWidget(createQuizTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('DEMO QUIZ (5 Qs)'), findsOneWidget);
    });

    testWidgets('Quiz Screen renders safely in Portrait mode without unbounded flex crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024)); // Portrait tablet

      // Start demo quiz before pumping so it mounts directly to QuizScreen
      await sessionService.startDemoQuiz();

      await tester.pumpWidget(createQuizTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('QUESTION 1 OF 5'), findsOneWidget);

      sessionService.timerService.stopTimer();
    });

    testWidgets('Answer submission shows feedback dialog and advances to Question 2', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(createQuizTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      await sessionService.startDemoQuiz();
      await tester.pump(const Duration(milliseconds: 200));

      // Answer first question
      final q1 = sessionService.currentQuestion!;
      final correctOpt = q1.options.firstWhere((o) => o.id == q1.correctAnswerId);
      await tester.tap(find.text(correctOpt.text));
      await tester.pump(const Duration(milliseconds: 150));

      // Feedback dialog should appear
      expect(find.text('Excellent Thinking!'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to advance
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 200));

      // Should now be at Question 2
      expect(find.text('QUESTION 2 OF 5'), findsOneWidget);
      expect(sessionService.currentQuestionIndex, 1);

      sessionService.timerService.stopTimer();
    });

    testWidgets('Question Timeout shows Time Up dialog and does not hang', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(createQuizTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      await sessionService.startDemoQuiz();
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger timeout
      await sessionService.handleTimeout();
      await tester.pump(const Duration(milliseconds: 150));

      // Timeout dialog should appear
      expect(find.text("Time's Up!"), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 200));

      // Should advance safely to Question 2
      expect(find.text('QUESTION 2 OF 5'), findsOneWidget);

      sessionService.timerService.stopTimer();
    });
  });
}
