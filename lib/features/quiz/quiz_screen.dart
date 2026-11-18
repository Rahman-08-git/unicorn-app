/// Quiz screen: one question at a time, 60-second deadline timer, locked
/// single submission, inline feedback and context-aware mascot.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/models/answer.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/question_bank_editor.dart' show audienceLabel;
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/quiz_timer_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionService>().onTimeoutOccurred = _onTimeout;
    });
  }

  void _onTimeout() {
    if (mounted) HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Deadline-based: time spent in background still counts.
      context.read<SessionService>().timerService.handleAppResume();
    }
  }

  Future<void> _answer(String id) async {
    final session = context.read<SessionService>();
    if (session.isAnswerLocked) return;
    await session.submitAnswer(id);
    if (session.recordedAnswers.isNotEmpty) {
      session.recordedAnswers.last.isCorrect ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
    }
  }

  Future<void> _next() async {
    if (_advancing) return;
    _advancing = true;
    await context.read<SessionService>().nextQuestionOrResults();
    if (mounted) _advancing = false;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final timer = session.timerService;
    final question = session.currentQuestion;
    if (question == null) {
      return const Scaffold(backgroundColor: AppColors.offWhite, body: Center(child: CircularProgressIndicator()));
    }

    final idx = session.currentQuestionIndex;
    final locked = session.isAnswerLocked;
    final Answer? last = locked && session.recordedAnswers.length > idx ? session.recordedAnswers[idx] : null;
    final isLast = idx == AppConstants.questionsPerAttempt - 1;

    // ── Mascot state + message (context aware) ─────────────────────────
    MascotState mState;
    String mMsg;
    if (last != null) {
      if (last.isTimeout) {
        mState = MascotState.questionTimeout;
        mMsg = 'Time flew by! Let\'s keep going.';
      } else if (last.isCorrect) {
        mState = MascotState.correctAnswer;
        mMsg = isLast ? 'Brilliant finish!' : 'Yes! You nailed it!';
      } else {
        mState = MascotState.incorrectAnswer; // sad for a moment, then cheers up
        mMsg = 'Aww, so close! Every answer teaches us something.';
      }
    } else if (timer.isUrgent) {
      mState = MascotState.timerUrgent;
      mMsg = 'Quick! Trust your instinct!';
    } else if (timer.isWarning) {
      mState = MascotState.timerWarning;
      mMsg = '15 seconds left. You\'ve got this!';
    } else {
      mState = MascotState.thinking;
      mMsg = isLast ? 'Last one! Make it count.' : (idx == 0 ? 'Here\'s your first challenge!' : 'Next challenge, coming up!');
    }

    final feedback = last == null
        ? null
        : _FeedbackPanel(
            answer: last,
            explanation: question.explanation,
            isLast: isLast,
            onNext: _next,
          );

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: UllBackground(
        tint: timer.isUrgent && !locked ? const Color(0xFFFDECEC) : AppColors.softViolet,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 800;
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 20),
              child: Column(
                children: [
                  _Header(session: session, timer: timer, locked: locked),
                  const SizedBox(height: 18),
                  Expanded(
                    child: landscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 7, child: _questionArea(session, question, landscape: true)),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: math.min(340, c.maxWidth * 0.28),
                                child: _SidePanel(state: mState, message: mMsg, feedback: feedback),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              UnicornMascot(state: mState, width: 230, height: 110, message: mMsg, bubbleSide: BubbleSide.right),
                              const SizedBox(height: 14),
                              Expanded(child: _questionArea(session, question, landscape: false)),
                              if (feedback != null) ...[const SizedBox(height: 14), feedback],
                            ],
                          ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _questionArea(SessionService session, Question q, {required bool landscape}) {
    final idx = session.currentQuestionIndex;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.screen),
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
      ),
      layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev.map((p) => IgnorePointer(child: p)), if (cur != null) cur]),
      child: _QuestionCard(
        key: ValueKey('q$idx-${q.id}'),
        index: idx,
        question: q,
        selectedId: session.selectedAnswerId,
        locked: session.isAnswerLocked,
        landscape: landscape,
        onSelect: _answer,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Header: question counter, segmented progress, ring timer
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.timer, required this.locked});
  final SessionService session;
  final QuizTimerService timer;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    const total = AppConstants.questionsPerAttempt;
    final idx = session.currentQuestionIndex;
    final p = session.currentParticipant;
    final category = p?.classLevel == null
        ? (p?.audienceCategory.label ?? 'Challenge')
        : audienceLabel(p!.classLevel!);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            UllPill(text: category.toUpperCase(), icon: Icons.bolt_rounded),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.deepInkNavy, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                children: [
                  const TextSpan(text: 'QUESTION ', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                  TextSpan(text: (idx + 1).toString().padLeft(2, '0'), style: const TextStyle(fontSize: 26)),
                  TextSpan(text: ' / ${total.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Row(
            children: List.generate(total, (i) {
              Color fill = AppColors.border;
              double amount = 0;
              if (i < session.recordedAnswers.length) {
                final a = session.recordedAnswers[i];
                fill = a.isCorrect ? AppColors.success : (a.isTimeout ? AppColors.warmGold : const Color(0xFFF97066));
                amount = 1;
              } else if (i == idx) {
                fill = AppColors.primaryViolet;
                amount = 1 - timer.progress;
              }
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFFE9EBF2), borderRadius: BorderRadius.circular(99)),
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: amount.clamp(0.0, 1.0)),
                    duration: Motion.of(context, const Duration(milliseconds: 400)),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99))),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 28),
        _RingTimer(timer: timer, paused: locked),
      ],
    );
  }
}

class _RingTimer extends StatelessWidget {
  const _RingTimer({required this.timer, required this.paused});
  final QuizTimerService timer;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final color = paused
        ? AppColors.secondaryText
        : (timer.isUrgent ? AppColors.error : (timer.isWarning ? const Color(0xFFD97706) : AppColors.primaryViolet));
    const size = 84.0;
    final ring = TweenAnimationBuilder<double>(
      tween: Tween(end: timer.progress),
      duration: Motion.of(context, paused ? Motion.fast : const Duration(milliseconds: 1000)),
      builder: (_, v, __) => CustomPaint(
        painter: _RingPainter(v, color),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: Motion.fast,
                  style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, height: 1),
                  child: Text('${timer.remainingSeconds}'),
                ),
                const Text('SEC', style: TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );

    // Gentle heartbeat when urgent.
    if (timer.isUrgent && !paused && !Motion.reduced(context)) {
      return TweenAnimationBuilder<double>(
        key: ValueKey(timer.remainingSeconds),
        tween: Tween(begin: 1.1, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: ring,
      );
    }
    return ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 5;
    canvas.drawCircle(c, r + 5, Paint()..color = Colors.white);
    canvas.drawCircle(c, r, Paint()
      ..color = color.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Question card + options
// ═══════════════════════════════════════════════════════════════════════════

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.selectedId,
    required this.locked,
    required this.landscape,
    required this.onSelect,
  });

  final int index;
  final Question question;
  final String? selectedId;
  final bool locked;
  final bool landscape;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final opts = question.options;
    Widget option(int i) => FadeSlideIn(
          index: i + 1,
          offset: const Offset(0, 16),
          child: _OptionCard(
            letter: String.fromCharCode(65 + i),
            option: opts[i],
            isCorrectOption: opts[i].id == question.correctAnswerId,
            selected: selectedId == opts[i].id,
            locked: locked,
            onTap: () => onSelect(opts[i].id),
          ),
        );

    return UllCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QUESTION ${index + 1} OF ${AppConstants.questionsPerAttempt}',
            style: const TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.8),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: landscape ? FlexFit.tight : FlexFit.loose,
            child: Align(
             alignment: Alignment.centerLeft,
             child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.question,
                    style: const TextStyle(color: AppColors.deepInkNavy, fontWeight: FontWeight.w800, fontSize: 30, height: 1.3),
                  ),
                  if (question.description != null && question.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(question.description!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 16, height: 1.4)),
                  ],
                ],
              ),
             ),
            ),
          ),
          const SizedBox(height: 22),
          if (landscape && opts.length == 4)
            Column(
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: option(0)), const SizedBox(width: 14), Expanded(child: option(1))]),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: option(2)), const SizedBox(width: 14), Expanded(child: option(3))]),
              ],
            )
          else
            for (int i = 0; i < opts.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: option(i)),
        ],
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  const _OptionCard({
    required this.letter,
    required this.option,
    required this.isCorrectOption,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String letter;
  final QuestionOption option;
  final bool isCorrectOption;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(covariant _OptionCard old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected && !Motion.reduced(context)) _fx.forward(from: 0);
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final sel = widget.selected;
    // After locking: selected-correct → green; selected-wrong → red;
    // the correct option is revealed in green so the learner sees the answer.
    final showCorrect = locked && widget.isCorrectOption;
    final showWrong = locked && sel && !widget.isCorrectOption;
    final faded = locked && !showCorrect && !showWrong;

    Color border = AppColors.border;
    Color bg = Colors.white;
    Color badgeBg = AppColors.softViolet;
    Color badgeFg = AppColors.primaryViolet;
    IconData? trail;
    if (showCorrect) {
      border = AppColors.success;
      bg = const Color(0xFFE9F7EF);
      badgeBg = AppColors.success;
      badgeFg = Colors.white;
      trail = Icons.check_circle_rounded;
    } else if (showWrong) {
      border = AppColors.error;
      bg = const Color(0xFFFDEEEC);
      badgeBg = AppColors.error;
      badgeFg = Colors.white;
      trail = Icons.cancel_rounded;
    }

    final card = AnimatedContainer(
      duration: Motion.base,
      curve: Motion.enter,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: (showCorrect || showWrong) ? 2.5 : 1.5),
        boxShadow: (showCorrect || showWrong)
            ? [BoxShadow(color: border.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))]
            : const [BoxShadow(color: Color(0x08101C3A), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Motion.base,
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(widget.letter, style: TextStyle(color: badgeFg, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.option.text,
              style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700, fontSize: 18, height: 1.3),
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.base,
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: c),
            child: trail == null
                ? const SizedBox(width: 30, key: ValueKey('none'))
                : Icon(trail, key: ValueKey(trail), color: border, size: 30),
          ),
        ],
      ),
    );

    return AnimatedOpacity(
      duration: Motion.base,
      opacity: faded ? 0.5 : 1,
      child: AnimatedBuilder(
        animation: _fx,
        child: Pressable(onTap: locked ? null : widget.onTap, semanticLabel: 'Option ${widget.letter}: ${widget.option.text}', child: card),
        builder: (_, child) {
          final t = _fx.value;
          if (t == 0 || t == 1) return child!;
          if (widget.isCorrectOption) {
            return Transform.scale(scale: 1 + math.sin(t * math.pi) * 0.04, child: child);
          }
          // gentle shake for a wrong pick (never harsh)
          return Transform.translate(offset: Offset(math.sin(t * math.pi * 5) * 6 * (1 - t), 0), child: child);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Side panel (mascot + feedback) and feedback panel
// ═══════════════════════════════════════════════════════════════════════════

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.state, required this.message, required this.feedback});
  final MascotState state;
  final String message;
  final Widget? feedback;

  @override
  Widget build(BuildContext context) {
    return UllCard(
      padding: const EdgeInsets.all(22),
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.base,
                      child: SpeechBubble(key: ValueKey(message), text: message, maxWidth: 280),
                    ),
                    const SizedBox(height: 16),
                    UnicornMascot(state: state, width: double.infinity, height: 210, faceLeft: true),
                  ],
                ),
              ),
            ),
          ),
          if (feedback != null) feedback!,
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.answer, required this.explanation, required this.isLast, required this.onNext});
  final Answer answer;
  final String? explanation;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final timeout = answer.isTimeout;
    final ok = answer.isCorrect;
    final color = ok ? AppColors.success : (timeout ? const Color(0xFFD97706) : AppColors.primaryViolet);
    final title = ok ? 'Excellent Thinking!' : (timeout ? "Time's Up!" : 'Good Try!');
    final sub = ok
        ? 'You discovered the correct solution!'
        : (timeout ? 'No worries — let\'s explore the next one.' : 'Every question is a chance to discover something new.');

    return FadeSlideIn(
      offset: const Offset(0, 30),
      duration: Motion.base,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.celebration_rounded : (timeout ? Icons.timer_off_rounded : Icons.lightbulb_rounded), color: color, size: 26),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20))),
              ],
            ),
            const SizedBox(height: 6),
            Text(sub, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, height: 1.35)),
            if (explanation != null && explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(explanation!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 14),
            UllButton(
              label: 'Next',
              icon: isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
              height: 54,
              expand: true,
              color: AppColors.deepInkNavy,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
