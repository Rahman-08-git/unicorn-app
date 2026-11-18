/// Audience selection: Parent / Student / Guardian.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class AudienceSelectionScreen extends StatefulWidget {
  const AudienceSelectionScreen({super.key});

  @override
  State<AudienceSelectionScreen> createState() => _AudienceSelectionScreenState();
}

class _AudienceOption {
  const _AudienceOption(this.category, this.title, this.subtitle, this.icon, this.color, this.soft, this.message);
  final AudienceCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color soft;
  final String message;
}

const _options = [
  _AudienceOption(AudienceCategory.parent, 'PARENT', 'Discover how your child learns best.', Icons.family_restroom_rounded,
      AppColors.primaryViolet, AppColors.softViolet, 'Welcome, Parent! Let\'s explore together.'),
  _AudienceOption(AudienceCategory.student, 'STUDENT', 'Take a fun challenge made for your class.', Icons.backpack_rounded,
      Color(0xFF2563EB), Color(0xFFE8F0FF), 'Yay, a fellow explorer! Pick your class next.'),
  _AudienceOption(AudienceCategory.guardian, 'GUARDIAN', 'Support a young learner\'s journey.', Icons.shield_moon_rounded,
      Color(0xFFB45309), AppColors.softGold, 'Welcome, Guardian! Great to have you here.'),
];

class _AudienceSelectionScreenState extends State<AudienceSelectionScreen> {
  AudienceCategory? _selected;

  void _onSelect(_AudienceOption o) {
    if (_selected != null) return; // one tap only
    setState(() => _selected = o.category);
    Future.delayed(Motion.of(context, const Duration(milliseconds: 350)), () {
      if (mounted) context.read<SessionService>().selectAudience(o.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _options.where((o) => o.category == _selected).firstOrNull;
    return UllScaffold(
      onBack: () => context.read<SessionService>().resetSessionToWelcome(),
      trailing: TextButton.icon(
        onPressed: () => context.read<SessionService>().startDemoQuiz(),
        icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
        label: const Text('Demo Quiz (5 Qs)'),
        style: TextButton.styleFrom(foregroundColor: AppColors.secondaryText),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight;
        final cards = _options.asMap().entries.map((e) {
          final o = e.value;
          return FadeSlideIn(
            index: e.key + 2,
            offset: const Offset(0, 36),
            child: _AudienceCard(
              option: o,
              selected: _selected == o.category,
              dimmed: _selected != null && _selected != o.category,
              onTap: () => _onSelect(o),
            ),
          );
        }).toList();

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeSlideIn(
                  child: UnicornMascot(
                    state: selected != null ? MascotState.celebration : MascotState.curious,
                    width: 320,
                    height: 140,
                    bubbleSide: BubbleSide.right,
                    message: selected?.message ?? 'Hi there! Tell me who is joining today.',
                  ),
                ),
                const SizedBox(height: 28),
                const FadeSlideIn(
                  index: 1,
                  child: Text(
                    "WHO'S JOINING THE ADVENTURE?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.deepInkNavy, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ),
                const SizedBox(height: 36),
                if (landscape)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 24),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  )
                else
                  Column(
                    children: [
                      for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 18), child: card),
                    ],
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({required this.option, required this.selected, required this.dimmed, required this.onTap});
  final _AudienceOption option;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.base,
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedScale(
        duration: Motion.base,
        curve: Motion.pop,
        scale: selected ? 1.04 : 1,
        child: Pressable(
          onTap: onTap,
          semanticLabel: option.title,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.enter,
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            decoration: BoxDecoration(
              color: selected ? option.color : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: selected ? option.color : AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: selected ? option.color.withOpacity(0.35) : const Color(0x0F101C3A),
                  blurRadius: selected ? 32 : 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: Motion.base,
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withOpacity(0.18) : option.soft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(option.icon, size: 40, color: selected ? Colors.white : option.color),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: Motion.base,
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: selected
                          ? const Icon(Icons.check_circle_rounded, key: ValueKey(1), color: Colors.white, size: 34)
                          : Icon(Icons.arrow_forward_rounded, key: const ValueKey(0), color: option.color.withOpacity(0.6), size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  option.title,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.deepInkNavy,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  option.subtitle,
                  style: TextStyle(
                    color: selected ? Colors.white.withOpacity(0.9) : AppColors.secondaryText,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
