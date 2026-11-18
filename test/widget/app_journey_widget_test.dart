import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/router.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

Widget createTestApp(SessionService sessionService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<QuestionBankService>(
        create: (_) => QuestionBankService(),
      ),
      Provider<ScoringService>(
        create: (_) => const ScoringService(),
      ),
      Provider<RewardService>(
        create: (_) => RewardService(),
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
  group('Unicorn Learning Lab Widget Tests', () {
    late SessionService sessionService;

    setUp(() {
      sessionService = SessionService();
    });

    tearDown(() {
      sessionService.dispose();
    });

    testWidgets('Welcome screen renders brand identity and Unicorn mascot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768)); // Landscape tablet

      await tester.pumpWidget(createTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UNICORN LEARNING LAB'), findsOneWidget);
      expect(find.text('EDUCATION 4.0'), findsOneWidget);
      expect(find.text('READY FOR A\nLITTLE ADVENTURE?'), findsOneWidget);
      expect(find.text("LET'S PLAY"), findsOneWidget);
      expect(find.byType(UnicornMascot), findsOneWidget);
    });

    testWidgets('Tapping LET\'S PLAY navigates to Audience Selection with 3 cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(createTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text("LET'S PLAY"));
      // Unicorn gallops off first (~520 ms), then the next scene opens.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text("WHO'S JOINING THE ADVENTURE?"), findsOneWidget);
      expect(find.text('PARENT'), findsOneWidget);
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('GUARDIAN'), findsOneWidget);
    });

    testWidgets('Student selection opens Class Selection name screen, then Class Selection grid with 14 levels', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(createTestApp(sessionService));
      await tester.pump(const Duration(milliseconds: 100));

      // Go to audience selection
      await tester.tap(find.text("LET'S PLAY"));
      // Unicorn gallops off first (~520 ms), then the next scene opens.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));

      // Select student
      await tester.tap(find.text('STUDENT'));
      await tester.pump(const Duration(milliseconds: 450));

      // Name screen comes first; Next is disabled until a name is typed.
      expect(find.text("WHAT'S YOUR NAME?"), findsOneWidget);
      final nextBtn = find.ancestor(of: find.text('NEXT: CHOOSE YOUR CLASS'), matching: find.byType(ElevatedButton));
      expect(tester.widget<ElevatedButton>(nextBtn).enabled, isFalse);
      await tester.enterText(find.byKey(const ValueKey('student_name')), 'Aarav Kumar');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ElevatedButton>(nextBtn).enabled, isTrue);
      await tester.tap(find.text('NEXT: CHOOSE YOUR CLASS'));
      await tester.pump(const Duration(milliseconds: 450));
      expect(sessionService.pendingStudentName, 'Aarav Kumar');

      expect(find.text('WHAT ARE YOU STUDYING?'), findsOneWidget);
      expect(find.text('Pre-Primary'), findsOneWidget);
      expect(find.text('Class 1'), findsOneWidget);
      expect(find.text('Class 5'), findsOneWidget);
      expect(find.text('Class 12'), findsOneWidget);
      expect(find.text('College'), findsOneWidget);

      // Start button is disabled initially
      expect(find.text('SELECT YOUR CLASS TO START'), findsOneWidget);

      // Tap Class 5
      await tester.tap(find.text('Class 5'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('START CLASS 5 CHALLENGE'), findsOneWidget);
    });
  });
}
