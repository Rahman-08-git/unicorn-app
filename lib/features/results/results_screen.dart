/// Results: score count-up, title reveal, breakdown, reward eligibility.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/scoring_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  /// Fallback label for a reward tier, used only when the gift's name is unknown.
  static String rewardLabel(String? type) {
    switch (type) {
      case AppConstants.rewardPremiumGift:
        return 'Premium Discovery Gift';
      case AppConstants.rewardScratchCard: // legacy tier, now part of the spin wheel tier
      case AppConstants.rewardSpinWheel:
        return 'Spin Wheel Surprise';
      default:
        return 'Explorer Sticker Pack';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final score = session.currentAttempt?.score ?? 0;
    const total = AppConstants.questionsPerAttempt;
    final outcome = const ScoringService().evaluateOutcome(score);
    final pct = (score / total * 100).round();
    final high = score >= 4;
    final accent = score == 5 ? const Color(0xFFB45309) : (score >= 3 ? AppColors.primaryViolet : const Color(0xFF2563EB));
    final mascotMsg = score == 5
        ? 'A perfect score! You are a true champion!'
        : (score >= 3 ? 'Wow, great thinking out there!' : 'I loved exploring with you! Curiosity is a superpower.');

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: UllBackground(
        tint: score == 5 ? AppColors.softGold : AppColors.softViolet,
        accent: AppColors.softViolet,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(builder: (context, c) {
                final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 800;
                final mascot = FadeSlideIn(
                  child: UnicornMascot(
                    state: score >= 3 ? MascotState.celebration : MascotState.encouraging,
                    width: double.infinity,
                    height: landscape ? 262 : 150,
                    message: mascotMsg,
                    bubbleSide: BubbleSide.top,
                  ),
                );

                final card = UllCard(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: _ScoreDial(score: score, total: total, color: accent),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 900),
                        scaleFrom: 0.8,
                        child: UllPill(
                          text: outcome.title,
                          icon: Icons.workspace_premium_rounded,
                          color: accent,
                          background: accent.withOpacity(0.1),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 1000),
                        child: Text(
                          '$score OUT OF $total!',
                          style: const TextStyle(color: AppColors.deepInkNavy, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 1050),
                        child: Text('$pct% correct', style: const TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 1100),
                        child: Text(
                          outcome.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 17, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(session.recordedAnswers.length, (i) {
                          final a = session.recordedAnswers[i];
                          final col = a.isCorrect ? AppColors.success : (a.isTimeout ? const Color(0xFFD97706) : const Color(0xFFF97066));
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 1200 + i * 90),
                            scaleFrom: 0.6,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(a.isCorrect ? Icons.check_rounded : (a.isTimeout ? Icons.timer_off_rounded : Icons.close_rounded), color: col, size: 20),
                                  const SizedBox(width: 4),
                                  Text('Q${i + 1}', style: TextStyle(color: col, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 1500),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.softGold, borderRadius: BorderRadius.circular(18)),
                          child: Row(
                            children: [
                              const Icon(Icons.redeem_rounded, color: Color(0xFFB45309), size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('YOU UNLOCKED', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4)),
                                    Text(
                                      session.assignedRewardName ?? rewardLabel(session.assignedReward?.rewardType ?? outcome.rewardType),
                                      style: const TextStyle(color: AppColors.deepInkNavy, fontWeight: FontWeight.w800, fontSize: 17),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 1600),
                        child: UllButton(
                          label: 'UNLOCK YOUR REWARD',
                          leadingIcon: Icons.card_giftcard_rounded,
                          expand: true,
                          color: AppColors.primaryViolet,
                          onPressed: session.goToRewardReveal,
                        ),
                      ),
                    ],
                  ),
                );

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: landscape
                          ? Row(
                              children: [
                                Expanded(flex: 4, child: mascot),
                                const SizedBox(width: 32),
                                Expanded(flex: 6, child: card),
                              ],
                            )
                          : Column(children: [mascot, const SizedBox(height: 24), card]),
                    ),
                  ),
                );
              }),
            ),
            if (high) const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.score, required this.total, required this.color});
  final int score;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / total),
      duration: Motion.of(context, const Duration(milliseconds: 1200)),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: _DialPainter(v, color),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${(v * total).round()}', style: TextStyle(color: color, fontSize: 60, fontWeight: FontWeight.w900, height: 1)),
                Text('/$total', style: const TextStyle(color: AppColors.secondaryText, fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    final base = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(c, r, base);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.v != v || old.color != color;
}
