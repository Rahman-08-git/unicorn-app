/// Reward reveal.
///
/// IMPORTANT: the reward is assigned and persisted in
/// SessionService._finalizeAttempt() BEFORE this screen opens. Everything here
/// only *reveals* `session.assignedReward`; no animation can choose or change it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

enum _Phase { chest, spin, revealed }

class _RewardInfo {
  const _RewardInfo(this.title, this.subtitle, this.icon, this.color, this.claim);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String claim;
}

/// Look and copy for a reward tier. [giftName] is the gift's current name from
/// the operator's Inventory tab; it replaces the tier's generic title.
_RewardInfo _infoFor(String type, String? giftName) {
  final name = (giftName == null || giftName.trim().isEmpty) ? null : giftName.trim();
  switch (type) {
    case AppConstants.rewardPremiumGift:
      final title = name ?? 'Premium Discovery Kit';
      return _RewardInfo(title, 'A perfect score earns our grand surprise!', Icons.diamond_rounded,
          const Color(0xFFB45309), 'Show this screen to campaign staff to receive your $title.');
    case AppConstants.rewardScratchCard: // legacy tier, now part of the spin wheel tier
    case AppConstants.rewardSpinWheel:
      final title = name ?? 'Learning Gift';
      return _RewardInfo(title, 'Your sharp thinking earned a learning gift!', Icons.redeem_rounded,
          const Color(0xFF2563EB), 'Present this tablet to staff to collect your $title.');
    default:
      final title = name ?? 'Explorer Sticker Pack';
      return _RewardInfo(title, 'Every explorer gets a badge of curiosity!', Icons.star_rounded,
          const Color(0xFFDB2777), 'Collect your $title from campaign staff!');
  }
}

class RewardRevealScreen extends StatefulWidget {
  const RewardRevealScreen({super.key});

  @override
  State<RewardRevealScreen> createState() => _RewardRevealScreenState();
}

class _RewardRevealScreenState extends State<RewardRevealScreen> {
  _Phase _phase = _Phase.chest;

  // Every reward is revealed with the spin wheel.
  void _onChestOpened() => setState(() => _phase = _Phase.spin);

  void _onSpinDone() {
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.revealed);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final reward = session.assignedReward;
    final type = reward?.rewardType ?? AppConstants.rewardSticker;
    final info = _infoFor(type, session.assignedRewardName);

    final String headline;
    final String mascotMsg;
    switch (_phase) {
      case _Phase.chest:
        headline = 'A SURPRISE AWAITS!';
        mascotMsg = 'I saved something special for you. Tap the chest!';
        break;
      case _Phase.spin:
        headline = 'SPIN THE WHEEL!';
        mascotMsg = 'Give it a big spin!';
        break;
      case _Phase.revealed:
        headline = 'YOU EARNED IT!';
        mascotMsg = 'Congratulations! You earned this with your thinking.';
        break;
    }

    Widget stage;
    switch (_phase) {
      case _Phase.chest:
        stage = _TreasureChest(key: const ValueKey('chest'), onOpened: _onChestOpened);
        break;
      case _Phase.spin:
        stage = _SpinWheel(key: const ValueKey('wheel'), seed: reward?.id.hashCode ?? 0, info: info, onDone: _onSpinDone);
        break;
      case _Phase.revealed:
        stage = _RewardCard(key: const ValueKey('card'), info: info, premium: type == AppConstants.rewardPremiumGift);
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: UllBackground(
        tint: AppColors.softGold,
        accent: AppColors.softViolet,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(builder: (context, c) {
                final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 800;
                final mascot = UnicornMascot(
                  state: _phase == _Phase.revealed
                      ? MascotState.rewardReveal
                      : (_phase == _Phase.chest ? MascotState.curious : MascotState.thinking),
                  width: landscape ? double.infinity : 230,
                  height: landscape ? 210 : 110,
                  message: mascotMsg,
                  bubbleSide: landscape ? BubbleSide.top : BubbleSide.right,
                );

                final main = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.base),
                      child: Text(
                        headline,
                        key: ValueKey(headline),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.deepInkNavy, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 330,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.slow),
                        switchInCurve: Motion.pop,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
                        ),
                        child: stage,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.base),
                      child: _phase != _Phase.revealed
                          ? const SizedBox(height: 60, key: ValueKey('empty'))
                          : Column(
                              key: const ValueKey('claim'),
                              children: [
                                if (session.rewardFallbackMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(session.rewardFallbackMessage!,
                                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                                  ),
                                if (reward == null)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: Text('Please show this screen to a staff member.',
                                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                                  ),
                                _ClaimBox(text: info.claim),
                                const SizedBox(height: 18),
                                UllButton(
                                  label: 'LEARN ABOUT EDUCATION 4.0',
                                  icon: Icons.arrow_forward_rounded,
                                  height: 58,
                                  onPressed: session.goToEducationIntro,
                                ),
                              ],
                            ),
                    ),
                  ],
                );

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: landscape
                          ? Row(children: [
                              Expanded(flex: 3, child: FadeSlideIn(child: mascot)),
                              const SizedBox(width: 24),
                              Expanded(flex: 6, child: main),
                            ])
                          : Column(children: [FadeSlideIn(child: mascot), const SizedBox(height: 20), main]),
                    ),
                  ),
                );
              }),
            ),
            if (_phase == _Phase.revealed) const Positioned.fill(child: ConfettiBurst(count: 90)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Treasure chest (always the intro)
// ═══════════════════════════════════════════════════════════════════════════

class _TreasureChest extends StatefulWidget {
  const _TreasureChest({super.key, required this.onOpened});
  final VoidCallback onOpened;

  @override
  State<_TreasureChest> createState() => _TreasureChestState();
}

class _TreasureChestState extends State<_TreasureChest> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _tapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_idle.isAnimating && !_tapped) _idle.repeat();
  }

  Future<void> _tap() async {
    if (_tapped) return;
    _tapped = true;
    _idle.stop();
    HapticFeedback.lightImpact();
    if (Motion.reduced(context)) {
      widget.onOpened();
      return;
    }
    await _open.forward();
    if (mounted) widget.onOpened();
  }

  @override
  void dispose() {
    _idle.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.warmGold;
    const wood = Color(0xFF7C3AED);
    const woodDark = Color(0xFF4C1D95);
    return Pressable(
      onTap: _tap,
      semanticLabel: 'Open treasure chest',
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _open]),
        builder: (context, _) {
          final o = _open.value;
          final shake = o < 0.35 ? math.sin(o / 0.35 * math.pi * 6) * 0.05 * (1 - o / 0.35) : 0.0;
          final lidT = Curves.easeOutBack.transform(((o - 0.35) / 0.4).clamp(0.0, 1.0));
          final glow = ((o - 0.45) / 0.55).clamp(0.0, 1.0);
          final bob = math.sin(_idle.value * 2 * math.pi) * 4;

          return SizedBox(
            width: 320,
            height: 330,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // light burst
                Opacity(
                  opacity: glow,
                  child: Transform.scale(
                    scale: 0.6 + glow * 0.9,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [Color(0xCCFFE7A3), Color(0x00FFE7A3)]),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, bob + 30),
                  child: Transform.rotate(
                    angle: shake,
                    child: SizedBox(
                      width: 230,
                      height: 190,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // base
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                color: wood,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22), top: Radius.circular(6)),
                                border: Border.all(color: woodDark, width: 4),
                                boxShadow: const [BoxShadow(color: Color(0x33101C3A), blurRadius: 24, offset: Offset(0, 14))],
                              ),
                              child: Stack(children: [
                                Positioned(left: 30, top: 0, bottom: 0, child: Container(width: 14, color: gold)),
                                Positioned(right: 30, top: 0, bottom: 0, child: Container(width: 14, color: gold)),
                                Align(
                                  alignment: const Alignment(0, -0.75),
                                  child: Container(
                                    width: 42,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: gold,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFB45309), width: 3),
                                    ),
                                    child: const Icon(Icons.lock_rounded, color: Color(0xFF7C2D12), size: 22),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          // lid (hinged at its back-bottom edge)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 10,
                            height: 74,
                            child: Transform(
                              alignment: Alignment.bottomCenter,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..translate(0.0, -lidT * 26)
                                ..rotateX(lidT * 1.15),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(60), bottom: Radius.circular(6)),
                                  border: Border.all(color: woodDark, width: 4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox(width: 26),
                                    Container(width: 14, color: gold),
                                    const Spacer(),
                                    Container(width: 14, color: gold),
                                    const SizedBox(width: 26),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_tapped)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.deepInkNavy, borderRadius: BorderRadius.circular(999)),
                      child: const Text('TAP TO OPEN',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Spin wheel — always lands on the segment representing the assigned reward
// ═══════════════════════════════════════════════════════════════════════════

class _SpinWheel extends StatefulWidget {
  const _SpinWheel({super.key, required this.seed, required this.info, required this.onDone});
  final int seed;
  final _RewardInfo info;
  final VoidCallback onDone;

  @override
  State<_SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<_SpinWheel> with SingleTickerProviderStateMixin {
  static const _segments = 8;
  static const _icons = [Icons.redeem_rounded, Icons.star_rounded, Icons.auto_stories_rounded, Icons.rocket_launch_rounded];
  static const _colors = [AppColors.primaryViolet, AppColors.warmGold, Color(0xFF2563EB), Color(0xFFDB2777)];

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final int _winner = widget.seed.abs() % _segments;
  late final Animation<double> _angle;
  bool _spun = false;

  @override
  void initState() {
    super.initState();
    // Segment i is centred at angle i*seg (measured from the top pointer).
    // Rotating by -(winner*seg) brings the winner under the pointer.
    const seg = 2 * math.pi / _segments;
    final target = 6 * 2 * math.pi + (2 * math.pi - _winner * seg);
    _angle = Tween<double>(begin: 0, end: target).animate(CurvedAnimation(parent: _c, curve: const Cubic(0.15, 0.85, 0.25, 1)));
  }

  Future<void> _spin() async {
    if (_spun) return;
    setState(() => _spun = true);
    HapticFeedback.selectionClick();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      await _c.forward();
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _angle,
                builder: (_, child) => Transform.rotate(angle: _angle.value, child: child),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(250, 250),
                    painter: _WheelPainter(_segments, _colors, _winner),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        children: List.generate(_segments, (i) {
                          final a = i * 2 * math.pi / _segments - math.pi / 2;
                          return Align(
                            alignment: Alignment(math.cos(a) * 0.66, math.sin(a) * 0.66),
                            child: Transform.rotate(
                              angle: a + math.pi / 2,
                              child: Icon(i == _winner ? widget.info.icon : _icons[i % _icons.length], color: Colors.white, size: 28),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x33101C3A), blurRadius: 12)],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.warmGold, size: 30),
              ),
              const Positioned(
                top: -6,
                child: Icon(Icons.arrow_drop_down_rounded, size: 64, color: AppColors.deepInkNavy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        UllButton(
          label: _spun ? 'SPINNING…' : 'SPIN THE WHEEL',
          leadingIcon: Icons.refresh_rounded,
          height: 56,
          onPressed: _spun ? null : _spin,
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.n, this.colors, this.winner);
  final int n;
  final List<Color> colors;
  final int winner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final seg = 2 * math.pi / n;
    canvas.drawCircle(c, r, Paint()..color = AppColors.deepInkNavy);
    for (int i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * seg - seg / 2;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 8), start, seg, true, Paint()..color = colors[i % colors.length]);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 8),
        start,
        seg,
        true,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (int i = 0; i < n * 2; i++) {
      final a = i * seg / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r - 4), 2.5, Paint()..color = AppColors.warmGold);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Final reward card + claim box
// ═══════════════════════════════════════════════════════════════════════════

class _RewardCard extends StatelessWidget {
  const _RewardCard({super.key, required this.info, required this.premium});
  final _RewardInfo info;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.rotate(angle: (1 - v) * -0.25, child: Transform.scale(scale: 0.6 + 0.4 * v, child: child)),
      // Operator-named gifts can be long: shrink to fit the stage instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: info.color.withOpacity(0.4), width: 3),
          boxShadow: [BoxShadow(color: info.color.withOpacity(0.28), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(info.icon, size: 60, color: info.color),
            ),
            const SizedBox(height: 14),
            if (premium) ...[
              const UllPill(text: 'GRAND SURPRISE', icon: Icons.emoji_events_rounded, color: Color(0xFFB45309), background: AppColors.softGold),
              const SizedBox(height: 10),
            ],
            Text(info.title,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.deepInkNavy, fontWeight: FontWeight.w900, fontSize: 26)),
            const SizedBox(height: 6),
            Text(info.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText, fontSize: 15)),
          ],
        ),
      ),
      ),
    );
  }
}

class _ClaimBox extends StatelessWidget {
  const _ClaimBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: AppColors.softGold, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.storefront_rounded, color: Color(0xFFB45309), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CLAIM YOUR PHYSICAL REWARD',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309), fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: AppColors.deepInkNavy, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}
