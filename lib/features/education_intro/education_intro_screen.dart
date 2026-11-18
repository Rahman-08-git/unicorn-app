/// Education 4.0 explainer: Think · Explore · Discover.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class _Pillar {
  const _Pillar(this.title, this.description, this.example, this.icon, this.color, this.soft);
  final String title, description, example;
  final IconData icon;
  final Color color, soft;
}

const _pillars = [
  _Pillar('THINK', 'Develop reasoning, logic and creative problem-solving.', 'Like asking “why does a paper plane fly?” and testing ideas.',
      Icons.psychology_rounded, AppColors.primaryViolet, AppColors.softViolet),
  _Pillar('EXPLORE', 'Experiment, question and learn by doing.', 'Like building a small robot and seeing what it can do.',
      Icons.travel_explore_rounded, Color(0xFF2563EB), Color(0xFFE8F0FF)),
  _Pillar('DISCOVER', 'Connect knowledge with real-life applications.', 'Like using maths to plan a garden or a school fair.',
      Icons.lightbulb_rounded, Color(0xFFB45309), AppColors.softGold),
];

class EducationIntroScreen extends StatefulWidget {
  const EducationIntroScreen({super.key});

  @override
  State<EducationIntroScreen> createState() => _EducationIntroScreenState();
}

class _EducationIntroScreenState extends State<EducationIntroScreen> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionService>();
    return UllScaffold(
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 800;
        final cards = List.generate(_pillars.length, (i) {
          return FadeSlideIn(
            index: i + 2,
            offset: const Offset(0, 40),
            child: _PillarCard(
              pillar: _pillars[i],
              step: i + 1,
              open: _open == i,
              onTap: () => setState(() => _open = _open == i ? null : i),
            ),
          );
        });

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FadeSlideIn(child: UllPill(text: 'EDUCATION 4.0 PHILOSOPHY', icon: Icons.auto_awesome_rounded)),
                const SizedBox(height: 16),
                const FadeSlideIn(
                  index: 1,
                  child: Text('A DIFFERENT WAY TO LEARN',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.deepInkNavy, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  index: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: const Text(
                      'Learning goes beyond memorising answers. We help learners ask questions, explore ideas and build things of their own.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 17, height: 1.45),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (landscape)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (int i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 22), Expanded(child: cards[i])],
                  ])
                else
                  Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: card)]),
                const SizedBox(height: 30),
                FadeSlideIn(
                  index: 6,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      const UnicornMascot(
                        state: MascotState.learning,
                        width: 240,
                        height: 110,
                        message: 'Tap a card to see an example!',
                        bubbleSide: BubbleSide.right,
                      ),
                      UllButton(label: 'CONTINUE TO FINISH', icon: Icons.arrow_forward_rounded, onPressed: session.goToThankYou),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar, required this.step, required this.open, required this.onTap});
  final _Pillar pillar;
  final int step;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: pillar.title,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.enter,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: open ? pillar.color : AppColors.border, width: 2),
          boxShadow: [
            BoxShadow(color: open ? pillar.color.withOpacity(0.2) : const Color(0x0F101C3A), blurRadius: 26, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: pillar.soft, borderRadius: BorderRadius.circular(20)),
                child: Icon(pillar.icon, color: pillar.color, size: 34),
              ),
              const Spacer(),
              Text('0$step', style: TextStyle(color: pillar.color.withOpacity(0.25), fontSize: 40, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 20),
            Text(pillar.title, style: TextStyle(color: pillar.color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(pillar.description, style: const TextStyle(color: AppColors.primaryText, fontSize: 16, height: 1.4)),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.enter,
              child: open
                  ? Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: pillar.soft, borderRadius: BorderRadius.circular(16)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.tips_and_updates_rounded, color: pillar.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pillar.example, style: const TextStyle(color: AppColors.deepInkNavy, fontSize: 14, height: 1.35))),
                      ]),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
