/// Question model supporting structured options, stable IDs, and JSON serialization.
library;

class QuestionOption {
  const QuestionOption({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
  };
}

class Question {
  const Question({
    required this.id,
    required this.audience,
    required this.question,
    this.description,
    required this.options,
    required this.correctAnswerId,
    this.explanation,
    this.difficulty = 'medium',
    this.topic,
    this.active = true,
    this.version = '1.0',
  });

  final String id;
  final String audience;
  final String question;
  final String? description;
  final List<QuestionOption> options;
  final String correctAnswerId;
  final String? explanation;
  final String difficulty;
  final String? topic;
  final bool active;
  final String version;

  /// Check whether this question structure is valid.
  bool isValid() {
    if (id.trim().isEmpty || question.trim().isEmpty) return false;
    if (options.length != 4) return false;
    final optionIds = options.map((o) => o.id.trim()).toSet();
    if (optionIds.length != 4) return false; // Duplicate option IDs
    if (!optionIds.contains(correctAnswerId.trim())) return false;
    return true;
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final optionsList = rawOptions
        .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
        .toList();

    return Question(
      id: json['id'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      question: json['question'] as String? ?? '',
      description: json['description'] as String?,
      options: optionsList,
      correctAnswerId: json['correctAnswerId'] as String? ?? '',
      explanation: json['explanation'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      topic: json['topic'] as String?,
      active: json['active'] as bool? ?? true,
      version: json['version'] as String? ?? '1.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audience': audience,
    'question': question,
    'description': description,
    'options': options.map((o) => o.toJson()).toList(),
    'correctAnswerId': correctAnswerId,
    'explanation': explanation,
    'difficulty': difficulty,
    'topic': topic,
    'active': active,
    'version': version,
  };
}
