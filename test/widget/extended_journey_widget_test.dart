import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/router.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/operator_pin_dialog.dart';
import 'package:unicorn_learning_lab/features/registration/registration_screen.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

Widget createTestAppWithCustomSession(SessionService sessionService, {Widget? home}) {
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
      home: home ?? const AppRouter(),
    ),
  );
}

void main() {
  group('Operator PIN Dialog Tests', () {
    testWidgets('Incorrect PIN shows error, correct PIN resolves true', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      final session = SessionService();

      await tester.pumpWidget(
        createTestAppWithCustomSession(
          session,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await showDialog<bool>(
                      context: ctx,
                      barrierDismissible: false,
                      builder: (_) => const OperatorPinDialog(),
                    );
                  },
                  child: const Text('OPEN PIN'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('OPEN PIN'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Operator Access'), findsOneWidget);

      // Enter incorrect PIN: '9999'
      await tester.enterText(find.byType(TextField), '9999');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Unlock'));
      await tester.pump(const Duration(milliseconds: 100));

      // Error message should appear
      expect(find.text('Incorrect PIN. Attempts remaining: 4'), findsOneWidget);

      // Clear and enter correct default PIN: '1234'
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Unlock'));
      // Route transition
      await tester.pump(const Duration(milliseconds: 600));

      // After correct unlock, the Operator Dashboard Screen is pushed!
      expect(find.text('Operator Dashboard'), findsOneWidget);
      session.dispose();
    });
  });

  group('Parent Registration Form Validation', () {
    testWidgets('Requires a name and a valid 10-digit Indian mobile number; no consent checkbox', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      final session = SessionService();

      await tester.pumpWidget(
        createTestAppWithCustomSession(
          session,
          home: const RegistrationScreen(category: AudienceCategory.parent),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Parent Pathway'), findsOneWidget);
      expect(find.text("LET'S GET STARTED"), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);

      // Button is disabled initially because phone field is empty
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.enabled, isFalse);

      // Enter invalid phone: 5 digits
      await tester.enterText(find.byKey(const ValueKey('registration_phone')), '12345');
      await tester.pump(const Duration(milliseconds: 50));
      final buttonAfter5Digits = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttonAfter5Digits.enabled, isFalse);

      // Enter valid phone: 10 digits — still disabled, the name is required
      await tester.enterText(find.byKey(const ValueKey('registration_phone')), '9876543210');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled, isFalse);

      // Enter a name: now enabled
      await tester.enterText(find.byKey(const ValueKey('registration_name')), 'Priya Sharma');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled, isTrue);

      // A blank name doesn't count
      await tester.enterText(find.byKey(const ValueKey('registration_name')), '   ');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled, isFalse);

      // No consent checkbox, and the name is no longer marked optional
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('educational insights'), findsNothing);
      expect(find.textContaining('optional'), findsNothing);

      session.dispose();
    });
  });

  group('Responsive Layout Verification across Tablet Aspect Ratios', () {
    final tabletResolutions = [
      {'name': '4:3 Aspect Ratio (1024x768 iPad/Galaxy Tab)', 'size': const Size(1024, 768)},
      {'name': '16:10 Aspect Ratio (1280x800 WXGA Tablet)', 'size': const Size(1280, 800)},
      {'name': '16:9 Aspect Ratio (1920x1080 FHD Tablet)', 'size': const Size(1920, 1080)},
    ];

    for (final res in tabletResolutions) {
      testWidgets('Renders Welcome and Audience cleanly on ${res['name']}', (tester) async {
        final size = res['size'] as Size;
        await tester.binding.setSurfaceSize(size);
        final session = SessionService();

        await tester.pumpWidget(createTestAppWithCustomSession(session));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify no overflow
        expect(tester.takeException(), isNull);
        expect(find.text('UNICORN LEARNING LAB'), findsOneWidget);

        // Advance to Audience Selection
        await tester.tap(find.text("LET'S PLAY"));
        // Unicorn gallops off first (~520 ms), then the next scene opens.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(find.text('PARENT'), findsOneWidget);
        expect(find.text('STUDENT'), findsOneWidget);
        expect(find.text('GUARDIAN'), findsOneWidget);

        session.dispose();
      });
    }
  });
}
