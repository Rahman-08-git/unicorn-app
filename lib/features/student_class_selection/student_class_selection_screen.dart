/// Student class selection: Pre-Primary, Class 1–12 + College as large touch tiles.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class StudentClassSelectionScreen extends StatefulWidget {
  const StudentClassSelectionScreen({super.key});

  @override
  State<StudentClassSelectionScreen> createState() => _StudentClassSelectionScreenState();
}

class _Band {
  const _Band(this.name, this.color, this.soft);
  final String name;
  final Color color;
  final Color soft;
}

const _prePrimary = _Band('Early Years', Color(0xFFEA580C), Color(0xFFFFEDD5));
const _primary = _Band('Primary', Color(0xFF16A34A), Color(0xFFE7F7EC));
const _middle = _Band('Middle', Color(0xFF2563EB), Color(0xFFE8F0FF));
const _secondary = _Band('Secondary', AppColors.primaryViolet, AppColors.softViolet);
const _senior = _Band('Senior', Color(0xFFDB2777), Color(0xFFFDE8F2));
const _college = _Band('Higher Ed', Color(0xFFB45309), AppColors.softGold);

_Band _bandFor(String code) {
  if (code == 'COLLEGE') return _college;
  if (code == 'PRE_PRIMARY') return _prePrimary;
  final n = int.parse(code.split('_').last);
  if (n <= 5) return _primary;
  if (n <= 8) return _middle;
  if (n <= 10) return _secondary;
  return _senior;
}

String _displayName(String code) {
  if (code == 'COLLEGE') return 'College';
  if (code == 'PRE_PRIMARY') return 'Pre-Primary';
  return 'Class ${code.split('_').last}';
}

/// Icon shown instead of a class number (null → show the number).
IconData? _iconFor(String code) {
  if (code == 'COLLEGE') return Icons.school_rounded;
  if (code == 'PRE_PRIMARY') return Icons.child_care_rounded;
  return null;
}

class _StudentClassSelectionScreenState extends State<StudentClassSelectionScreen> {
  String? _selectedLevel;
  bool _isStarting = false;

  Future<void> _startChallenge() async {
    if (_selectedLevel == null || _isStarting) return;
    setState(() => _isStarting = true);
    final session = context.read<SessionService>();
    final ok = await session.registerStudent(classLevel: _selectedLevel!);
    if (!ok && mounted) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastStartError ?? 'Something went wrong. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selectedLevel;
    final studentName = context.read<SessionService>().pendingStudentName;
    final firstName = studentName?.split(RegExp(r'\s+')).first;
    return UllScaffold(
      onBack: () => context.read<SessionService>().goToStudentNameEntry(),
      tint: const Color(0xFFE8F0FF),
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight;
        final cols = landscape ? 7 : 4;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WHAT ARE YOU STUDYING?',
                          style: TextStyle(color: AppColors.deepInkNavy, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                        ),
                        SizedBox(height: 6),
                        Text('Choose your class to find your challenge.',
                            style: TextStyle(color: AppColors.secondaryText, fontSize: 17)),
                      ],
                    ),
                  ),
                  if (c.maxWidth > 700)
                    UnicornMascot(
                      state: sel != null ? MascotState.celebration : MascotState.curious,
                      width: 260,
                      height: 120,
                      faceLeft: true,
                      bubbleSide: BubbleSide.left,
                      message: sel != null
                          ? '${_displayName(sel)}! Your challenge is ready.'
                          : (firstName != null
                              ? 'Hi $firstName! Five questions, made just for your class!'
                              : 'Five questions, made just for your class!'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: landscape ? 1.0 : 1.05,
                ),
                itemCount: AppConstants.studentClassLevels.length,
                itemBuilder: (context, i) {
                  final code = AppConstants.studentClassLevels[i];
                  return FadeSlideIn(
                    index: i,
                    offset: const Offset(0, 20),
                    child: _ClassTile(
                      code: code,
                      selected: sel == code,
                      onTap: () => setState(() => _selectedLevel = code),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            UllButton(
              label: sel != null ? 'START ${_displayName(sel).toUpperCase()} CHALLENGE' : 'SELECT YOUR CLASS TO START',
              icon: sel != null ? Icons.arrow_forward_rounded : null,
              expand: true,
              loading: _isStarting,
              onPressed: (sel != null && !_isStarting) ? _startChallenge : null,
            ),
          ],
        );
      }),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.code, required this.selected, required this.onTap});
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = _bandFor(code);
    final icon = _iconFor(code);
    final fg = selected ? Colors.white : band.color;
    return AnimatedScale(
      duration: Motion.base,
      curve: Motion.pop,
      scale: selected ? 1.05 : 1,
      child: Pressable(
        onTap: onTap,
        semanticLabel: _displayName(code),
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.enter,
          decoration: BoxDecoration(
            color: selected ? band.color : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? band.color : AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: selected ? band.color.withOpacity(0.35) : const Color(0x0D101C3A),
                blurRadius: selected ? 24 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: selected
                      ? const Icon(Icons.check_circle_rounded, key: ValueKey(1), color: Colors.white, size: 22)
                      : const SizedBox.shrink(key: ValueKey(0)),
                ),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon != null
                            ? Icon(icon, size: 46, color: fg)
                            : Text(
                                code.split('_').last,
                                style: TextStyle(color: fg, fontSize: 44, fontWeight: FontWeight.w900, height: 1),
                              ),
                        const SizedBox(height: 8),
                        Text(
                          _displayName(code),
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.deepInkNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          band.name.toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.white.withOpacity(0.85) : AppColors.secondaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
