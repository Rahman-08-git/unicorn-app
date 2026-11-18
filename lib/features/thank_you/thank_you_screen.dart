/// Thank-you / farewell screen with auto-reset countdown.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final total = session.config.sessionResetSeconds <= 0 ? 1 : session.config.sessionResetSeconds;
    final remaining = session.inactivitySecondsRemaining;

    return UllScaffold(
      tint: AppColors.softGold,
      accent: AppColors.softViolet,
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 800;
        final mascot = FadeSlideIn(
          child: UnicornMascot(
            state: MascotState.goodbye,
            width: double.infinity,
            height: landscape ? 294 : 190,
            message: 'Bye for now, explorer! See you on the next adventure!',
          ),
        );

        final copy = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            const FadeSlideIn(index: 1, child: UllPill(text: 'THINK. EXPLORE. DISCOVER.', icon: Icons.favorite_rounded)),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 2,
              child: Text(
                'THANKS FOR EXPLORING WITH US!',
                textAlign: landscape ? TextAlign.start : TextAlign.center,
                style: const TextStyle(color: AppColors.deepInkNavy, fontSize: 42, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -0.6),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 3,
              child: Text(
                'Learning is an adventure.\nKeep thinking, keep exploring, and keep discovering.',
                textAlign: landscape ? TextAlign.start : TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 18, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
            FadeSlideIn(
              index: 4,
              child: UllButton(
                label: 'FINISH & START NEW SESSION',
                leadingIcon: Icons.replay_rounded,
                onPressed: session.resetSessionToWelcome,
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              index: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: remaining / total),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, v, __) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 3,
                        color: AppColors.primaryViolet,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Session resets in ${remaining}s',
                      style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        );

        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: landscape
                  ? Row(children: [
                      Expanded(flex: 4, child: Center(child: mascot)),
                      const SizedBox(width: 48),
                      Expanded(flex: 6, child: copy),
                    ])
                  : Column(children: [mascot, const SizedBox(height: 28), copy]),
            ),
          ),
        );
      }),
    );
  }
}
