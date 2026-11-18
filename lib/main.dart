/// Entry point for Unicorn Learning Lab - Education 4.0.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/router.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/reward_service.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow both landscape and portrait, with landscape preferred for campaign tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Kiosk-style fullscreen for campaign tablets (sticky: swipe reveals bars briefly).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Pre-initialize local database
  final dbHelper = DatabaseHelper.instance;
  try {
    await dbHelper.database;
  } catch (e) {
    debugPrint('Local database unavailable on this platform: $e');
  }

  runApp(const UnicornLearningLabApp());
}

class UnicornLearningLabApp extends StatelessWidget {
  const UnicornLearningLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<QuestionBankService>(
          create: (_) => QuestionBankService(),
        ),
        Provider<ScoringService>(
          create: (_) => const ScoringService(),
        ),
        Provider<RewardService>(
          create: (_) => RewardService(dbHelper: DatabaseHelper.instance),
        ),
        ChangeNotifierProvider<SessionService>(
          create: (ctx) => SessionService(
            dbHelper: DatabaseHelper.instance,
            scoringService: ctx.read<ScoringService>(),
            rewardService: ctx.read<RewardService>(),
            questionBankService: ctx.read<QuestionBankService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Unicorn Learning Lab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Keep layouts stable on tablets with large accessibility font settings.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final scale = mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
          return ValueListenableBuilder<bool>(
            valueListenable: Motion.reducedPref,
            builder: (_, reduced, ___) => MediaQuery(
              data: mq.copyWith(textScaler: scale, disableAnimations: mq.disableAnimations || reduced),
              child: child!,
            ),
          );
        },
        home: const AppRouter(),
      ),
    );
  }
}
