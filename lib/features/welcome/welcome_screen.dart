/// Welcome screen — first impression of Unicorn Learning Lab.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/interactive_challenge/robot_puzzle_dialog.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/operator_pin_dialog.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final MascotState _mascotState = MascotState.welcome;
  bool _starting = false;

  void _openOperator() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OperatorPinDialog(),
      );

  void _openChallenge() => showDialog(context: context, builder: (_) => const RobotPuzzleDialog());

  Future<void> _start() async {
    if (_starting) return;
    // The unicorn gallops off ahead of the participant, then the next scene opens.
    setState(() => _starting = true);
    await Future.delayed(Motion.of(context, const Duration(milliseconds: 520)));
    if (mounted) context.read<SessionService>().goToAudienceSelection();
  }

  Future<void> _startDemo() async {
    final session = context.read<SessionService>();
    final ok = await session.startDemoQuiz();
    if (!ok && mounted && session.lastStartError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(session.lastStartError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: UllBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight;
            final mascotSize = landscape
                ? (c.maxHeight * 0.62).clamp(240.0, 460.0)
                : (c.maxWidth * 0.55).clamp(220.0, 400.0);

            final mascot = Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Soft stage the unicorn gallops onto
                Container(
                  width: mascotSize * 1.1,
                  height: mascotSize * 1.1,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFECE8FF)),
                ),
                Positioned(
                  bottom: mascotSize * 0.06,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: mascotSize * 0.12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCD5FF),
                      borderRadius: BorderRadius.all(Radius.elliptical(mascotSize * 0.45, mascotSize * 0.06)),
                    ),
                  ),
                ),
                UnicornMascot(
                  state: _mascotState,
                  width: double.infinity, // whole left stage to wander in
                  height: mascotSize,
                  exiting: _starting,
                  bubbleSide: BubbleSide.none,
                ),
                Positioned(
                  left: -10,
                  top: mascotSize * 0.02,
                  child: AnimatedOpacity(
                    opacity: _starting ? 0 : 1,
                    duration: Motion.base,
                    child: const FadeSlideIn(
                      delay: Duration(milliseconds: 1300),
                      child: SpeechBubble(text: "Hi! I'm Uni. Ready for a little adventure?", maxWidth: 230),
                    ),
                  ),
                ),
                Positioned(
                  right: -8,
                  top: mascotSize * 0.08,
                  child: const FadeSlideIn(delay: Duration(milliseconds: 900), child: _FloatingBadge(icon: Icons.lightbulb_rounded, color: AppColors.warmGold)),
                ),
                Positioned(
                  right: mascotSize * 0.02,
                  bottom: -4,
                  child: const FadeSlideIn(delay: Duration(milliseconds: 1000), child: _FloatingBadge(icon: Icons.rocket_launch_rounded, color: AppColors.primaryViolet)),
                ),
              ],
            );

            final content = _WelcomeCopy(onStart: _start, onDemo: _startDemo, starting: _starting, centered: !landscape);

            return Padding(
              padding: const EdgeInsets.fromLTRB(36, 24, 36, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Flexible(child: BrandMark(onLongPress: _openOperator)),
                      const Spacer(),
                      Tooltip(
                        message: 'Logic Challenge',
                        child: Pressable(
                          onTap: _openChallenge,
                          semanticLabel: 'Try Logic Challenge',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.extension_rounded, color: AppColors.primaryViolet, size: 20),
                                SizedBox(width: 8),
                                Text('Logic', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepInkNavy)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: landscape
                        ? Row(
                            children: [
                              Expanded(flex: 5, child: Center(child: mascot)),
                              const SizedBox(width: 40),
                              Expanded(flex: 6, child: Align(alignment: Alignment.centerLeft, child: content)),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 24),
                                mascot,
                                const SizedBox(height: 40),
                                content,
                              ],
                            ),
                          ),
                  ),
                  const Text(
                    'A little curiosity can lead to big discoveries.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.onStart, required this.onDemo, required this.starting, required this.centered});
  final VoidCallback onStart;
  final VoidCallback onDemo;
  final bool starting;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        const FadeSlideIn(
          index: 0,
          child: UllPill(
            text: '5 QUESTIONS  ·  1 SURPRISE',
            icon: Icons.card_giftcard_rounded,
            color: Color(0xFFB45309),
            background: AppColors.softGold,
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          index: 1,
          child: Text(
            "DON'T JUST LEARN.\nCREATE.",
            textAlign: textAlign,
            style: const TextStyle(
              color: AppColors.deepInkNavy,
              fontSize: 54,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 2,
          child: Text(
            'READY FOR A\nLITTLE ADVENTURE?',
            textAlign: textAlign,
            style: const TextStyle(color: AppColors.primaryViolet, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: 0.4),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          index: 3,
          child: Text(
            'Answer five questions and unlock your surprise.',
            textAlign: textAlign,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 18, height: 1.45),
          ),
        ),
        const SizedBox(height: 34),
        FadeSlideIn(
          index: 4,
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UllButton(
                label: "LET'S PLAY",
                icon: Icons.arrow_forward_rounded,
                height: 68,
                loading: false,
                onPressed: starting ? null : onStart,
              ),
              TextButton.icon(
                onPressed: onDemo,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('DEMO QUIZ (5 Qs)', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 5,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Step(label: 'THINK', color: AppColors.primaryViolet),
              _Dot(),
              _Step(label: 'EXPLORE', color: Color(0xFF2563EB)),
              _Dot(),
              _Step(label: 'DISCOVER', color: Color(0xFFB45309)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13));
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        width: 5,
        height: 5,
        decoration: const BoxDecoration(color: AppColors.border, shape: BoxShape.circle),
      );
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x1A101C3A), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Icon(icon, color: color, size: 30),
      );
}
