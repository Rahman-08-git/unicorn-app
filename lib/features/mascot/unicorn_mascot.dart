/// Animated Unicorn Learning Lab character ("Uni").
///
/// One ticker drives everything: Uni gallops in from off-screen, wanders
/// around its area (walk cycle, cartoon turn-around, pauses, fidgets), stops
/// to react to what the participant does (jump for joy, get sad then cheer
/// up, panic at the timer…), gallops off again ([exiting]) and hops when
/// tapped. Painting reads the clock directly — no per-frame widget rebuilds.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_rig.dart';

enum BubbleSide { none, top, right, left }

class UnicornMascot extends StatefulWidget {
  const UnicornMascot({
    super.key,
    this.state = MascotState.idle,
    this.width = 240,
    this.height = 240,
    this.interactive = true,
    this.message,
    this.bubbleSide = BubbleSide.top,
    this.enter = true,
    this.exiting = false,
    this.faceLeft = false,
    this.roam = true,
  });

  final MascotState state;

  /// Box size. Uni is drawn [height] tall; when [width] is larger than
  /// [height] the extra space is the area Uni wanders around in.
  final double width;
  final double height;
  final bool interactive;
  final String? message;
  final BubbleSide bubbleSide;

  /// Gallop in from off-screen when first shown.
  final bool enter;

  /// Gallop off-screen (forward), e.g. when the participant presses start.
  final bool exiting;

  /// Preferred facing when standing still / reacting.
  final bool faceLeft;

  /// Wander around the free space when not busy reacting.
  final bool roam;

  @override
  State<UnicornMascot> createState() => _UnicornMascotState();
}

class _UnicornMascotState extends State<UnicornMascot> with SingleTickerProviderStateMixin {
  static const double _entranceDur = 1.2;
  static const _roamable = {
    MascotState.idle,
    MascotState.welcome,
    MascotState.goodbye,
    MascotState.curious,
    MascotState.encouraging,
    MascotState.thinking,
  };

  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  final math.Random _rnd = math.Random();
  double _stateStart = 0;
  double _exitStart = -1;
  double _tapAt = -10;
  bool _animateEntrance = false;
  bool _arrived = false;
  bool _configured = false;

  // roaming
  Size _size = Size.zero;
  double _x = 0.5; // 0..1 across the free range
  double _tx = 0.5;
  bool _walking = false;
  double _pauseUntil = 2.5;
  double _flip = 1; // -1 facing left … 1 facing right (animated turn)
  bool _wantLeft = false;
  double _last = 0;

  double get _enterEnd => _animateEntrance ? _entranceDur : 0;

  @override
  void initState() {
    super.initState();
    _wantLeft = widget.faceLeft;
    _flip = widget.faceLeft ? -1 : 1;
    _ticker = createTicker((elapsed) {
      final now = elapsed.inMicroseconds / 1e6;
      final dt = (now - _last).clamp(0.0, 0.1);
      _last = now;
      _tickRoam(now, dt);
      final target = _wantLeft ? -1.0 : 1.0;
      _flip += (target - _flip) * math.min(1.0, dt * 12);
      _clock.value = now;
      if (!_arrived && now >= _enterEnd) setState(() => _arrived = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = Motion.reduced(context);
    if (!_configured) {
      _configured = true;
      _animateEntrance = widget.enter && !reduced;
      _arrived = !_animateEntrance;
      if (widget.exiting) _exitStart = 0;
    }
    if (reduced) {
      if (_ticker.isActive) _ticker.stop();
      _arrived = true;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant UnicornMascot old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _stateStart = _clock.value;
      if (!_roamable.contains(widget.state)) {
        // stop and react on the spot, facing the content
        _walking = false;
        _wantLeft = widget.faceLeft;
      }
      _pauseUntil = _clock.value + 1.8;
    }
    if (widget.exiting && !old.exiting) {
      _exitStart = _clock.value;
      _walking = false;
      _wantLeft = widget.faceLeft;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  double get _side => math.min(_size.width, _size.height);
  double get _free => math.max(0, _size.width - _side);

  void _tickRoam(double now, double dt) {
    final canRoam = widget.roam &&
        _roamable.contains(widget.state) &&
        _exitStart < 0 &&
        now >= _enterEnd &&
        now - _tapAt > 1.5 &&
        _free > _side * 0.25;
    if (!canRoam) {
      _walking = false;
      return;
    }
    if (_walking) {
      // walk speed matched to the leg cycle so hooves don't slide
      final speed = 0.30 * _side / _free;
      final d = _tx - _x;
      final step = speed * dt;
      if (d.abs() <= step) {
        _x = _tx;
        _walking = false;
        _pauseUntil = now + 1.6 + _rnd.nextDouble() * 2.6;
        // after a stroll, usually turn back toward the content
        if (_rnd.nextDouble() < 0.6) _wantLeft = widget.faceLeft;
      } else {
        _x += step * d.sign;
        _wantLeft = d < 0;
      }
    } else if (now >= _pauseUntil) {
      var nt = _rnd.nextDouble();
      if ((nt - _x).abs() < 0.3) {
        nt = _x < 0.5 ? _x + 0.4 + _rnd.nextDouble() * 0.2 : _x - 0.4 - _rnd.nextDouble() * 0.2;
      }
      _tx = nt.clamp(0.0, 1.0);
      _walking = true;
    }
  }

  bool get _busy => const {
        MascotState.timerUrgent,
        MascotState.timerWarning,
        MascotState.incorrectAnswer,
        MascotState.questionTimeout,
      }.contains(widget.state);

  void _onTap() {
    if (!widget.interactive || _busy || _exitStart >= 0) return;
    HapticFeedback.lightImpact();
    _walking = false;
    _tapAt = _clock.value;
  }

  /// Called by the painter every frame.
  void paintFrame(Canvas canvas, Size size) {
    _size = size;
    final now = _clock.value;
    final side = _side;
    final dir = _flip >= 0 ? 1.0 : -1.0;
    MascotState st = widget.state;
    double s;
    double dx = 0;

    if (_exitStart >= 0) {
      st = MascotState.runIn;
      final es = now - _exitStart;
      dx = dir * es * es * side * 7;
      s = es;
    } else if (now < _enterEnd) {
      st = MascotState.runIn;
      final e = now / _enterEnd;
      dx = -dir * (1 - Curves.easeOutCubic.transform(e)) * (size.width + side * 1.4 + 80);
      s = now;
    } else if (_walking) {
      st = MascotState.walkIn;
      s = now;
    } else {
      s = now - math.max(_stateStart, _enterEnd);
      if (now - _tapAt < 1.45 && !_busy) {
        st = MascotState.celebration;
        s = now - _tapAt;
      }
    }

    final pose = computeUnicornPose(st, now, s);
    canvas.save();
    canvas.translate(_free * _x + dx, size.height - side);
    // cartoon turn-around: squash through (almost) zero width when changing direction
    canvas.translate(side / 2, 0);
    canvas.scale(_flip.abs() < 0.08 ? 0.08 * dir : _flip, 1);
    canvas.translate(-side / 2, 0);
    UnicornArt.paint(canvas, Size(side, side), pose, flipped: _flip < 0);
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) {
    final character = GestureDetector(
      onTap: widget.interactive ? _onTap : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: RepaintBoundary(
          child: CustomPaint(painter: _LivePainter(this, widget.state)),
        ),
      ),
    );

    final msg = widget.message;
    final semantic = Semantics(label: 'Uni the unicorn mascot', image: true, child: character);
    if (msg == null || widget.bubbleSide == BubbleSide.none) return semantic;

    final bubble = AnimatedOpacity(
      opacity: _arrived && !widget.exiting ? 1 : 0,
      duration: Motion.of(context, Motion.base),
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.base),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: c),
        ),
        child: SpeechBubble(key: ValueKey(msg), text: msg, side: widget.bubbleSide),
      ),
    );

    switch (widget.bubbleSide) {
      case BubbleSide.right:
        return Row(mainAxisSize: MainAxisSize.min, children: [semantic, const SizedBox(width: 10), Flexible(child: bubble)]);
      case BubbleSide.left:
        return Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: bubble), const SizedBox(width: 10), semantic]);
      default:
        return Column(mainAxisSize: MainAxisSize.min, children: [bubble, const SizedBox(height: 6), semantic]);
    }
  }
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.host, this.state) : super(repaint: host._clock);
  final _UnicornMascotState host;
  final MascotState state;

  @override
  void paint(Canvas canvas, Size size) => host.paintFrame(canvas, size);

  @override
  bool shouldRepaint(covariant _LivePainter old) => old.state != state;
}

/// Mascot speech bubble.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.side = BubbleSide.top, this.maxWidth = 320});
  final String text;
  final BubbleSide side;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x14101C3A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.deepInkNavy, fontWeight: FontWeight.w700, fontSize: 15, height: 1.35),
      ),
    );
  }
}
