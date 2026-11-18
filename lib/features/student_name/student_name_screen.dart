/// Student name entry: shown after picking "Student", before class selection.
/// The name is optional — students can tap "Skip" to go straight to their class.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class StudentNameScreen extends StatefulWidget {
  const StudentNameScreen({super.key});

  @override
  State<StudentNameScreen> createState() => _StudentNameScreenState();
}

class _StudentNameScreenState extends State<StudentNameScreen> {
  static const _accent = Color(0xFF2563EB);
  static const _soft = Color(0xFFE8F0FF);

  late final TextEditingController _nameController;
  String _name = '';

  bool get _hasName => _name.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Keep the name if the student came back from class selection.
    _name = context.read<SessionService>().pendingStudentName ?? '';
    _nameController = TextEditingController(text: _name);
    _nameController.addListener(() {
      if (_nameController.text != _name) setState(() => _name = _nameController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue({bool skip = false}) {
    FocusScope.of(context).unfocus();
    context.read<SessionService>().submitStudentName(skip ? null : _name);
  }

  String get _firstName => _name.trim().split(RegExp(r'\s+')).first;

  @override
  Widget build(BuildContext context) {
    final mascotMsg = _hasName ? 'Hi $_firstName! Let\'s pick your class.' : 'Hi there! What\'s your name?';

    return UllScaffold(
      onBack: () => context.read<SessionService>().goToAudienceSelection(),
      tint: _soft,
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 760;
        final form = FadeSlideIn(index: 1, child: _buildForm());
        final guide = FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UllPill(text: 'Student Pathway', icon: Icons.backpack_rounded, color: _accent, background: _soft),
              const SizedBox(height: 20),
              UnicornMascot(
                state: _hasName ? MascotState.celebration : MascotState.curious,
                width: landscape ? double.infinity : 240,
                height: landscape ? 230 : 120,
                message: mascotMsg,
                bubbleSide: landscape ? BubbleSide.top : BubbleSide.right,
              ),
            ],
          ),
        );

        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: landscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 4, child: guide),
                        const SizedBox(width: 40),
                        Expanded(flex: 6, child: form),
                      ],
                    )
                  : Column(children: [guide, const SizedBox(height: 24), form]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildForm() {
    return UllCard(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "WHAT'S YOUR NAME?",
            style: TextStyle(color: AppColors.deepInkNavy, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type your name, then choose your class on the next screen.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 28),
          const Text('Your name', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('student_name'),
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            onSubmitted: (_) {
              if (_hasName) _continue();
            },
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.deepInkNavy),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded),
              suffixIcon: AnimatedSwitcher(
                duration: Motion.base,
                child: _hasName
                    ? const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), color: AppColors.success, size: 28)
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              hintText: 'e.g. Aarav',
              hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.45)),
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _accent, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          UllButton(
            label: 'NEXT: CHOOSE YOUR CLASS',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            color: _accent,
            onPressed: _hasName ? _continue : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('student_name_skip'),
            onPressed: () => _continue(skip: true),
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
