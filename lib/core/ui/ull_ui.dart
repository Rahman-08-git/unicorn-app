/// Shared design + motion kit for Unicorn Learning Lab.
///
/// One coordinated system: every screen uses the same durations, curves,
/// entrance choreography, press feedback, buttons and backgrounds.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:unicorn_learning_lab/app/theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Motion tokens & reduced-motion preference
// ═══════════════════════════════════════════════════════════════════════════

class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Duration screen = Duration(milliseconds: 420);
  static const Duration stagger = Duration(milliseconds: 70);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve pop = Curves.easeOutBack;

  /// Operator-controlled reduced-motion switch (Operator Dashboard → Settings).
  static final ValueNotifier<bool> reducedPref = ValueNotifier<bool>(false);

  /// True when either the OS or the operator asked for reduced motion.
  static bool reduced(BuildContext context) =>
      reducedPref.value || (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Entrance animation: fade + rise, with optional stagger index
// ═══════════════════════════════════════════════════════════════════════════

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 24),
    this.duration = Motion.slow,
    this.scaleFrom = 1.0,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Offset offset;
  final Duration duration;
  final double scaleFrom;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // Delay is folded into the controller (Interval curve) — no Timers, so
  // nothing is left pending when a screen is disposed mid-animation.
  late final Duration _wait = widget.delay + Motion.stagger * widget.index;
  late final AnimationController _c = AnimationController(vsync: this, duration: _wait + widget.duration);
  late final Animation<double> _curved = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _wait.inMicroseconds / (_wait + widget.duration).inMicroseconds,
      1,
      curve: Motion.emphasized,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final v = _curved.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - v),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Press feedback: subtle scale-down on touch, used by every tappable card
// ═══════════════════════════════════════════════════════════════════════════

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.965,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: Motion.fast,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Buttons
// ═══════════════════════════════════════════════════════════════════════════

/// Primary CTA. Wraps an [ElevatedButton] (keeps semantics/tests intact)
/// and adds a press-scale and a coloured shadow.
class UllButton extends StatelessWidget {
  const UllButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leadingIcon,
    this.loading = false,
    this.height = 60,
    this.expand = false,
    this.color = AppColors.primaryViolet,
    this.foreground = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? leadingIcon;
  final bool loading;
  final double height;
  final bool expand;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final button = AnimatedContainer(
      duration: Motion.base,
      height: height,
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [BoxShadow(color: color.withOpacity(0.32), blurRadius: 22, offset: const Offset(0, 10))]
            : const [],
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.disabledText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: foreground, strokeWidth: 2.4),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[Icon(leadingIcon, size: 22), const SizedBox(width: 10)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 1.1),
                    ),
                  ),
                  if (icon != null) ...[const SizedBox(width: 12), Icon(icon, size: 22)],
                ],
              ),
      ),
    );
    return _ButtonPress(enabled: enabled, child: button);
  }
}

class _ButtonPress extends StatefulWidget {
  const _ButtonPress({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  State<_ButtonPress> createState() => _ButtonPressState();
}

class _ButtonPressState extends State<_ButtonPress> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.fast,
        child: widget.child,
      ),
    );
  }
}

/// Round back button used on every flow screen.
class UllBackButton extends StatelessWidget {
  const UllBackButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Back',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: const Icon(Icons.arrow_back_rounded, color: AppColors.deepInkNavy),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Surfaces
// ═══════════════════════════════════════════════════════════════════════════

class UllCard extends StatelessWidget {
  const UllCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.radius = 28,
    this.color = Colors.white,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x0F101C3A), blurRadius: 30, offset: Offset(0, 14)),
          BoxShadow(color: Color(0x08101C3A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/// Small uppercase pill used for eyebrows / badges.
class UllPill extends StatelessWidget {
  const UllPill({
    super.key,
    required this.text,
    this.icon,
    this.color = AppColors.primaryViolet,
    this.background = AppColors.softViolet,
  });

  final String text;
  final IconData? icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand lockup: violet monogram + wordmark. Long-press hook for operator.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onLongPress, this.compact = false});
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 38 : 46,
            height: compact ? 38 : 46,
            decoration: BoxDecoration(
              color: AppColors.deepInkNavy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.warmGold, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
           child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UNICORN LEARNING LAB',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.deepInkNavy,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 13 : 15,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'EDUCATION 4.0',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primaryViolet,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 10 : 11,
                  letterSpacing: 2.4,
                ),
              ),
            ],
           ),
          ),
        ],
      ),
    );
  }
}

/// Calm branded backdrop: off-white with two large soft colour fields and
/// a faint dot grid. Static (no animation loop) so it is free on GPU.
class UllBackground extends StatelessWidget {
  const UllBackground({super.key, required this.child, this.tint = AppColors.softViolet, this.accent = AppColors.softGold});
  final Widget child;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _BackdropPainter(tint, accent))),
          ),
          child,
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.tint, this.accent);
  final Color tint;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max(size.width, size.height);
    canvas.drawCircle(Offset(size.width * 1.02, -r * 0.08), r * 0.5, Paint()..color = tint);
    canvas.drawCircle(Offset(-r * 0.12, size.height * 1.08), r * 0.36, Paint()..color = accent);
    final dot = Paint()..color = AppColors.deepInkNavy.withOpacity(0.045);
    const gap = 28.0;
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.tint != tint || old.accent != accent;
}

/// Standard flow-screen scaffold: background, safe area, optional back button
/// and brand mark on top.
class UllScaffold extends StatelessWidget {
  const UllScaffold({
    super.key,
    required this.body,
    this.onBack,
    this.trailing,
    this.showBrand = true,
    this.tint = AppColors.softViolet,
    this.accent = AppColors.softGold,
  });

  final Widget body;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBrand;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      resizeToAvoidBottomInset: true,
      body: UllBackground(
        tint: tint,
        accent: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onBack != null || showBrand || trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        if (onBack != null) ...[UllBackButton(onTap: onBack!), const SizedBox(width: 16)],
                        if (showBrand) const Flexible(child: BrandMark(compact: true)),
                        const Spacer(),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Confetti: one-shot, lightweight, ~70 particles, self-disposing.
// ═══════════════════════════════════════════════════════════════════════════

class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.play = true, this.count = 70});
  final bool play;
  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final List<_Particle> _ps;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    const colors = [AppColors.primaryViolet, AppColors.warmGold, Color(0xFF3B82F6), Color(0xFFE5484D), Color(0xFF22C55E)];
    _ps = List.generate(widget.count, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      return _Particle(
        angle: angle,
        speed: 0.55 + rnd.nextDouble() * 0.6,
        spin: (rnd.nextDouble() - 0.5) * 12,
        color: colors[i % colors.length],
        size: 6 + rnd.nextDouble() * 7,
        originX: 0.3 + rnd.nextDouble() * 0.4,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.play && !Motion.reduced(context) && !_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => _c.value == 0 || _c.value == 1
              ? const SizedBox.expand()
              : CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_ps, _c.value)),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({required this.angle, required this.speed, required this.spin, required this.color, required this.size, required this.originX});
  final double angle, speed, spin, size, originX;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.ps, this.t);
  final List<_Particle> ps;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final p in ps) {
      final d = p.speed * size.height * 0.9;
      final x = size.width * p.originX + math.cos(p.angle) * d * t;
      final y = size.height * 0.62 + math.sin(p.angle) * d * t + 0.9 * size.height * t * t;
      paint.color = p.color.withOpacity(fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Count-up number animation (score reveal).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style, this.duration = const Duration(milliseconds: 1100), this.suffix = ''});
  final int value;
  final TextStyle style;
  final Duration duration;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.of(context, duration),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}$suffix', style: style),
    );
  }
}
