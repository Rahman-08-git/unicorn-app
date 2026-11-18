/// Registration screen for Parent and Guardian flows (name + phone number, both required).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.category});

  final AudienceCategory category;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _focus = FocusNode();
  bool _isSubmitting = false;
  String _digits = '';

  /// Indian mobile numbers: 10 digits starting with 6, 7, 8 or 9.
  static final _validMobile = RegExp(r'^[6-9]\d{9}$');

  bool get _isValidPhone => _validMobile.hasMatch(_digits);

  String _name = '';

  /// A name is required: at least 2 letters after trimming.
  bool get _isValidName => _name.trim().length >= 2;

  bool get _canSubmit => _isValidPhone && _isValidName;

  String? get _error {
    if (_digits.isEmpty) return null;
    if (!RegExp(r'^[6-9]').hasMatch(_digits)) return 'Indian mobile numbers start with 6, 7, 8 or 9.';
    if (_digits.length == 10 && !_isValidPhone) return 'Please check the number.';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_nameController.text != _name) setState(() => _name = _nameController.text);
    });
    _phoneController.addListener(() {
      final d = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (d != _digits) setState(() => _digits = d);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();
    final session = context.read<SessionService>();
    final ok = await session.registerParentOrGuardian(
      category: widget.category,
      phoneNumber: '+91$_digits',
      name: _nameController.text,
    );
    if (!ok && mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastStartError ?? 'Something went wrong. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.category == AudienceCategory.parent;
    final roleName = isParent ? 'Parent' : 'Guardian';
    final accent = isParent ? AppColors.primaryViolet : const Color(0xFFB45309);
    final soft = isParent ? AppColors.softViolet : AppColors.softGold;

    final mascotMsg = _isValidPhone
        ? 'Perfect! Tap continue when you\'re ready.'
        : (_error != null ? 'Hmm, let\'s double-check that number.' : 'Your name and number, and we\'re off!');

    return UllScaffold(
      onBack: () => context.read<SessionService>().goToAudienceSelection(),
      tint: soft,
      body: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 760;
        final form = FadeSlideIn(index: 1, child: _buildForm(context, roleName, accent, soft));
        final guide = FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UllPill(text: '$roleName Pathway', icon: Icons.route_rounded, color: accent, background: soft),
              const SizedBox(height: 20),
              UnicornMascot(
                state: _canSubmit ? MascotState.celebration : (_error != null ? MascotState.encouraging : MascotState.curious),
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

  Widget _buildForm(BuildContext context, String roleName, Color accent, Color soft) {
    final error = _error;
    return UllCard(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "LET'S GET STARTED",
            style: TextStyle(color: AppColors.deepInkNavy, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your name and mobile number to begin your $roleName journey.',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 28),
          const Text('Your name', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('registration_name'),
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            onSubmitted: (_) => _focus.requestFocus(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.deepInkNavy),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded),
              hintText: 'e.g. Priya Sharma',
              hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.45)),
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Mobile number', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('registration_phone'),
            controller: _phoneController,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 3, color: AppColors.deepInkNavy),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border, width: 1.5))),
                child: const Center(
                  widthFactor: 1,
                  child: Text('+91', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.deepInkNavy)),
                ),
              ),
              suffixIcon: AnimatedSwitcher(
                duration: Motion.base,
                child: _isValidPhone
                    ? const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), color: AppColors.success, size: 28)
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              hintText: '98765 43210',
              hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.45), letterSpacing: 2),
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: error != null ? AppColors.error : AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: error != null ? AppColors.error : accent, width: 2.5),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.enter,
            child: error == null
                ? const SizedBox(width: double.infinity, height: 10)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(error, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: soft.withOpacity(0.7), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 20, color: accent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Saved only on this tablet for event records. Never sold, shared or sent online.',
                    style: TextStyle(fontSize: 13, color: AppColors.primaryText, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          UllButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            color: accent,
            loading: _isSubmitting,
            onPressed: _canSubmit && !_isSubmitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}
