/// Operator screens for viewing, adding, editing and deleting quiz questions
/// for one audience category / class. Edits are saved on the tablet.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:unicorn_learning_lab/app/theme.dart';
import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/services/question_bank_service.dart';

/// Friendly label for an audience/category code like CLASS_5 → "Class 5".
String audienceLabel(String code) {
  final c = code.toUpperCase();
  if (c.startsWith('CLASS_')) return 'Class ${c.substring(6)}';
  switch (c) {
    case 'PARENT':
      return 'Parents';
    case 'GUARDIAN':
      return 'Guardians';
    case 'COLLEGE':
      return 'College';
    case 'PRE_PRIMARY':
      return 'Pre-Primary';
    case 'DEMO':
      return 'Demo';
    default:
      return c[0] + c.substring(1).toLowerCase();
  }
}

/// Sort order: Parent, Guardian, Pre-Primary, Class 1..12, College, Demo, others.
int audienceSortKey(String code) {
  final c = code.toUpperCase();
  if (c == 'PARENT') return 0;
  if (c == 'GUARDIAN') return 1;
  if (c == 'PRE_PRIMARY') return 5;
  if (c.startsWith('CLASS_')) return 10 + (int.tryParse(c.substring(6)) ?? 0);
  if (c == 'COLLEGE') return 50;
  if (c == 'DEMO') return 60;
  return 100;
}

class QuestionBankEditorScreen extends StatelessWidget {
  const QuestionBankEditorScreen({super.key, required this.audienceCode});

  final String audienceCode;

  @override
  Widget build(BuildContext context) {
    final qService = context.watch<QuestionBankService>();
    final questions = qService.getAllQuestionsForAudience(audienceCode);
    final validation = qService.validateAudienceBank(audienceCode);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
          '${audienceLabel(audienceCode)} • Questions',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepInkNavy),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.deepInkNavy),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        backgroundColor: AppColors.primaryViolet,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: validation.isValid ? AppColors.success.withOpacity(0.08) : AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  validation.isValid ? Icons.check_circle : Icons.error_outline,
                  color: validation.isValid ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    validation.isValid
                        ? '${validation.activeCount} active questions. Each quiz picks 5 at random.'
                        : 'Only ${validation.activeCount} active questions. At least 5 are needed or this quiz cannot start.',
                    style: TextStyle(
                      color: validation.isValid ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (questions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No questions yet. Tap "Add question" to create one.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
            ),
          for (var i = 0; i < questions.length; i++) _QuestionCard(index: i, question: questions[i]),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, Question? existing) async {
    await showQuestionEditorDialog(context, audienceCode: audienceCode, existing: existing);
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.index, required this.question});

  final int index;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final qService = context.read<QuestionBankService>();
    final correct = question.options.where((o) => o.id == question.correctAnswerId);
    final valid = question.isValid();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showQuestionEditorDialog(context, audienceCode: question.audience, existing: question),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: question.active ? AppColors.softViolet : AppColors.offWhite,
                child: Text('${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: question.active ? AppColors.primaryViolet : AppColors.secondaryText,
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: question.active ? AppColors.deepInkNavy : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      correct.isNotEmpty
                          ? 'Answer: ${correct.first.id}. ${correct.first.text}'
                          : 'No valid correct answer set',
                      style: TextStyle(
                        fontSize: 13,
                        color: correct.isNotEmpty ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (!question.active) _tag('Hidden from quiz', AppColors.secondaryText),
                        if (!valid) _tag('Incomplete', AppColors.error),
                        if (!qService.isBuiltIn(question.id)) _tag('Added on tablet', AppColors.primaryViolet),
                        _tag(question.difficulty, AppColors.secondaryText),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: question.active,
                    activeColor: AppColors.primaryViolet,
                    onChanged: valid
                        ? (v) => qService.saveQuestion(_copy(question, active: v))
                        : null,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await showQuestionEditorDialog(context, audienceCode: question.audience, existing: question);
                      } else if (v == 'restore') {
                        await qService.restoreBuiltIn(question.id);
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this question?'),
                            content: Text(question.question),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await qService.deleteQuestion(question);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (qService.isBuiltIn(question.id))
                        const PopupMenuItem(value: 'restore', child: Text('Restore original')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

Question _copy(Question q, {bool? active}) => Question(
      id: q.id,
      audience: q.audience,
      question: q.question,
      description: q.description,
      options: q.options,
      correctAnswerId: q.correctAnswerId,
      explanation: q.explanation,
      difficulty: q.difficulty,
      topic: q.topic,
      active: active ?? q.active,
      version: q.version,
    );

/// Add (existing == null) or edit a question.
Future<void> showQuestionEditorDialog(
  BuildContext context, {
  required String audienceCode,
  Question? existing,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<QuestionBankService>(),
      child: _QuestionEditorDialog(audienceCode: audienceCode, existing: existing),
    ),
  );
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({required this.audienceCode, this.existing});

  final String audienceCode;
  final Question? existing;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  static const _optionIds = ['A', 'B', 'C', 'D'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _question;
  late final TextEditingController _description;
  late final TextEditingController _explanation;
  late final List<TextEditingController> _options;
  late String _correct;
  late String _difficulty;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _question = TextEditingController(text: q?.question ?? '');
    _description = TextEditingController(text: q?.description ?? '');
    _explanation = TextEditingController(text: q?.explanation ?? '');
    // Map existing options onto A–D slots (keeps their text, normalises IDs).
    final existingOpts = q?.options ?? const <QuestionOption>[];
    _options = List.generate(
      4,
      (i) => TextEditingController(text: i < existingOpts.length ? existingOpts[i].text : ''),
    );
    final correctIdx = existingOpts.indexWhere((o) => o.id == q?.correctAnswerId);
    _correct = correctIdx >= 0 && correctIdx < 4 ? _optionIds[correctIdx] : 'A';
    _difficulty = (q?.difficulty == 'easy' || q?.difficulty == 'hard') ? q!.difficulty : 'medium';
    _active = q?.active ?? true;
  }

  @override
  void dispose() {
    _question.dispose();
    _description.dispose();
    _explanation.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final svc = context.read<QuestionBankService>();
    final old = widget.existing;
    final q = Question(
      id: old?.id ?? svc.newQuestionId(widget.audienceCode),
      audience: old?.audience ?? widget.audienceCode.toUpperCase(),
      question: _question.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      options: [
        for (var i = 0; i < 4; i++) QuestionOption(id: _optionIds[i], text: _options[i].text.trim()),
      ],
      correctAnswerId: _correct,
      explanation: _explanation.text.trim().isEmpty ? null : _explanation.text.trim(),
      difficulty: _difficulty,
      topic: old?.topic,
      active: _active,
      version: old?.version ?? '1.0',
    );
    try {
      await svc.saveQuestion(q);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Add question • ${audienceLabel(widget.audienceCode)}'
          : 'Edit question • ${audienceLabel(widget.audienceCode)}'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _question,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Hint / subtitle (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Answer options — select the correct one',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepInkNavy)),
                const SizedBox(height: 8),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: _optionIds[i],
                          groupValue: _correct,
                          activeColor: AppColors.success,
                          onChanged: (v) => setState(() => _correct = v!),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _options[i],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Option ${_optionIds[i]}${_correct == _optionIds[i] ? '  ✓ correct' : ''}',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: _required,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _explanation,
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Explanation shown after answering (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Difficulty: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _difficulty,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                    const Spacer(),
                    const Text('Show in quiz'),
                    Switch(
                      value: _active,
                      activeColor: AppColors.primaryViolet,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryViolet, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
