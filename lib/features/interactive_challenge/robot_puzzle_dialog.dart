/// Optional interactive programming challenge: Robot Path Sequencing Puzzle.
/// Demonstrates sequencing and algorithmic thinking completely offline.
library;

import 'package:flutter/material.dart';
import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';

enum RobotCommand { moveForward, turnLeft, turnRight }

class RobotPuzzleDialog extends StatefulWidget {
  const RobotPuzzleDialog({super.key});

  @override
  State<RobotPuzzleDialog> createState() => _RobotPuzzleDialogState();
}

class _RobotPuzzleDialogState extends State<RobotPuzzleDialog> {
  // Grid size 4x4. Robot starts at (0, 3) facing North (direction 0: North, 1: East, 2: South, 3: West).
  // Target is at (2, 1).
  final List<RobotCommand> _program = [];
  int _robotX = 0;
  int _robotY = 3;
  int _robotDir = 0; // 0: N, 1: E, 2: S, 3: W
  bool _isRunning = false;
  bool _isSuccess = false;
  String? _statusFeedback;
  MascotState _mascotState = MascotState.curious;

  final int _targetX = 2;
  final int _targetY = 1;

  void _addCommand(RobotCommand cmd) {
    if (_program.length < 8 && !_isRunning && !_isSuccess) {
      setState(() {
        _program.add(cmd);
        _statusFeedback = null;
      });
    }
  }

  void _clearProgram() {
    if (!_isRunning) {
      setState(() {
        _program.clear();
        _resetRobot();
        _statusFeedback = null;
        _isSuccess = false;
        _mascotState = MascotState.curious;
      });
    }
  }

  void _resetRobot() {
    _robotX = 0;
    _robotY = 3;
    _robotDir = 0;
  }

  Future<void> _runProgram() async {
    if (_isRunning || _program.isEmpty) return;
    setState(() {
      _isRunning = true;
      _resetRobot();
      _statusFeedback = 'Running instructions...';
      _mascotState = MascotState.thinking;
    });

    for (final cmd in _program) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        switch (cmd) {
          case RobotCommand.moveForward:
            if (_robotDir == 0 && _robotY > 0) _robotY--;
            if (_robotDir == 1 && _robotX < 3) _robotX++;
            if (_robotDir == 2 && _robotY < 3) _robotY++;
            if (_robotDir == 3 && _robotX > 0) _robotX--;
            break;
          case RobotCommand.turnLeft:
            _robotDir = (_robotDir - 1 + 4) % 4;
            break;
          case RobotCommand.turnRight:
            _robotDir = (_robotDir + 1) % 4;
            break;
        }
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_robotX == _targetX && _robotY == _targetY) {
      setState(() {
        _isRunning = false;
        _isSuccess = true;
        _statusFeedback = 'Success! You guided the robot to the goal!';
        _mascotState = MascotState.celebration;
      });
    } else {
      setState(() {
        _isRunning = false;
        _isSuccess = false;
        _statusFeedback = 'Not quite there yet. Try rearranging your steps!';
        _mascotState = MascotState.encouraging;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.offWhite,
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: AppColors.primaryViolet, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Logic Challenge: Guide the Robot',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepInkNavy,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Arrange instructions to navigate from Start (bottom-left) to Star (target).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
            const SizedBox(height: 16),

            // Main Challenge Workspace
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4x4 Grid
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, index) {
                      final x = index % 4;
                      final y = index ~/ 4;
                      final isRobot = (x == _robotX && y == _robotY);
                      final isTarget = (x == _targetX && y == _targetY);

                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border.withOpacity(0.5)),
                          color: isTarget
                              ? AppColors.softGold
                              : (isRobot ? AppColors.softViolet : Colors.white),
                        ),
                        child: Center(
                          child: isRobot
                              ? _buildRobotIcon()
                              : (isTarget
                                  ? const Icon(Icons.star, color: AppColors.warmGold, size: 24)
                                  : null),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),

                // Program Sequence Area & Mascot Reaction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mascot
                      SizedBox(
                        height: 90,
                        child: Row(
                          children: [
                            UnicornMascot(
                              state: _mascotState,
                              width: 90,
                              height: 90,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  _statusFeedback ?? 'Add commands below and tap "Run" to test!',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.primaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Command Sequence Display
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _program.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sequence: (empty)',
                                  style: TextStyle(color: AppColors.secondaryText),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _program.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 4),
                                itemBuilder: (context, i) {
                                  final cmd = _program[i];
                                  return Chip(
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    backgroundColor: AppColors.softViolet,
                                    label: Text(
                                      cmd == RobotCommand.moveForward
                                          ? 'Forward'
                                          : (cmd == RobotCommand.turnLeft ? 'Left' : 'Right'),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Command Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addCommand(RobotCommand.moveForward),
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('Forward'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addCommand(RobotCommand.turnLeft),
                              icon: const Icon(Icons.rotate_left, size: 16),
                              label: const Text('Left'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addCommand(RobotCommand.turnRight),
                              icon: const Icon(Icons.rotate_right, size: 16),
                              label: const Text('Right'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _clearProgram,
                  child: const Text('Clear', style: TextStyle(color: AppColors.secondaryText)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isRunning || _program.isEmpty ? null : _runProgram,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Sequence'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryViolet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRobotIcon() {
    IconData icon;
    switch (_robotDir) {
      case 0:
        icon = Icons.navigation;
        break;
      case 1:
        icon = Icons.arrow_circle_right;
        break;
      case 2:
        icon = Icons.arrow_circle_down;
        break;
      case 3:
      default:
        icon = Icons.arrow_circle_left;
        break;
    }
    return Icon(icon, color: AppColors.primaryViolet, size: 28);
  }
}
