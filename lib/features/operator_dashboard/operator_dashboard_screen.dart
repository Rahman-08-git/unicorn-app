/// Operator Dashboard: Campaign administration, analytics, inventory,
/// question validation, settings, and CSV export.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/core/constants/app_constants.dart';
import 'package:unicorn_learning_lab/core/ui/ull_ui.dart';
import 'package:unicorn_learning_lab/data/database/database_helper.dart';
import 'package:unicorn_learning_lab/data/models/attempt.dart';
import 'package:unicorn_learning_lab/data/models/campaign_config.dart';
import 'package:unicorn_learning_lab/data/models/participant.dart';
import 'package:unicorn_learning_lab/data/models/reward.dart';
import 'package:unicorn_learning_lab/data/models/reward_inventory.dart';
import 'package:unicorn_learning_lab/features/operator_dashboard/question_bank_editor.dart';
import 'package:unicorn_learning_lab/services/export_service.dart';
import 'package:unicorn_learning_lab/services/session_service.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';
import 'package:unicorn_learning_lab/services/storage_bridge.dart';

class OperatorDashboardScreen extends StatefulWidget {
  const OperatorDashboardScreen({super.key});

  @override
  State<OperatorDashboardScreen> createState() => _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseHelper.instance;
  late final ExportService _exportService =
      ExportService(questionBank: context.read<QuestionBankService>());
  final _storage = const StorageBridge();

  Map<String, dynamic> _stats = {};
  List<Participant> _participants = [];
  List<Reward> _rewards = [];
  List<RewardInventory> _inventory = [];
  CampaignConfig _config = CampaignConfig();
  bool _isLoading = true;

  // Lookups for participant details
  Map<String, List<Attempt>> _attemptsByParticipant = {};
  Map<String, Attempt> _attemptById = {};
  Map<String, Reward> _rewardByAttempt = {};
  Map<String, Participant> _participantById = {};
  String _participantQuery = '';

  // Export state
  PickedFolder? _exportFolder;
  ExportResult? _lastExport;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboardData();
    _loadExportFolder();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    final stats = await _db.getDashboardStats();
    final participants = await _db.getAllParticipants();
    final attempts = await _db.getAllAttempts(); // newest first
    final rewards = await _db.getAllRewards();
    final inventory = await _db.getAllInventory();
    final config = await _db.getCampaignConfig();

    final byParticipant = <String, List<Attempt>>{};
    for (final a in attempts) {
      byParticipant.putIfAbsent(a.participantId, () => []).add(a);
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _participants = participants;
        _participantById = {for (final p in participants) p.id: p};
        _attemptsByParticipant = byParticipant;
        _attemptById = {for (final a in attempts) a.id: a};
        _rewards = rewards;
        _rewardByAttempt = {for (final r in rewards) r.attemptId: r};
        _inventory = inventory;
        _config = config;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExportFolder() async {
    try {
      final folder = await _exportService.getSavedExportFolder();
      if (mounted) setState(() => _exportFolder = folder);
    } catch (_) {}
  }

  Future<PickedFolder?> _chooseExportFolder() async {
    try {
      final folder = await _exportService.chooseExportFolder();
      if (folder != null && mounted) setState(() => _exportFolder = folder);
      return folder;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the file explorer: $e')));
      }
      return null;
    }
  }

  Future<void> _runCsvExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ExportResult res;
    if (_storage.isSupported) {
      // Ask for a folder the first time (or if access was lost).
      var folder = _exportFolder;
      folder ??= await _chooseExportFolder();
      if (folder == null) {
        if (mounted) setState(() => _exporting = false);
        return; // cancelled
      }
      res = await _exportService.exportToFolder(folder);
      if (!res.success) {
        // Permission may have been revoked: let them pick again.
        final retry = await _chooseExportFolder();
        if (retry != null) res = await _exportService.exportToFolder(retry);
      }
    } else {
      res = await _exportService.exportAllCampaignData();
    }
    if (!mounted) return;
    setState(() {
      _lastExport = res;
      _exporting = false;
    });
  }

  Future<void> _openExportFolder() async {
    final uri = _lastExport?.folderUri ?? _exportFolder?.uri;
    if (uri == null) return;
    final ok = await _storage.openFolder(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Open the Files app and go to: ${_lastExport?.locationLabel ?? _exportFolder?.label}'),
      ));
    }
  }

  Future<void> _editCampaignConfig() async {
    final c = _config;
    final tablet = TextEditingController(text: c.tabletId);
    final campaignId = TextEditingController(text: c.campaignId);
    final campaignName = TextEditingController(text: c.campaignName);
    final timer = TextEditingController(text: '${c.timerDurationSeconds}');
    final reset = TextEditingController(text: '${c.sessionResetSeconds}');
    final pin = TextEditingController(text: c.operatorPin);
    final formKey = GlobalKey<FormState>();

    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
    String? range(String? v, int min, int max) {
      final n = int.tryParse(v?.trim() ?? '');
      if (n == null || n < min || n > max) return 'Enter $min–$max';
      return null;
    }

    Widget field(TextEditingController ctrl, String label,
            {String? Function(String?)? validator, bool number = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: ctrl,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            validator: validator ?? req,
          ),
        );

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit campaign settings'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  field(tablet, 'Tablet identifier'),
                  field(campaignId, 'Campaign identifier'),
                  field(campaignName, 'Campaign name'),
                  field(timer, 'Seconds per question', number: true, validator: (v) => range(v, 10, 300)),
                  field(reset, 'Auto-reset idle screens after (seconds)', number: true, validator: (v) => range(v, 10, 600)),
                  field(pin, 'Operator PIN (4–8 digits)', number: true, validator: (v) {
                    final t = v?.trim() ?? '';
                    return RegExp(r'^\d{4,8}$').hasMatch(t) ? null : 'Use 4–8 digits';
                  }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true) {
      final updated = CampaignConfig(
        id: c.id,
        campaignId: campaignId.text.trim(),
        campaignName: campaignName.text.trim(),
        tabletId: tablet.text.trim(),
        timerDurationSeconds: int.parse(timer.text.trim()),
        rewardMode: c.rewardMode,
        activeQuestionBankVersion: c.activeQuestionBankVersion,
        sessionResetSeconds: int.parse(reset.text.trim()),
        operatorPin: pin.text.trim(),
        soundEnabled: c.soundEnabled,
        hapticEnabled: c.hapticEnabled,
      );
      await _db.updateCampaignConfig(updated);
      if (mounted) {
        setState(() => _config = updated);
        context.read<SessionService>().refreshConfig();
      }
    }
    for (final ctrl in [tablet, campaignId, campaignName, timer, reset, pin]) {
      ctrl.dispose();
    }
  }

  Future<void> _markRewardCollected(String rewardId) async {
    await _db.markRewardCollected(rewardId);
    await _loadDashboardData(showSpinner: false);
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Campaign Data?'),
        content: const Text(
          'This will permanently delete all participants, attempts, answers and gift records on this tablet. Current stock levels are kept. Export your CSV files first!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.resetAllCampaignData();
      await _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Operator Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepInkNavy),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.deepInkNavy),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryViolet,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryViolet,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline), text: 'Participants'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
            Tab(icon: Icon(Icons.quiz_outlined), text: 'Question Bank'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings & Export'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildParticipantsTab(),
                _buildInventoryTab(),
                _buildQuestionBankTab(),
                _buildSettingsAndExportTab(),
              ],
            ),
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab() {
    final total = _stats['totalParticipants'] ?? 0;
    final completed = _stats['completedAttempts'] ?? 0;
    final avgScore = (_stats['averageScore'] as double? ?? 0.0);
    final scoreDist = _stats['scoreDistribution'] as Map<int, int>? ?? {};
    final classBreakdown = _stats['classBreakdown'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Cards Row
          Row(
            children: [
              _buildStatCard('Total Participants', '$total', Icons.groups, AppColors.primaryViolet),
              const SizedBox(width: 16),
              _buildStatCard('Completed Quizzes', '$completed', Icons.check_circle, AppColors.success),
              const SizedBox(width: 16),
              _buildStatCard('Average Score', '${avgScore.toStringAsFixed(1)} / 5', Icons.star, AppColors.warmGold),
            ],
          ),

          const SizedBox(height: 24),

          // Score Distribution Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score Distribution (0 - 5)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.deepInkNavy),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(6, (i) {
                      final count = scoreDist[i] ?? 0;
                      return Column(
                        children: [
                          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 60,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: AppColors.offWhite,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FractionallySizedBox(
                              heightFactor: total > 0 ? (count / total).clamp(0.08, 1.0) : 0.08,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == 5 ? AppColors.warmGold : AppColors.primaryViolet,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('$i/5', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildClassBreakdownCard(classBreakdown),
        ],
      ),
    );
  }

  /// Students per class (Pre-Primary, Class 1–12, College), always listing every class.
  Widget _buildClassBreakdownCard(Map<String, int> breakdown) {
    final maxCount = breakdown.values.fold<int>(0, (m, v) => v > m ? v : m);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Students by Class',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.deepInkNavy),
            ),
            const SizedBox(height: 16),
            for (final code in AppConstants.studentClassLevels)
              Padding(
                key: ValueKey('class_breakdown_$code'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(audienceLabel(code), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maxCount == 0 ? 0 : (breakdown[code] ?? 0) / maxCount,
                          minHeight: 12,
                          backgroundColor: AppColors.offWhite,
                          color: code == 'PRE_PRIMARY' ? const Color(0xFFEA580C) : AppColors.primaryViolet,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('${breakdown[code] ?? 0}',
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.deepInkNavy)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // 2. Participants Tab
  String _participantLabel(Participant p) {
    final cls = p.classLevel;
    if (cls == null) return p.audienceCategory.label;
    return '${p.audienceCategory.label} • ${audienceLabel(cls)}';
  }

  Widget _buildParticipantsTab() {
    final q = _participantQuery.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final filtered = q.isEmpty
        ? _participants
        : _participants.where((p) {
            final name = (p.name ?? '').toLowerCase();
            final phone = (p.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
            return name.contains(q) ||
                (qDigits.isNotEmpty && phone.contains(qDigits)) ||
                _participantLabel(p).toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name, phone number or class',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _participantQuery = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No participants yet.', style: TextStyle(color: AppColors.secondaryText)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final timeStr = DateFormat('hh:mm a, dd MMM').format(p.registrationTimestamp);
                    final attempt = _latestAttemptFor(p.id);
                    final reward = attempt == null ? null : _rewardByAttempt[attempt.id];
                    final hasName = p.name != null && p.name!.trim().isNotEmpty;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () => _showParticipantDetails(p),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.softViolet,
                          child: Text(
                            hasName ? p.name!.trim()[0].toUpperCase() : p.audienceCategory.code[0],
                            style: const TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          hasName ? '${p.name} • ${_participantLabel(p)}' : _participantLabel(p),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (p.phoneNumber != null && p.phoneNumber!.isNotEmpty) 'Phone: ${p.phoneNumber}',
                            if (attempt != null && attempt.status == AttemptStatus.completed)
                              'Score: ${attempt.score}/${attempt.totalQuestions}',
                            if (reward != null) 'Gift: ${_giftName(reward.rewardIdentifier)}',
                            'Registered: $timeStr',
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Attempt? _latestAttemptFor(String participantId) {
    final list = _attemptsByParticipant[participantId];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  String _giftName(String rewardIdentifier) {
    for (final i in _inventory) {
      if (i.rewardIdentifier == rewardIdentifier) return i.displayName;
    }
    return RewardInventory.prettifyIdentifier(rewardIdentifier);
  }

  Future<void> _showParticipantDetails(Participant p) async {
    final attempts = _attemptsByParticipant[p.id] ?? const <Attempt>[];
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Widget row(String label, String value, {Widget? trailing}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(label, style: const TextStyle(color: AppColors.secondaryText)),
                  ),
                  Expanded(
                    child: SelectableText(value,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepInkNavy)),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            );

        final hasName = p.name != null && p.name!.trim().isNotEmpty;
        return AlertDialog(
          title: Text(hasName ? p.name! : 'Participant details'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row(
                    'Name',
                    hasName ? p.name! : 'Not provided',
                    trailing: IconButton(
                      tooltip: 'Edit name',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _editParticipantName(p);
                      },
                    ),
                  ),
                  row('Phone number', (p.phoneNumber == null || p.phoneNumber!.isEmpty) ? 'Not collected' : p.phoneNumber!),
                  row('Category', _participantLabel(p)),
                  row('Registered', DateFormat('hh:mm a, dd MMM yyyy').format(p.registrationTimestamp)),
                  const Divider(height: 28),
                  const Text('Quiz attempts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.deepInkNavy)),
                  const SizedBox(height: 8),
                  if (attempts.isEmpty)
                    const Text('No quiz attempts recorded.', style: TextStyle(color: AppColors.secondaryText)),
                  for (final a in attempts) _attemptTile(ctx, a),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _attemptTile(BuildContext dialogCtx, Attempt a) {
    final reward = _rewardByAttempt[a.id];
    final completed = a.status == AttemptStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                completed ? '${a.score}/${a.totalQuestions}' : '—',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: completed ? AppColors.primaryViolet : AppColors.secondaryText,
                ),
              ),
              const Text('score', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward != null ? 'Gift: ${_giftName(reward.rewardIdentifier)}' : 'No gift assigned',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepInkNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('hh:mm a, dd MMM').format(a.startedAt),
                    completed ? 'Completed' : (a.status == AttemptStatus.abandoned ? 'Abandoned' : 'Not finished'),
                    if (reward != null) reward.isCollected ? 'Gift collected' : 'Gift not collected yet',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          if (reward != null && !reward.isCollected)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _markRewardCollected(reward.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
              child: const Text('Mark collected'),
            )
          else if (reward != null)
            const Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  Future<void> _editParticipantName(Participant p) async {
    final controller = TextEditingController(text: p.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Participant name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null) return;
    final trimmed = newName.trim();
    await _db.updateParticipantName(p.id, trimmed.isEmpty ? null : trimmed);
    await _loadDashboardData();
  }

  // 3. Inventory Tab
  static const _tierOrder = [
    AppConstants.rewardPremiumGift,
    AppConstants.rewardSpinWheel,
    AppConstants.rewardSticker,
  ];

  static String tierLabel(String type) {
    switch (type) {
      case AppConstants.rewardPremiumGift:
        return 'Premium gift • score 5/5';
      case AppConstants.rewardScratchCard: // legacy tier, merged into the 3–4 tier
      case AppConstants.rewardSpinWheel:
        return 'Spin wheel gift • score 3–4/5';
      case AppConstants.rewardSticker:
        return 'Sticker • score 0–2/5 (and backup when others run out)';
      default:
        return type;
    }
  }

  Widget _buildInventoryTab() {
    final byTier = <String, List<RewardInventory>>{};
    for (final item in _inventory) {
      byTier.putIfAbsent(item.rewardType, () => []).add(item);
    }
    final tiers = [
      ..._tierOrder,
      ...byTier.keys.where((t) => !_tierOrder.contains(t)),
    ];
    final totalInStock = _inventory.fold<int>(0, (s, i) => s + i.availableStock);
    final totalGiven = _inventory.fold<int>(0, (s, i) => s + i.assignedCount);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            _buildStatCard('Units in stock', '$totalInStock', Icons.inventory_2, AppColors.primaryViolet),
            const SizedBox(width: 16),
            _buildStatCard('Gifts given out', '$totalGiven', Icons.card_giftcard, AppColors.warmGold),
            const SizedBox(width: 16),
            _buildStatCard('Gift types', '${_inventory.length}', Icons.category_outlined, AppColors.success),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Gifts & stock',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.deepInkNavy),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showGiftEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Add gift'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Stock goes down automatically each time a participant wins a gift. Tap a gift to rename it or change its stock.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final tier in tiers) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              tierLabel(tier).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          if ((byTier[tier] ?? const []).isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No gifts in this tier. Winners get the backup gift.',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ),
          for (final item in byTier[tier] ?? const <RewardInventory>[]) _giftCard(item),
        ],
        const SizedBox(height: 24),
        const Text(
          'Recent gifts given',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.deepInkNavy),
        ),
        const SizedBox(height: 12),
        if (_rewards.isEmpty)
          const Text('No gifts given yet.', style: TextStyle(color: AppColors.secondaryText))
        else
          ..._rewards.take(20).map((r) {
            final isCollected = r.collectionStatus == AppConstants.statusCollected;
            final attempt = _attemptById[r.attemptId];
            final participant = attempt == null ? null : _participantById[attempt.participantId];
            final who = participant == null
                ? 'Unknown participant'
                : ((participant.name?.trim().isNotEmpty ?? false)
                    ? participant.name!
                    : (participant.phoneNumber ?? _participantLabel(participant)));
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: participant == null ? null : () => _showParticipantDetails(participant),
                title: Text('${_giftName(r.rewardIdentifier)} → $who'),
                subtitle: Text(
                  '${attempt != null ? 'Score ${attempt.score}/${attempt.totalQuestions} • ' : ''}'
                  '${isCollected ? 'Collected' : 'Not collected yet'} • ${DateFormat('hh:mm a, dd MMM').format(r.assignedAt)}',
                ),
                trailing: isCollected
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : ElevatedButton(
                        onPressed: () => _markRewardCollected(r.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark Collected'),
                      ),
              ),
            );
          }),
      ],
    );
  }

  Widget _giftCard(RewardInventory item) {
    final remaining = item.availableStock;
    final low = remaining > 0 && remaining <= 10;
    final color = remaining == 0 ? AppColors.error : (low ? const Color(0xFFB45309) : AppColors.primaryViolet);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showGiftEditor(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(remaining > 0 ? Icons.card_giftcard : Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.deepInkNavy)),
                    const SizedBox(height: 2),
                    Text(
                      'Given out: ${item.assignedCount} • Collected: ${item.collectedCount}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove 1',
                onPressed: remaining > 0 ? () => _adjustStock(item, -1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 96),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      remaining > 0 ? '$remaining' : 'OUT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color),
                    ),
                    Text('in stock', style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add 1',
                onPressed: () => _adjustStock(item, 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Edit gift',
                onPressed: () => _showGiftEditor(item),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adjustStock(RewardInventory item, int delta) async {
    await _db.updateInventoryItem(
      rewardIdentifier: item.rewardIdentifier,
      displayName: item.displayName,
      rewardType: item.rewardType,
      unitsInStock: item.availableStock + delta,
    );
    await _loadDashboardData(showSpinner: false);
  }

  Future<void> _showGiftEditor(RewardInventory? existing) async {
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final stockCtrl = TextEditingController(text: '${existing?.availableStock ?? 0}');
    String tier = existing?.rewardType ?? AppConstants.rewardSticker;
    if (tier == AppConstants.rewardScratchCard) tier = AppConstants.rewardSpinWheel;
    if (!_tierOrder.contains(tier)) tier = AppConstants.rewardSticker;
    final formKey = GlobalKey<FormState>();
    final tierCount = existing == null ? 0 : _inventory.where((i) => i.rewardType == existing.rewardType).length;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void bump(int d) {
            final v = (int.tryParse(stockCtrl.text.trim()) ?? 0) + d;
            stockCtrl.text = '${v < 0 ? 0 : v}';
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add gift' : 'Edit gift'),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      autofocus: existing == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Gift name', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: tier,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Given for', border: OutlineInputBorder()),
                      items: [
                        for (final t in _tierOrder) DropdownMenuItem(value: t, child: Text(tierLabel(t))),
                      ],
                      onChanged: (v) => setLocal(() => tier = v!),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton(onPressed: () => bump(-10), icon: const Icon(Icons.keyboard_double_arrow_down), tooltip: '-10'),
                        IconButton(onPressed: () => bump(-1), icon: const Icon(Icons.remove), tooltip: '-1'),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Units in stock now', border: OutlineInputBorder()),
                            validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Enter a number' : null,
                          ),
                        ),
                        IconButton(onPressed: () => bump(1), icon: const Icon(Icons.add), tooltip: '+1'),
                        IconButton(onPressed: () => bump(10), icon: const Icon(Icons.keyboard_double_arrow_up), tooltip: '+10'),
                      ],
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${existing.assignedCount} already given out. The stock count drops by 1 automatically every time this gift is won.',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (existing != null)
                TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('delete'),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                ),
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) Navigator.of(ctx).pop('save');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    final name = nameCtrl.text.trim();
    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
    nameCtrl.dispose();
    stockCtrl.dispose();
    if (!mounted || action == null) return;

    if (action == 'delete' && existing != null) {
      if (tierCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Each reward tier needs at least one gift. Set its stock to 0 instead, or add another gift first.'),
        ));
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${existing.displayName}"?'),
          content: const Text('Past winners keep their record. This gift will no longer be handed out.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _db.deleteInventoryItem(existing.rewardIdentifier);
        await _loadDashboardData(showSpinner: false);
      }
      return;
    }

    if (existing == null) {
      final id = 'GIFT_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
      await _db.insertInventoryItem(RewardInventory(
        rewardType: tier,
        rewardIdentifier: id,
        displayName: name,
        configuredStock: stock,
      ));
    } else {
      if (existing.rewardType != tier && tierCount <= 1 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Each reward tier needs at least one gift, so the tier was not changed.'),
        ));
        tier = existing.rewardType;
      }
      await _db.updateInventoryItem(
        rewardIdentifier: existing.rewardIdentifier,
        displayName: name,
        rewardType: tier,
        unitsInStock: stock,
      );
    }
    await _loadDashboardData(showSpinner: false);
  }

  // 4. Question Bank Tab
  Widget _buildQuestionBankTab() {
    final qService = context.watch<QuestionBankService>();
    final categories = [...qService.configuredAudienceCategories]
      ..sort((a, b) => audienceSortKey(a).compareTo(audienceSortKey(b)));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tap a category to view, add, edit or hide its questions. Changes are saved on this tablet.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final cat in categories) ...[
          Builder(builder: (context) {
            final validation = qService.validateAudienceBank(cat);
            final total = qService.getAllQuestionsForAudience(cat).length;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QuestionBankEditorScreen(audienceCode: cat)),
                ),
                leading: Icon(
                  validation.isValid ? Icons.check_circle : Icons.error_outline,
                  color: validation.isValid ? AppColors.success : AppColors.error,
                ),
                title: Text(audienceLabel(cat), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${validation.activeCount} active of $total questions (min 5 required)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      backgroundColor: validation.isValid
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      label: Text(
                        validation.isValid ? 'READY' : 'DEFICIT',
                        style: TextStyle(
                          color: validation.isValid ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_note),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // 5. Settings & Export Tab
  Widget _buildSettingsAndExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CSV Export Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Campaign Records (CSV)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Exports a Quiz Report (one row per visitor: name, phone, class, every question with their answer and the correct answer, score, result and gift won), the Gift Inventory and a Summary, ready to open in Excel or Google Sheets.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_storage.isSupported) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined, color: AppColors.primaryViolet),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Save to folder',
                                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                Text(
                                  _exportFolder?.label ?? 'No folder chosen yet',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepInkNavy),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _exporting ? null : _chooseExportFolder,
                            icon: const Icon(Icons.drive_folder_upload_outlined),
                            label: Text(_exportFolder == null ? 'Choose folder' : 'Change folder'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _exporting ? null : _runCsvExport,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.file_download_outlined),
                        label: const Text('Export All CSV Files'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (_storage.isSupported && (_lastExport?.folderUri ?? _exportFolder?.uri) != null)
                        OutlinedButton.icon(
                          onPressed: _openExportFolder,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('Open folder in Files'),
                        ),
                    ],
                  ),
                  if (_lastExport != null) ...[
                    const SizedBox(height: 12),
                    if (_lastExport!.success) ...[
                      Text(
                        'Saved ${_lastExport!.exportedFiles.length} CSV files to: ${_lastExport!.locationLabel}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      for (final f in _lastExport!.exportedFiles)
                        Text('• ${f.split(RegExp(r'[\\/]')).last}',
                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                    ] else
                      Text(
                        'Export failed: ${_lastExport!.errorMessage}',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Configuration details
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tablet & Campaign Configuration',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _editCampaignConfig,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Tablet Identifier: ${_config.tabletId}'),
                  Text('Campaign Identifier: ${_config.campaignId}'),
                  Text('Campaign Name: ${_config.campaignName}'),
                  Text('Timer per Question: ${_config.timerDurationSeconds} seconds'),
                  Text('Auto-reset after: ${_config.sessionResetSeconds} seconds'),
                  Text('Active Question Bank Version: ${_config.activeQuestionBankVersion}'),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.casino_outlined, size: 20, color: AppColors.primaryViolet),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reward reveal: spin wheel for every score. The wheel always lands on the gift that was won.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: Motion.reducedPref,
                    builder: (_, reduced, __) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reduced motion'),
                      subtitle: const Text('Minimise animations for sensitive visitors or slower tablets.'),
                      value: reduced,
                      onChanged: (v) => Motion.reducedPref.value = v,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Destructive Reset Card
          Card(
            color: const Color(0xFFFEF2F2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Destructive Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Clear all participants, quiz attempts and gift records on this tablet. Stock levels are kept.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _confirmResetData,
                    icon: const Icon(Icons.delete_forever, color: AppColors.error),
                    label: const Text('Reset All Campaign Data', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
