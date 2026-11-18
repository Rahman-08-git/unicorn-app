/// PIN verification dialog protecting the Operator Dashboard.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/operator_dashboard_screen.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';

class OperatorPinDialog extends StatefulWidget {
  const OperatorPinDialog({super.key});

  @override
  State<OperatorPinDialog> createState() => _OperatorPinDialogState();
}

class _OperatorPinDialogState extends State<OperatorPinDialog> {
  final _pinController = TextEditingController();
  int _failedAttempts = 0;
  String? _errorMessage;
  bool _isLockedOut = false;

  void _verifyPin(String correctPin) {
    if (_isLockedOut) return;

    final entered = _pinController.text.trim();
    if (entered == correctPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OperatorDashboardScreen(),
        ),
      );
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        setState(() {
          _isLockedOut = true;
          _errorMessage = 'Too many incorrect attempts. Locked for 60 seconds.';
        });
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) {
            setState(() {
              _isLockedOut = false;
              _failedAttempts = 0;
              _errorMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Attempts remaining: ${5 - _failedAttempts}';
          _pinController.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionService>();
    final correctPin = session.config.operatorPin;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primaryViolet),
          SizedBox(width: 10),
          Text('Operator Access'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the 4-digit operator PIN to access campaign administration.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            autofocus: true,
            enabled: !_isLockedOut,
            decoration: InputDecoration(
              labelText: 'Operator PIN',
              errorText: _errorMessage,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _verifyPin(correctPin),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLockedOut ? null : () => _verifyPin(correctPin),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryViolet,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
