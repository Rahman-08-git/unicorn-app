/// Navigation and screen routing for the Unicorn Learning Lab application.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/features/audience_selection/audience_selection_screen.dart';
import 'package:unicorn_learning_lab/features/education_intro/education_intro_screen.dart';
import 'package:unicorn_learning_lab/features/quiz/quiz_screen.dart';
import 'package:unicorn_learning_lab/features/registration/registration_screen.dart';
import 'package:unicorn_learning_lab/features/results/results_screen.dart';
import 'package:unicorn_learning_lab/features/rewards/reward_reveal_screen.dart';
import 'package:unicorn_learning_lab/features/student_class_selection/student_class_selection_screen.dart';
import 'package:unicorn_learning_lab/features/student_name/student_name_screen.dart';
import 'package:unicorn_learning_lab/features/thank_you/thank_you_screen.dart';
import 'package:unicorn_learning_lab/features/welcome/welcome_screen.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild when the stage changes (not on every timer tick).
    final stage = context.select<SessionService, SessionStage>((s) => s.currentStage);
    final reduced = Motion.reduced(context);

    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : Motion.screen,
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous.map((w) => IgnorePointer(child: w)), if (current != null) current],
      ),
      child: KeyedSubtree(key: ValueKey(stage), child: _screenFor(stage)),
    );
  }

  Widget _screenFor(SessionStage stage) {
    switch (stage) {
      case SessionStage.welcome:
        return const WelcomeScreen();
      case SessionStage.audienceSelection:
        return const AudienceSelectionScreen();
      case SessionStage.parentRegistration:
        return const RegistrationScreen(category: AudienceCategory.parent);
      case SessionStage.guardianRegistration:
        return const RegistrationScreen(category: AudienceCategory.guardian);
      case SessionStage.studentNameEntry:
        return const StudentNameScreen();
      case SessionStage.studentClassSelection:
        return const StudentClassSelectionScreen();
      case SessionStage.quiz:
        return const QuizScreen();
      case SessionStage.results:
        return const ResultsScreen();
      case SessionStage.rewardReveal:
        return const RewardRevealScreen();
      case SessionStage.educationIntro:
        return const EducationIntroScreen();
      case SessionStage.thankYou:
        return const ThankYouScreen();
    }
  }
}
