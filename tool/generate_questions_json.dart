import 'dart:convert';
import 'dart:io';

import 'package:unicorn_learning_lab/data/models/question.dart';
import 'package:unicorn_learning_lab/data/question_banks/default_questions.dart';

void main() {
  final outDir = Directory('assets/questions');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final grouped = <String, List<Question>>{};
  for (final q in DefaultQuestions.allQuestions) {
    grouped.putIfAbsent(q.audience.toLowerCase(), () => []).add(q);
  }

  for (final entry in grouped.entries) {
    final file = File('assets/questions/questions_${entry.key}.json');
    final data = {
      'audience': entry.key.toUpperCase(),
      'version': DefaultQuestions.version,
      'questions': entry.value.map((q) => q.toJson()).toList(),
    };
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    print('Generated: ${file.path} with ${entry.value.length} questions');
  }

  // Also full backup export
  final fullFile = File('assets/questions/all_questions_v1.0.json');
  fullFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': DefaultQuestions.version,
      'questions': DefaultQuestions.allQuestions.map((q) => q.toJson()).toList(),
    }),
  );
  print('Generated full question bank at: ${fullFile.path}');
}
