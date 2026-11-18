/// Rigged cartoon Unicorn Learning Lab mascot ("Uni").
///
/// Uni is a chibi unicorn standing on four legs: white plush body, a big head
/// with calm, friendly (gender-neutral) eyes, spiky blue/red/purple mane, blue
/// spiral horn, navy hooves and a branded sash with the Unicorn Learning Lab
/// badge. Gestures (wave, hoof-bump, point, holding the trophy) are done by
/// lifting the near front hoof.
///
/// The character is a vector rig (four legs with hip + knee, body, neck,
/// head, ears, tail, eyes, brows, mouth + props) drawn in a 200×200 design
/// space, side-on facing right with the head turned 3/4 toward the viewer.
/// A [UnicornPose] describes one frame; [computeUnicornPose] turns a
/// behaviour state + time into a pose, and [UnicornArt.paint] draws it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';

enum EyeMode { normal, happy, sad, wide }

enum MouthMode { smile, open, frown, o, flat, soft }

/// What a lifted front hoof is "saying".
enum HoofGesture { plain, sole, bump, point }

enum Emote { none, stars, hearts, heart, sparkles, cloud, exclaim, exclaimUrgent, question, burst, confetti, bulb }

/// One frame of the rig.
///
/// Legs: `fn` = front near, `ff` = front far, `bn` = back (hind) near,
/// `bf` = back far. Hip angle > 0 swings the hoof forward (toward the facing
/// direction); knee > 0 folds the lower leg backward, knee < 0 forward/up.
/// [rear] < 0 tips the body back onto the hind hooves (rearing up).
class UnicornPose {
  double bodyY = 0, bodyRot = 0, rear = 0, squash = 1, shadowK = 1;
  double headRot = 0, headDY = 0;
  double fnHip = 0, fnKnee = 0, ffHip = 0, ffKnee = 0;
  double bnHip = 0, bnKnee = 0, bfHip = 0, bfKnee = 0;
  HoofGesture hoofN = HoofGesture.plain;
  double tail = 0, earL = 0, earR = 0, mane = 0;
  double eyeOpen = 1;
  EyeMode eyes = EyeMode.normal;
  bool winkL = false;
  Offset look = Offset.zero;
  MouthMode mouth = MouthMode.smile;
  double browSad = 0, browRaise = 0;
  double tear = -1;
  bool sweat = false;
  bool dust = false;
  bool speedLines = false;
  double dustT = 0;
  bool hornSparkle = false;
  bool glasses = false, book = false, trophy = false;
  double time = 0;
  Emote emote = Emote.none;
  double emoteT = 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Behaviour → pose
// ═══════════════════════════════════════════════════════════════════════════

double _mix(double a, double b, double k) => a + (b - a) * k;

/// 0 → 1 → 0 envelope over [start, start+dur] with eased ramps of [ramp] s.
double _env(double w, double start, double dur, [double ramp = 0.25]) {
  if (w < start || w > start + dur) return 0;
  final a = ((w - start) / ramp).clamp(0.0, 1.0);
  final b = ((start + dur - w) / ramp).clamp(0.0, 1.0);
  return Curves.easeInOut.transform(math.min(a, b));
}

/// [t] = global seconds (continuous), [s] = seconds since this state began.
UnicornPose computeUnicornPose(MascotState state, double t, double s) {
  final p = UnicornPose()
    ..time = t
    ..emoteT = s
    // breathing + weight shift: the character is never perfectly still
    ..bodyY = math.sin(t * 2.6) * 0.9
    ..squash = 1 + math.sin(t * 2.6) * 0.01
    ..bodyRot = math.sin(t * 1.1) * 0.008
    ..headRot = math.sin(t * 1.7) * 0.04
    ..headDY = math.sin(t * 2.6 - 0.7) * 1.2
    ..tail = math.sin(t * 2.4) * 0.2
    ..mane = math.sin(t * 2.4 - 0.8) * 2.0
    ..look = Offset(math.sin(t * 0.7) * 0.5, math.sin(t * 0.45) * 0.25);

  // natural blink every ~3.7 s
  final bp = t % 3.7;
  if (bp < 0.16) p.eyeOpen = 1 - math.sin(bp / 0.16 * math.pi);
  // occasional ear flick
  final ef = t % 5.3;
  if (ef < 0.25) p.earR = math.sin(ef / 0.25 * math.pi) * 0.3;
  final el = (t + 2.1) % 6.7;
  if (el < 0.25) p.earL = -math.sin(el / 0.25 * math.pi) * 0.3;

  // idle fidgets (hoof-bump, shake the mane, little hop)
  final fidgety = state == MascotState.idle || state == MascotState.curious;
  if (fidgety) {
    final w = t % 9.0;
    final k = _env(w, 0, 1.8, 0.3);
    if (k > 0) {
      _hoofBump(p, k);
      p
        ..winkL = k > 0.9 && w > 0.6 && w < 1.2
        ..mouth = MouthMode.open;
    } else if (w > 4.0 && w < 4.6) {
      final k = (w - 4.0) / 0.6;
      p
        ..headRot += math.sin(k * math.pi * 4) * 0.12 * (1 - k)
        ..mane += math.sin(k * math.pi * 4) * 4;
    } else if (w > 7.0 && w < 7.45) {
      final k = math.sin((w - 7.0) / 0.45 * math.pi);
      p
        ..bodyY = -k * 10
        ..eyes = EyeMode.happy
        ..shadowK = 1 - k * 0.12;
      _tuck(p, k * 0.5);
    }
  }

  switch (state) {
    case MascotState.runIn:
    case MascotState.runAcross:
    case MascotState.letsGo:
      _run(p, t, 2.6, 0.7);
      break;
    case MascotState.walkIn:
      _walk(p, t, 1.7, 0.5);
      break;
    case MascotState.correctAnswer:
    case MascotState.greatJob:
      _greatJob(p, t, s);
      break;
    case MascotState.celebration:
    case MascotState.excited:
      _excited(p, t, s);
      break;
    case MascotState.rewardReveal:
      _excited(p, t, s);
      p
        ..hornSparkle = true
        ..emote = s < 2.2 ? Emote.burst : Emote.sparkles;
      break;
    case MascotState.incorrectAnswer:
      // Sad for a moment, then "Don't worry!" — supportive, never humiliating.
      if (s < 1.8) {
        _sad(p, t, s, tears: true);
      } else {
        _dontWorry(p, t, s - 1.8);
      }
      break;
    case MascotState.dontWorry:
      _dontWorry(p, t, s);
      break;
    case MascotState.encouraging:
    case MascotState.youGotThis:
      _youGotThis(p, t, s);
      break;
    case MascotState.keepGoing:
      _keepGoing(p, t, s);
      break;
    case MascotState.learning:
      _learning(p, t, s);
      break;
    case MascotState.thinking:
      _thinking(p, t);
      break;
    case MascotState.curious:
      p
        ..headRot = -0.07 + math.sin(t * 1.6) * 0.04
        ..look = const Offset(0.8, -0.2)
        ..earL = 0.15
        ..earR = -0.15
        ..browRaise = 0.35;
      // "pointer" pose: one front hoof lifted and folded
      if (p.hoofN == HoofGesture.plain && p.fnHip == 0) {
        p
          ..fnHip = 0.55
          ..fnKnee = 1.7;
      }
      break;
    case MascotState.timerWarning:
      final st = math.sin(t * 12);
      p
        ..eyes = EyeMode.wide
        ..browRaise = 1
        ..look = const Offset(0.6, -0.7)
        ..mouth = MouthMode.o
        ..sweat = true
        ..earL = 0.12
        ..earR = -0.12
        // nervous stamping of the front hooves
        ..fnHip = 0.15 * math.max(0, st)
        ..fnKnee = 0.9 * math.max(0, st)
        ..ffHip = 0.15 * math.max(0, -st)
        ..ffKnee = 0.9 * math.max(0, -st)
        ..emote = Emote.exclaim;
      break;
    case MascotState.timerUrgent:
      _run(p, t, 3.2, 0.5);
      p
        ..dust = false
        ..speedLines = false
        ..eyes = EyeMode.wide
        ..browRaise = 1
        ..look = const Offset(0.6, -0.6)
        ..mouth = MouthMode.o
        ..sweat = true
        ..earL = 0
        ..earR = 0
        ..emote = Emote.exclaimUrgent;
      break;
    case MascotState.questionTimeout:
      if (s < 0.55) {
        final k = math.sin(s / 0.55 * math.pi);
        p
          ..bodyY = -k * 12
          ..shadowK = 1 - k * 0.15
          ..eyes = EyeMode.wide
          ..browRaise = 1
          ..mouth = MouthMode.o
          ..earL = 0.2
          ..earR = -0.2
          // startled: all four legs splay out
          ..fnHip = 0.5 * k
          ..ffHip = 0.4 * k
          ..bnHip = -0.5 * k
          ..bfHip = -0.4 * k
          ..emote = Emote.exclaim;
      } else {
        _sad(p, t, s - 0.55, tears: false);
        p
          ..sweat = true
          ..emote = Emote.none;
      }
      break;
    case MascotState.welcome:
    case MascotState.goodbye:
      final cyc = s % 6.0;
      if (cyc < 2.8) {
        _wave(p, t);
        if (state == MascotState.goodbye || cyc < 1.2) p.eyes = EyeMode.happy;
      } else if (state == MascotState.welcome && cyc > 3.4 && cyc < 5.4) {
        // hoof-bump between waves
        _hoofBump(p, _env(cyc, 3.4, 2.0, 0.3));
        p.mouth = MouthMode.open;
      }
      if (s < 3.0) p.emote = state == MascotState.goodbye ? Emote.burst : Emote.sparkles;
      break;
    case MascotState.idle:
      break;
  }
  final locomotion = state == MascotState.runIn ||
      state == MascotState.runAcross ||
      state == MascotState.walkIn ||
      state == MascotState.letsGo;
  if (!locomotion) {
    p
      ..headRot += math.sin(t * 1.7) * 0.025
      ..tail += math.sin(t * 2.4) * 0.14
      ..mane += math.sin(t * 2.4 - 0.8) * 1.0;
  }
  return p;
}

/// Near front hoof raised high in a friendly "hoof-bump" (the old thumbs-up).
void _hoofBump(UnicornPose p, double k) {
  p
    ..fnHip = _mix(p.fnHip, 1.25, k)
    ..fnKnee = _mix(p.fnKnee, -2.15, k)
    ..hoofN = k > 0.6 ? HoofGesture.bump : HoofGesture.plain;
}

/// Fold all four legs a little (hop / jump tuck), [k] in 0..1.
void _tuck(UnicornPose p, double k) {
  p
    ..fnHip += 0.7 * k
    ..fnKnee += 1.5 * k
    ..ffHip += 0.6 * k
    ..ffKnee += 1.6 * k
    ..bnHip += 0.35 * k
    ..bnKnee += 1.1 * k
    ..bfHip += 0.3 * k
    ..bfKnee += 1.0 * k;
}

void _wave(UnicornPose p, double t) {
  p
    ..fnHip = 1.55
    ..fnKnee = -1.35 + math.sin(t * 10) * 0.35
    ..hoofN = HoofGesture.sole
    ..rear = -0.04
    ..headRot = -0.06
    ..mouth = MouthMode.open
    ..tail = 0.3 + math.sin(t * 8) * 0.2;
}

/// Gallop: front pair and hind pair swing in opposite phase, with the far
/// leg of each pair trailing slightly; the body rocks fore and aft.
void _run(UnicornPose p, double t, double freq, double amp) {
  final ph = t * 2 * math.pi * freq;
  double hip(double o) => amp * math.sin(ph + o);
  double knee(double o) => 1.4 * math.max(0, math.cos(ph + o));
  p
    ..fnHip = hip(0)
    ..fnKnee = knee(0)
    ..ffHip = hip(-0.5)
    ..ffKnee = knee(-0.5)
    ..bnHip = hip(math.pi) * 0.9
    ..bnKnee = knee(math.pi) * 0.8
    ..bfHip = hip(math.pi - 0.5) * 0.9
    ..bfKnee = knee(math.pi - 0.5) * 0.8
    ..bodyY = -math.sin(ph).abs() * 7 * amp
    ..bodyRot = math.sin(ph) * 0.06
    ..headRot = math.cos(ph * 2) * 0.04 - 0.04
    ..tail = 0.55 + math.sin(ph) * 0.22
    ..mane = math.sin(ph * 2) * 1.5 - 2
    ..earL = -0.35
    ..earR = -0.4
    ..mouth = MouthMode.open
    ..look = const Offset(1, 0)
    ..dust = true
    ..speedLines = true
    ..dustT = t * freq;
  p.shadowK = 1 - p.bodyY.abs() / 60;
}

/// Four-beat walk: hind near, front near, hind far, front far.
void _walk(UnicornPose p, double t, double freq, double amp) {
  final ph = t * 2 * math.pi * freq;
  double hip(double o) => amp * math.sin(ph + o);
  double knee(double o) => 0.9 * math.max(0, math.cos(ph + o));
  p
    ..bnHip = hip(0)
    ..bnKnee = knee(0)
    ..fnHip = hip(math.pi / 2)
    ..fnKnee = knee(math.pi / 2)
    ..bfHip = hip(math.pi)
    ..bfKnee = knee(math.pi)
    ..ffHip = hip(math.pi * 1.5)
    ..ffKnee = knee(math.pi * 1.5)
    ..bodyY = -math.sin(ph * 2).abs() * 1.6
    ..bodyRot = math.sin(ph) * 0.015
    ..headRot = math.sin(ph * 2) * 0.04 - 0.02
    ..tail = 0.25 + math.sin(ph) * 0.18
    ..earL = 0.05
    ..earR = -0.1
    ..mouth = MouthMode.smile;
}

void _jump(UnicornPose p, double t, double s, {double strongH = 26, double softH = 8}) {
  const period = 0.72;
  final hp = (s % period) / period;
  final strong = s < period * 2;
  final air = math.sin(hp * math.pi);
  final h = air * (strong ? strongH : softH);
  p
    ..bodyY = -h
    ..squash = (hp < 0.1 || hp > 0.92) ? 0.93 : 1.0 + air * 0.03
    ..shadowK = 1 - h / 70;
  _tuck(p, strong ? air : air * 0.35);
}

void _excited(UnicornPose p, double t, double s) {
  _jump(p, t, s);
  final flap = math.sin(t * 9) * 0.25;
  p
    // happy prance: rear up with both front hooves kicking
    ..rear = -0.2
    ..fnHip = 1.1 + flap
    ..fnKnee = 1.6 - flap
    ..ffHip = 0.85 - flap
    ..ffKnee = 1.8 + flap
    ..headRot = -0.08
    ..eyes = EyeMode.happy
    ..mouth = MouthMode.open
    ..tail = 0.6 + math.sin(t * 14) * 0.25
    ..mane = math.sin(t * 9) * 1.4
    ..earL = 0.12
    ..earR = -0.12
    ..hornSparkle = true
    ..emote = Emote.burst;
}

void _greatJob(UnicornPose p, double t, double s) {
  _jump(p, t, s, strongH: 14, softH: 5);
  p
    ..rear = -0.12
    // trophy held high on the near front hoof
    ..fnHip = 1.55
    ..fnKnee = -0.35 + math.sin(t * 6) * 0.05
    ..trophy = true
    ..ffHip = 0.6
    ..ffKnee = 1.5 + math.max(0, math.sin(t * 7)) * 0.3
    ..headRot = -0.05
    ..eyes = EyeMode.happy
    ..mouth = MouthMode.open
    ..tail = 0.5 + math.sin(t * 12) * 0.22
    ..hornSparkle = true
    ..emote = Emote.confetti;
}

void _youGotThis(UnicornPose p, double t, double s) {
  final k = Curves.easeOutBack.transform((s / 0.35).clamp(0.0, 1.0));
  p
    // near front hoof stretched straight out: "you!"
    ..fnHip = _mix(0, 1.45, k)
    ..fnKnee = _mix(0, -0.1, k) + math.sin(t * 4) * 0.04
    ..hoofN = k > 0.5 ? HoofGesture.point : HoofGesture.plain
    ..rear = -0.03 * k
    ..headRot = -0.05 + math.sin(t * 3) * 0.03
    ..winkL = (s % 3.5) > 0.3 && (s % 3.5) < 1.6
    ..mouth = MouthMode.open
    ..browRaise = 0.15
    ..emote = Emote.stars;
}

void _keepGoing(UnicornPose p, double t, double s) {
  p
    ..fnHip = 1.7
    ..fnKnee = -1.2 + math.sin(t * 5) * 0.25
    ..hoofN = HoofGesture.sole
    ..rear = -0.05
    ..headRot = -0.04 + math.sin(t * 3) * 0.03
    ..mouth = MouthMode.smile
    ..tail = 0.25 + math.sin(t * 6) * 0.15
    ..emote = s < 2.5 ? Emote.sparkles : Emote.none;
}

void _dontWorry(UnicornPose p, double t, double s) {
  final k = (s / 0.35).clamp(0.0, 1.0);
  p
    // near hoof folded up to the chest, head tilted kindly
    ..fnHip = _mix(0, 0.95, k)
    ..fnKnee = _mix(0, 2.1, k)
    ..headRot = 0.08 + math.sin(t * 2) * 0.03
    ..browSad = 0.35
    ..mouth = MouthMode.soft
    ..look = const Offset(0.3, 0.1)
    ..tail = 0.15 + math.sin(t * 3) * 0.1
    ..emote = Emote.heart;
}

void _learning(UnicornPose p, double t, double s) {
  final glance = _env(s % 5.0, 3.4, 1.4, 0.3); // look up from the book now and then
  p
    ..glasses = true
    ..book = true
    ..headDY = 5 * (1 - glance)
    ..headRot = 0.14 * (1 - glance) + math.sin(t * 1.3) * 0.02
    ..look = Offset.lerp(Offset(0.3 + math.sin(t * 1.6) * 0.5, 0.85), const Offset(0.4, -0.2), glance)!
    ..mouth = glance > 0.5 ? MouthMode.open : MouthMode.soft
    ..browRaise = 0.3 * glance
    ..emote = Emote.bulb;
}

void _thinking(UnicornPose p, double t) {
  p
    ..headRot = -0.1 + math.sin(t * 1.3) * 0.03
    ..headDY = 2
    ..look = const Offset(-0.4, -0.9)
    ..mouth = MouthMode.flat
    ..browRaise = 0.5
    // tapping a front hoof while pondering
    ..fnHip = 0.3
    ..fnKnee = 0.25 + math.max(0, math.sin(t * 8)) * 0.6
    ..emote = Emote.question;
}

void _sad(UnicornPose p, double t, double s, {required bool tears}) {
  final k = (s / 0.35).clamp(0.0, 1.0);
  p
    ..headDY = 7 * k
    ..headRot = 0.15 * k
    ..earL = -0.9 * k
    ..earR = 0.95 * k
    ..eyes = EyeMode.sad
    ..look = const Offset(0, 0.7)
    ..browSad = k
    ..mouth = MouthMode.frown
    ..tail = -0.4 * k + math.sin(t * 1.2) * 0.05
    ..bodyY = 2 * k + math.sin(t * 1.5) * 0.6
    ..emote = Emote.cloud;
  if (tears) p.tear = (s % 1.6) / 1.6;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Drawing
// ═══════════════════════════════════════════════════════════════════════════

class UnicornArt {
  UnicornArt._();

  static const ink = Color(0xFF22264F);
  static const white = Color(0xFFFFFFFF);
  static const shade = Color(0xFFE2E6F3);
  static const blue = Color(0xFF2F5BEA);
  static const deepBlue = Color(0xFF1E3FB8);
  static const red = Color(0xFFE5384D);
  static const purple = Color(0xFF7246E8);
  static const pink = Color(0xFFFFB8C6);
  static const earInner = Color(0xFFCBD3EE);
  static const muzzle = Color(0xFFEEF1F9);
  static const navy = Color(0xFF1C2766);
  static const navyHi = Color(0xFF3A4A9E);
  static const gold = Color(0xFFF6B42A);
  static const brow = Color(0xFF2A3268);

  static final Paint _stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static Paint _fill(Color c) => Paint()..color = c;

  // ── layout (design space, facing right) ──────────────────────────────
  // body barrel
  static final Path _torso = Path()
    ..moveTo(98, 112)
    ..cubicTo(124, 111, 142, 122, 141, 140)
    ..cubicTo(140, 158, 122, 165, 98, 165)
    ..cubicTo(72, 165, 55, 158, 55, 139)
    ..cubicTo(55, 121, 72, 113, 98, 112)
    ..close();
  static final Paint _torsoFill = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [white, white, shade],
      stops: [0, 0.55, 1],
    ).createShader(const Rect.fromLTWH(55, 112, 86, 53));
  // leg hips (near legs a little lower = closer to the viewer)
  static const _hipBN = Offset(67, 152), _hipBF = Offset(78, 149);
  static const _hipFN = Offset(119, 152), _hipFF = Offset(130, 149);
  // the head is drawn in its own 200-box frame, then shifted onto the neck
  static const _neckPivot = Offset(128, 120);
  static const _headShift = Offset(30, 12);
  static const Rect _headRect = Rect.fromLTWH(64, 26, 84, 72);
  static final Paint _headFill = Paint()
    ..shader = const RadialGradient(center: Alignment(-0.15, -0.4), radius: 0.95, colors: [white, Color(0xFFE9ECF7)])
        .createShader(_headRect);
  static final Paint _hornFill = Paint()
    ..shader = const LinearGradient(colors: [Color(0xFF7FB4FF), Color(0xFF1F45C8)])
        .createShader(const Rect.fromLTWH(100, -8, 20, 40));

  static final TextPainter _qText = _label('?', purple, 30);
  static final TextPainter _exText = _label('!', white, 17);
  static final TextPainter _exExText = _label('!!', white, 15);

  static TextPainter _label(String s, Color c, double size) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Paint [p] into [size]. [flipped] tells emote text to counter-mirror.
  static void paint(Canvas canvas, Size size, UnicornPose p, {bool flipped = false}) {
    final s = math.min(size.width, size.height) / 200;
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);
    // leave head-room for the horn, raised hooves and emotes
    canvas.translate(100, 0);
    canvas.scale(0.84);
    canvas.translate(-103, 37);
    _draw(canvas, p, flipped);
    canvas.restore();
  }

  static void _draw(Canvas c, UnicornPose p, bool flipped) {
    // ground shadow
    c.drawOval(
      Rect.fromCenter(center: const Offset(100, 192), width: 118 * p.shadowK, height: 12 * p.shadowK),
      _fill(const Color(0x22101C3A)),
    );
    if (p.dust) _dust(c, p);

    c.save();
    c.translate(0, p.bodyY);
    // squash & stretch around the hooves
    c.translate(100, 190);
    c.scale(1 + (1 - p.squash) * 0.6, p.squash);
    c.translate(-100, -190);
    // rear up around the hind hooves
    c.translate(72, 190);
    c.rotate(p.rear);
    c.translate(-72, -190);
    // gentle pitch around the middle of the body
    c.translate(98, 150);
    c.rotate(p.bodyRot);
    c.translate(-98, -150);

    // keep the hind hooves under the body while rearing
    final hindFix = p.rear * 0.9;

    if (p.speedLines) _speedLines(c, p);

    // far legs (behind the body, slightly shaded)
    _leg(c, p, _hipBF, p.bfHip + hindFix, p.bfKnee, true, 16);
    _leg(c, p, _hipFF, p.ffHip, p.ffKnee, true, 14.5);
    _tail(c, p);

    // body + sash
    c.drawPath(_torso, _torsoFill);
    c.drawOval(Rect.fromCenter(center: const Offset(92, 126), width: 44, height: 16), _fill(const Color(0x88FFFFFF)));
    c.save();
    c.clipPath(_torso);
    _sash(c);
    c.restore();
    c.drawPath(_torso, _stroke);
    _badge(c);

    _leg(c, p, _hipBN, p.bnHip + hindFix, p.bnKnee, false, 16);

    // neck + head
    c.save();
    _headTransform(c, p);
    _backMane(c, p);
    _neck(c);
    _head(c, p);
    c.restore();

    if (p.book) _book(c, p);
    // near front leg last so a raised hoof (and the trophy) sits in front
    _leg(c, p, _hipFN, p.fnHip, p.fnKnee, false, 14.5, gesture: p.hoofN, trophy: p.trophy);

    c.save();
    c.translate(26, 6); // emotes float around the head
    _emote(c, p, flipped);
    c.restore();
    c.restore();
  }

  static void _headTransform(Canvas c, UnicornPose p) {
    c.translate(0, p.headDY);
    c.translate(_neckPivot.dx, _neckPivot.dy);
    c.rotate(p.headRot);
    c.translate(-_neckPivot.dx, -_neckPivot.dy);
    c.translate(_headShift.dx, _headShift.dy);
  }

  /// Neck, in head-frame coordinates, reaching down into the body.
  static void _neck(Canvas c) {
    final neck = Path()
      ..moveTo(84, 124)
      ..quadraticBezierTo(82, 100, 92, 86)
      ..lineTo(122, 90)
      ..quadraticBezierTo(116, 110, 103, 121)
      ..close();
    c.drawPath(neck, _fill(white));
    c.drawPath(
      Path()
        ..moveTo(84.5, 120)
        ..quadraticBezierTo(82, 100, 92, 86),
      _stroke,
    );
    c.drawPath(
      Path()
        ..moveTo(122, 90)
        ..quadraticBezierTo(116, 110, 104, 120),
      _stroke,
    );
  }

  // ── legs ─────────────────────────────────────────────────────────────

  static void _leg(
    Canvas c,
    UnicornPose p,
    Offset hip,
    double h,
    double k,
    bool far,
    double w, {
    HoofGesture gesture = HoofGesture.plain,
    bool trophy = false,
  }) {
    const l1 = 16.0, l2 = 15.0;
    final fill = _fill(far ? shade : white);
    c.save();
    c.translate(hip.dx, hip.dy);
    c.rotate(-h);
    final thigh = RRect.fromRectAndRadius(Rect.fromLTWH(-w / 2, -10, w, l1 + 14), Radius.circular(w / 2));
    c.drawRRect(thigh, fill);
    c.drawRRect(thigh, _stroke);
    c.translate(0, l1);
    c.rotate(k);
    final shin = RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.42, -4, w * 0.84, l2 + 2), Radius.circular(w * 0.42));
    c.drawRRect(shin, fill);
    c.drawRRect(shin, _stroke);
    // navy hoof
    final hf = RRect.fromRectAndCorners(
      Rect.fromLTWH(-w * 0.52, l2 - 3, w * 1.04, 11),
      topLeft: const Radius.circular(5),
      topRight: const Radius.circular(5),
      bottomLeft: const Radius.circular(3.5),
      bottomRight: const Radius.circular(3.5),
    );
    c.drawRRect(hf, _fill(far ? const Color(0xFF151D52) : navy));
    c.drawLine(Offset(-w * 0.32, l2 - 0.5), Offset(w * 0.18, l2 - 0.5), Paint()
      ..color = navyHi
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    c.drawRRect(hf, _stroke);
    if (gesture == HoofGesture.sole) {
      // underside of the hoof turned toward the viewer (waving)
      c.drawOval(Rect.fromCenter(center: const Offset(0, l2 + 6.5), width: w * 0.8, height: 4.5), _fill(navyHi));
    }
    c.drawCircle(Offset.zero, w * 0.38, fill); // hide knee seam
    if (gesture == HoofGesture.bump || gesture == HoofGesture.point) {
      final tw = (math.sin(p.time * 8) + 1) / 2;
      _sparkle(c, Offset(0, l2 + 15 + tw * 1.5), 4 + tw * 2.5, gold);
    }
    if (trophy) {
      c.translate(0, l2 + 8);
      c.rotate(h - k); // trophy stays upright on screen
      c.translate(5, 2);
      c.scale(0.85);
      _trophy(c);
    }
    c.restore();
  }

  static void _trophy(Canvas c) {
    final g = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFFFE07A), Color(0xFFE29A12)])
          .createShader(const Rect.fromLTWH(-12, -40, 24, 36));
    final handle = Paint()
      ..color = const Color(0xFFE6A11A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawArc(Rect.fromCenter(center: const Offset(-11, -31), width: 9, height: 10), 1.2, 3.6, false, handle);
    c.drawArc(Rect.fromCenter(center: const Offset(11, -31), width: 9, height: 10), -1.9, 3.6, false, handle);
    final cup = Path()
      ..moveTo(-11, -40)
      ..lineTo(11, -40)
      ..quadraticBezierTo(11, -22, 0, -19)
      ..quadraticBezierTo(-11, -22, -11, -40)
      ..close();
    c.drawPath(cup, g);
    c.drawPath(cup, _stroke);
    c.drawRect(const Rect.fromLTWH(-2.2, -19.5, 4.4, 7), g);
    final base = RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -13, 16, 6), const Radius.circular(2));
    c.drawRRect(base, g);
    c.drawRRect(base, _stroke);
    _starPath(c, const Offset(0, -31), 4.6, _fill(white));
  }

  /// Open book lying on the ground in front of the hooves.
  static void _book(Canvas c, UnicornPose p) {
    c.save();
    c.translate(166, 184);
    c.scale(0.72, 0.5);
    for (final sx in [-1.0, 1.0]) {
      final cover = Path()
        ..moveTo(0, -12)
        ..lineTo(sx * 30, -16)
        ..lineTo(sx * 32, 14)
        ..lineTo(0, 18)
        ..close();
      c.drawPath(cover, _fill(purple));
      c.drawPath(cover, _stroke);
      final page = Path()
        ..moveTo(0, -13)
        ..quadraticBezierTo(sx * 12, -19, sx * 27, -17)
        ..lineTo(sx * 28, 10)
        ..quadraticBezierTo(sx * 12, 8, 0, 14)
        ..close();
      c.drawPath(page, _fill(const Color(0xFFFFFDF6)));
      c.drawPath(page, Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      final line = Paint()
        ..color = const Color(0xFFB9B4D8)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final y = -8 + i * 6.5;
        c.drawLine(Offset(sx * 5, y), Offset(sx * 22, y - 1), line);
      }
    }
    c.restore();
  }

  // ── hair ─────────────────────────────────────────────────────────────

  static void _tail(Canvas c, UnicornPose p) {
    c.save();
    c.translate(62, 126);
    c.rotate(p.tail);
    Offset wv(int i, double amp, double lag) =>
        Offset(math.sin(p.time * 3.4 + i * 0.9 + lag) * amp, math.cos(p.time * 3.4 + i * 0.9 + lag) * amp * 0.8);
    _tuft(c, Offset.zero, const Offset(-26, -24) + wv(0, 3, 0), const Offset(-36, 2) + wv(0, 6, 1), 10, blue);
    _tuft(c, const Offset(0, 4), const Offset(-38, -2) + wv(1, 3, 0), const Offset(-38, 28) + wv(1, 6, 1), 10, purple);
    _tuft(c, const Offset(0, 6), const Offset(-26, 18) + wv(2, 3, 0), const Offset(-22, 40) + wv(2, 6, 1), 9, red);
    c.restore();
  }

  static void _backMane(Canvas c, UnicornPose p) {
    final m = p.mane;
    double mw(int i) => math.sin(p.time * 3.0 + i * 1.1) * 2.2;
    _tuft(c, const Offset(140, 40), Offset(156 + mw(4), 54 + m), Offset(150 + mw(5), 80 + m), 9, blue);
    _tuft(c, const Offset(80, 34), Offset(56 + mw(0), 42 + m), Offset(50 + mw(1), 70 + m), 13, blue);
    _tuft(c, const Offset(72, 50), Offset(50 + mw(1), 70 + m), Offset(56 + mw(2), 100 + m), 12, red);
    _tuft(c, const Offset(74, 70), Offset(56 + mw(2), 92 + m), Offset(66 + mw(3), 118 + m), 10, purple);
    _tuft(c, const Offset(82, 82), Offset(70 + mw(3), 104 + m), Offset(80 + mw(4), 122 + m), 8, blue);
  }

  /// Tapered hair lock from [from] to [to], bulging through [ctrl].
  static void _tuft(Canvas c, Offset from, Offset ctrl, Offset to, double w, Color color) {
    final d = to - from;
    final len = d.distance;
    final n = Offset(-d.dy / len, d.dx / len);
    final path = Path()
      ..moveTo(from.dx + n.dx * w, from.dy + n.dy * w)
      ..quadraticBezierTo(ctrl.dx + n.dx * w * 0.7, ctrl.dy + n.dy * w * 0.7, to.dx, to.dy)
      ..quadraticBezierTo(ctrl.dx - n.dx * w * 0.7, ctrl.dy - n.dy * w * 0.7, from.dx - n.dx * w, from.dy - n.dy * w)
      ..close();
    c.drawPath(path, _fill(color));
    c.drawPath(path, _stroke);
    c.drawPath(
      Path()
        ..moveTo(from.dx + n.dx * w * 0.35, from.dy + n.dy * w * 0.35)
        ..quadraticBezierTo(ctrl.dx + n.dx * w * 0.3, ctrl.dy + n.dy * w * 0.3, (ctrl.dx + to.dx) / 2, (ctrl.dy + to.dy) / 2),
      Paint()
        ..color = const Color(0x59FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── sash + badge ─────────────────────────────────────────────────────

  static void _sash(Canvas c) {
    // band wrapped around the barrel, just behind the front legs
    final band = Path()
      ..moveTo(74, 106)
      ..lineTo(88, 106)
      ..lineTo(100, 170)
      ..lineTo(86, 170)
      ..close();
    c.drawPath(band, _fill(const Color(0xFFF7F8FF)));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    c.drawLine(const Offset(74, 106), const Offset(86, 170), edge..color = blue);
    c.drawLine(const Offset(88, 106), const Offset(100, 170), edge..color = blue);
    c.drawLine(const Offset(78, 106), const Offset(90, 170), Paint()
      ..color = red
      ..strokeWidth = 1.3);
  }

  static void _badge(Canvas c) {
    const ctr = Offset(87, 138);
    c.drawCircle(ctr, 11.5, _fill(white));
    c.drawCircle(ctr, 11.5, Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2);
    c.drawArc(Rect.fromCircle(center: ctr, radius: 7.4), 0.3, 2.5, false, Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);
    _starPath(c, ctr + const Offset(0, -1), 4.8, _fill(gold));
    c.drawCircle(ctr, 13, Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
  }

  // ── head ─────────────────────────────────────────────────────────────

  static void _head(Canvas c, UnicornPose p) {
    _ear(c, const Offset(76, 40), -0.5 + p.earL);
    _ear(c, const Offset(137, 34), 0.42 + p.earR);

    // crest spikes behind the horn
    final cm = Offset(math.sin(p.time * 3.2) * 1.2, p.mane * 0.3);
    _tuft(c, const Offset(96, 34), const Offset(84, 22), const Offset(74, 18) + cm, 10, blue);
    _tuft(c, const Offset(102, 32), const Offset(96, 18), const Offset(90, 8) + cm, 9, red);
    _tuft(c, const Offset(120, 30), const Offset(126, 16), const Offset(132, 8) + cm, 9, red);
    _tuft(c, const Offset(124, 32), const Offset(138, 22), const Offset(146, 22) + cm, 9, blue);

    // horn
    final horn = Path()
      ..moveTo(103, 32)
      ..lineTo(111, -6)
      ..lineTo(119, 31)
      ..close();
    c.drawPath(horn, _hornFill);
    final stripe = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final k in [0.22, 0.46, 0.7]) {
      final a = Offset.lerp(const Offset(103, 32), const Offset(111, -6), k)!;
      final b = Offset.lerp(const Offset(119, 31), const Offset(111, -6), k - 0.1)!;
      c.drawLine(a, b, stripe);
    }
    c.drawPath(horn, _stroke);
    if (p.hornSparkle) {
      final tw = (math.sin(p.time * 9) + 1) / 2;
      _sparkle(c, const Offset(124, -6), 3 + tw * 4, white);
      _sparkle(c, const Offset(124, -6), 2 + tw * 2, gold);
    }

    // head + muzzle
    final head = Path()..addOval(_headRect);
    c.drawPath(head, _headFill);
    c.drawPath(head, _stroke);
    final mz = Path()..addOval(Rect.fromCenter(center: const Offset(113, 86), width: 52, height: 29));
    c.drawPath(mz, _fill(muzzle));
    c.drawPath(mz, _stroke);

    // neutral face: no blush, no lashes, calm medium-sized eyes
    _eye(c, p, const Offset(90, 59), 9, 11, true);
    _eye(c, p, const Offset(123, 58), 10, 12, false);
    if (p.glasses) _glasses(c);

    // nostrils + mouth
    final nos = _fill(const Color(0xFF8D96B8));
    c.drawOval(Rect.fromCenter(center: const Offset(104, 81), width: 5.5, height: 4), nos);
    c.drawOval(Rect.fromCenter(center: const Offset(122, 80), width: 5.5, height: 4), nos);
    _mouth(c, p.mouth);

    // spiky forelock (blue / red / purple) over the horn base
    final fb = Offset(math.sin(p.time * 3.0) * 1.4, math.cos(p.time * 3.0) * 0.8) + Offset(0, p.mane * 0.35);
    _tuft(c, const Offset(94, 28), const Offset(76, 28), const Offset(66, 44) + fb, 11, blue);
    _tuft(c, const Offset(98, 30), const Offset(86, 38), const Offset(80, 48) + fb, 8, purple);
    _tuft(c, const Offset(106, 26), const Offset(98, 38), const Offset(96, 50) + fb, 11, red);
    _tuft(c, const Offset(114, 26), const Offset(114, 38), const Offset(110, 49) + fb, 9, red);
    _tuft(c, const Offset(122, 27), const Offset(128, 36), const Offset(126, 46) + fb, 8, red);
    _tuft(c, const Offset(126, 28), const Offset(142, 30), const Offset(150, 44) + fb, 10, blue);

    _brow(c, p, const Offset(90, 58), true);
    _brow(c, p, const Offset(123, 57), false);

    if (p.tear >= 0) {
      final tp = p.tear;
      final alpha = (1 - tp * tp).clamp(0.0, 1.0);
      _drop(c, Offset(82, 72 + tp * 18), 4.5, alpha);
      _drop(c, Offset(132, 71 + tp * 18), 4.5, alpha);
    }
    if (p.sweat) {
      final bob = math.sin(p.time * 4) * 1.5;
      _drop(c, Offset(150, 42 + bob), 6.5, 1);
    }
  }

  static void _ear(Canvas c, Offset base, double angle) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    c.drawPath(_leaf(12, 28), _fill(white));
    c.drawPath(_leaf(12, 28), _stroke);
    c.drawPath(_leaf(6, 19), _fill(earInner));
    c.restore();
  }

  static Path _leaf(double w, double len) => Path()
    ..moveTo(-w, 4)
    ..quadraticBezierTo(-w, -len * 0.6, 0, -len)
    ..quadraticBezierTo(w, -len * 0.6, w, 4)
    ..quadraticBezierTo(0, 4 + w * 0.5, -w, 4)
    ..close();

  static void _eye(Canvas c, UnicornPose p, Offset ctr, double rx, double ry, bool left) {
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    if (p.eyes == EyeMode.happy || (left && p.winkL)) {
      c.drawPath(
        Path()
          ..moveTo(ctr.dx - rx, ctr.dy + 3)
          ..quadraticBezierTo(ctr.dx, ctr.dy - ry * 1.1, ctr.dx + rx, ctr.dy + 3),
        line,
      );
      return;
    }
    final open = p.eyeOpen.clamp(0.0, 1.0);
    if (open < 0.18) {
      c.drawPath(
        Path()
          ..moveTo(ctr.dx - rx, ctr.dy)
          ..quadraticBezierTo(ctr.dx, ctr.dy + ry * 0.5, ctr.dx + rx, ctr.dy),
        line,
      );
      return;
    }
    final wide = p.eyes == EyeMode.wide;
    final h = ry * open * (wide ? 1.08 : 1);
    final w = rx * (wide ? 1.06 : 1);
    final rect = Rect.fromCenter(center: ctr, width: w * 2, height: h * 2);
    final sad = p.eyes == EyeMode.sad;
    Offset? lidA, lidB;
    c.save();
    if (sad) {
      lidA = Offset(ctr.dx - w - 2, left ? ctr.dy - ry * 0.05 : ctr.dy - ry * 0.7);
      lidB = Offset(ctr.dx + w + 2, left ? ctr.dy - ry * 0.7 : ctr.dy - ry * 0.05);
      c.clipPath(Path()
        ..moveTo(lidA.dx, lidA.dy)
        ..lineTo(lidB.dx, lidB.dy)
        ..lineTo(ctr.dx + w + 2, ctr.dy + ry + 2)
        ..lineTo(ctr.dx - w - 2, ctr.dy + ry + 2)
        ..close());
    }
    c.drawOval(rect, _fill(ink));
    final iris = rect.deflate(2.2);
    c.drawOval(
      iris,
      Paint()
        ..shader = const RadialGradient(center: Alignment(0, 0.4), radius: 0.9, colors: [Color(0xFF4F8FE0), Color(0xFF23408F)])
            .createShader(iris),
    );
    final pr = w * (wide ? 0.32 : 0.5);
    final pc = ctr + Offset(p.look.dx * w * 0.28, p.look.dy * h * 0.28);
    c.drawOval(Rect.fromCenter(center: pc, width: pr * 2, height: pr * 2.1), _fill(const Color(0xFF0B1030)));
    // one simple catch-light keeps the eyes alive without looking glossy/doll-like
    c.drawCircle(pc + Offset(-w * 0.3, -h * 0.32), w * 0.24, _fill(white));
    c.restore();
    if (sad) {
      c.drawLine(lidA! + const Offset(2, 0), lidB! - const Offset(2, 0), _stroke);
    } else {
      c.drawOval(rect, Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
    }
  }

  static void _glasses(Canvas c) {
    final rim = Paint()
      ..color = deepBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    final lens = _fill(const Color(0x22FFFFFF));
    const l = Offset(90, 58), r = Offset(123, 57);
    c.drawCircle(l, 15.5, lens);
    c.drawCircle(r, 16.5, lens);
    c.drawCircle(l, 15.5, rim);
    c.drawCircle(r, 16.5, rim);
    c.drawPath(
      Path()
        ..moveTo(104.5, 56)
        ..quadraticBezierTo(106, 52, 107.5, 55),
      rim,
    );
    c.drawLine(const Offset(74.5, 56), const Offset(67, 52), rim);
    c.drawLine(const Offset(139.5, 55), const Offset(146, 51), rim);
    c.drawArc(Rect.fromCircle(center: r, radius: 12), 3.7, 0.9, false, Paint()
      ..color = const Color(0xAAFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
  }

  static void _brow(Canvas c, UnicornPose p, Offset eye, bool left) {
    final by = eye.dy - 17 - p.browRaise * 4;
    final inner = left ? 1.0 : -1.0;
    // neutral, level brows by default; browSad lifts the inner ends
    final tilt = p.browSad * 4;
    final a = Offset(eye.dx - 7 * inner, by + tilt);
    final b = Offset(eye.dx + 6 * inner, by - tilt);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(eye.dx, by - 1.6, b.dx, b.dy),
      Paint()
        ..color = brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _mouth(Canvas c, MouthMode mode) {
    const m = Offset(113, 91);
    switch (mode) {
      case MouthMode.smile:
        c.drawPath(
          Path()
            ..moveTo(m.dx - 10, m.dy - 1)
            ..quadraticBezierTo(m.dx, m.dy + 7, m.dx + 10, m.dy - 3),
          _stroke,
        );
        break;
      case MouthMode.soft:
        c.drawPath(
          Path()
            ..moveTo(m.dx - 6, m.dy)
            ..quadraticBezierTo(m.dx, m.dy + 4, m.dx + 6, m.dy - 1),
          _stroke,
        );
        break;
      case MouthMode.open:
        final path = Path()
          ..moveTo(m.dx - 12, m.dy - 3)
          ..quadraticBezierTo(m.dx, m.dy - 1, m.dx + 12, m.dy - 4)
          ..quadraticBezierTo(m.dx + 2, m.dy + 13, m.dx - 12, m.dy - 3)
          ..close();
        c.drawPath(path, _fill(const Color(0xFF6E1F31)));
        c.save();
        c.clipPath(path);
        c.drawOval(Rect.fromCenter(center: m + const Offset(1, 7), width: 13, height: 7), _fill(const Color(0xFFFF7A93)));
        c.restore();
        c.drawPath(path, _stroke);
        break;
      case MouthMode.frown:
        c.drawPath(
          Path()
            ..moveTo(m.dx - 8, m.dy + 5)
            ..quadraticBezierTo(m.dx, m.dy - 3, m.dx + 8, m.dy + 5),
          _stroke,
        );
        break;
      case MouthMode.o:
        final o = Rect.fromCenter(center: m + const Offset(0, 3), width: 8, height: 10);
        c.drawOval(o, _fill(const Color(0xFF6E1F31)));
        c.drawOval(o, _stroke);
        break;
      case MouthMode.flat:
        c.drawPath(
          Path()
            ..moveTo(m.dx - 7, m.dy + 2)
            ..quadraticBezierTo(m.dx, m.dy + 3, m.dx + 7, m.dy),
          _stroke,
        );
        break;
    }
  }

  static void _drop(Canvas c, Offset at, double r, double alpha) {
    final path = Path()
      ..moveTo(at.dx, at.dy - r * 1.3)
      ..quadraticBezierTo(at.dx + r, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx - r, at.dy, at.dx, at.dy - r * 1.3)
      ..close();
    c.drawPath(path, _fill(const Color(0xFF8CCBFF).withOpacity(alpha)));
    c.drawPath(path, Paint()
      ..color = ink.withOpacity(alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
    c.drawCircle(at + Offset(-r * 0.3, -r * 0.1), r * 0.25, _fill(white.withOpacity(alpha)));
  }

  static void _dust(Canvas c, UnicornPose p) {
    for (int i = 0; i < 4; i++) {
      final ph = (p.dustT + i / 4) % 1.0;
      final r = 4 + ph * 7;
      c.drawCircle(Offset(80 - ph * 40, 188 - ph * 8), r, _fill(Color.fromRGBO(196, 202, 222, 0.6 * (1 - ph))));
    }
  }

  static void _speedLines(Canvas c, UnicornPose p) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final ph = (p.dustT * 1.3 + i / 3) % 1.0;
      final y = 112.0 + i * 16;
      final x = 44 - ph * 22;
      paint.color = const Color(0xFF9AA6C8).withOpacity(0.7 * (1 - ph));
      c.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x - 10, y - 3, x - 22 + i * 3, y + 1),
        paint,
      );
    }
  }

  // ── emotes ───────────────────────────────────────────────────────────

  static void _emote(Canvas c, UnicornPose p, bool flipped) {
    if (p.emote == Emote.none) return;
    final t = p.emoteT;
    final pop = Curves.easeOutBack.transform((t * 3).clamp(0.0, 1.0));
    const anchor = Offset(158, -14);

    void textBubble(TextPainter tp, Color bg, Color border, double scale) {
      c.save();
      c.translate(anchor.dx, anchor.dy);
      c.scale(pop * scale);
      c.drawCircle(Offset.zero, 13, _fill(bg));
      c.drawCircle(Offset.zero, 13, Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
      if (flipped) c.scale(-1, 1);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }

    switch (p.emote) {
      case Emote.stars:
        for (int i = 0; i < 2; i++) {
          final tw = 1 + math.sin(t * 5 + i * 2) * 0.18;
          _starPath(c, Offset(160 + i * 12.0, -8 + i * 16.0), (9 - i * 2.5) * pop * tw, _fill(gold));
        }
        break;
      case Emote.hearts:
        for (int i = 0; i < 3; i++) {
          final ph = (t * 0.7 + i / 3) % 1.0;
          final pos = Offset(124 + i * 18 + math.sin(ph * 6.28) * 4, 4 - ph * 36);
          _heart(c, pos, 7 * (0.75 + 0.25 * (1 - ph)), const Color(0xFFFF4D6D).withOpacity(1 - ph));
        }
        break;
      case Emote.heart:
        final beat = 1 + math.max(0, math.sin(t * 6)) * 0.14;
        _heart(c, Offset(156, 6 + math.sin(t * 2) * 2), 9 * pop * beat, const Color(0xFFF2385A));
        break;
      case Emote.sparkles:
        const spots = [Offset(62, 10), Offset(164, 18), Offset(76, -14), Offset(156, -16), Offset(132, -28)];
        for (int i = 0; i < spots.length; i++) {
          final tw = (math.sin(t * 6 + i * 1.7) + 1) / 2;
          _sparkle(c, spots[i], (3 + tw * 5) * pop, i.isEven ? gold : const Color(0xFF8B7BFF));
        }
        break;
      case Emote.burst:
        // excited motion strokes on both sides of the head
        final len = (7 + math.sin(t * 10) * 2.5) * pop;
        final paint = Paint()
          ..color = gold
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        for (final side in [
          (const Offset(60, 18), math.pi * 1.15),
          (const Offset(152, 4), math.pi * 1.85),
        ]) {
          for (int i = -1; i <= 1; i++) {
            final a = side.$2 + i * 0.42;
            final dir = Offset(math.cos(a), math.sin(a));
            final from = side.$1 + dir * 6;
            c.drawLine(from, from + dir * len, paint);
          }
        }
        break;
      case Emote.confetti:
        const cols = [Color(0xFFF6B42A), Color(0xFFE5384D), Color(0xFF2F5BEA), Color(0xFF7246E8), Color(0xFF2EC4A6)];
        for (int i = 0; i < 12; i++) {
          final ph = (t * 0.55 + i * 0.137) % 1.0;
          final x = 40 + (i * 53 % 140) + math.sin(ph * 9 + i) * 6;
          final y = -30 + ph * 150;
          c.save();
          c.translate(x.toDouble(), y);
          c.rotate(ph * 10 + i);
          c.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -1.6, 6, 3.2), const Radius.circular(1)),
            _fill(cols[i % cols.length].withOpacity(ph > 0.8 ? (1 - ph) * 5 : 1)),
          );
          c.restore();
        }
        break;
      case Emote.bulb:
        c.save();
        c.translate(anchor.dx - 2, anchor.dy + 4 + math.sin(t * 2) * 2);
        c.scale(pop);
        final glow = (math.sin(t * 4) + 1) / 2;
        final ray = Paint()
          ..color = gold
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 5; i++) {
          final a = math.pi * (1.1 + i * 0.2);
          final d = Offset(math.cos(a), math.sin(a));
          c.drawLine(d * 13, d * (17 + glow * 3), ray);
        }
        c.drawCircle(const Offset(0, -1), 9.5, _fill(const Color(0xFFFFE27A)));
        c.drawCircle(const Offset(0, -1), 9.5, _stroke);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 7, 10, 7), const Radius.circular(2)), _fill(const Color(0xFFB8C0D8)));
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 7, 10, 7), const Radius.circular(2)), _stroke);
        c.drawPath(
          Path()
            ..moveTo(-3, 4)
            ..lineTo(-1.5, -2)
            ..lineTo(1.5, 1)
            ..lineTo(3, -3),
          Paint()
            ..color = const Color(0xFFE29A12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
        c.restore();
        break;
      case Emote.cloud:
        c.save();
        c.translate(anchor.dx, anchor.dy + 4 + math.sin(t * 2) * 2);
        c.scale(pop);
        final cl = Path()
          ..addOval(Rect.fromCircle(center: const Offset(-10, 0), radius: 8))
          ..addOval(Rect.fromCircle(center: const Offset(0, -5), radius: 10))
          ..addOval(Rect.fromCircle(center: const Offset(11, 0), radius: 8))
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -2, 37, 10), const Radius.circular(5)));
        c.drawPath(cl, _fill(const Color(0xFFC3CBDD)));
        for (int i = 0; i < 3; i++) {
          final ph = (t * 1.5 + i / 3) % 1.0;
          c.drawLine(
            Offset(-9 + i * 9.0, 11 + ph * 12),
            Offset(-10 + i * 9.0, 15 + ph * 12),
            Paint()
              ..color = const Color(0xFF6FB6FF).withOpacity(1 - ph)
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round,
          );
        }
        c.restore();
        break;
      case Emote.exclaim:
        textBubble(_exText, gold, ink, 1);
        break;
      case Emote.exclaimUrgent:
        textBubble(_exExText, const Color(0xFFE5484D), ink, 1 + math.sin(t * 12) * 0.07);
        break;
      case Emote.question:
        c.save();
        c.translate(anchor.dx, anchor.dy + math.sin(t * 2.5) * 2);
        c.rotate(0.15 + math.sin(t * 2) * 0.08);
        c.scale(pop);
        if (flipped) c.scale(-1, 1);
        _qText.paint(c, Offset(-_qText.width / 2, -_qText.height / 2));
        c.restore();
        break;
      case Emote.none:
        break;
    }
  }

  static void _starPath(Canvas c, Offset ctr, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = i * math.pi / 5 - math.pi / 2;
      final pt = ctr + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), paint);
  }

  static void _heart(Canvas c, Offset at, double s, Color color) {
    final path = Path()
      ..moveTo(at.dx, at.dy + s * 0.9)
      ..cubicTo(at.dx - s * 1.6, at.dy - s * 0.2, at.dx - s * 0.6, at.dy - s * 1.3, at.dx, at.dy - s * 0.4)
      ..cubicTo(at.dx + s * 0.6, at.dy - s * 1.3, at.dx + s * 1.6, at.dy - s * 0.2, at.dx, at.dy + s * 0.9)
      ..close();
    c.drawPath(path, _fill(color));
  }

  static void _sparkle(Canvas c, Offset at, double r, Color color) {
    final path = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    c.drawPath(path, _fill(color));
  }
}
