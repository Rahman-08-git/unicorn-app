/// Participant model for Unicorn Learning Lab.
library;

import 'package:uuid/uuid.dart';

enum AudienceCategory {
  parent('PARENT', 'Parent'),
  guardian('GUARDIAN', 'Guardian'),
  student('STUDENT', 'Student');

  const AudienceCategory(this.code, this.label);
  final String code;
  final String label;

  static AudienceCategory fromCode(String code) {
    return AudienceCategory.values.firstWhere(
      (e) => e.code.toUpperCase() == code.toUpperCase(),
      orElse: () => AudienceCategory.student,
    );
  }
}

class Participant {
  Participant({
    String? id,
    required this.audienceCategory,
    this.classLevel,
    this.phoneNumber,
    this.name,
    this.consentGiven = false,
    DateTime? registrationTimestamp,
  })  : id = id ?? const Uuid().v4(),
        registrationTimestamp = registrationTimestamp ?? DateTime.now();

  final String id;
  final AudienceCategory audienceCategory;
  final String? classLevel;
  final String? phoneNumber;
  final String? name;
  final bool consentGiven;
  final DateTime registrationTimestamp;

  /// Returns masked phone number for privacy in operator logs/screens
  String get maskedPhone {
    if (phoneNumber == null || phoneNumber!.isEmpty) return 'N/A';
    final clean = phoneNumber!.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 4) return '***';
    final last4 = clean.substring(clean.length - 4);
    final prefix = clean.length > 4 ? clean.substring(0, clean.length - 4) : '';
    return '${'*' * prefix.length}$last4';
  }

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] as String,
      audienceCategory: AudienceCategory.fromCode(map['audience_category'] as String),
      classLevel: map['class_level'] as String?,
      phoneNumber: map['phone_number'] as String?,
      name: map['name'] as String?,
      consentGiven: (map['consent_given'] as int? ?? 0) == 1,
      registrationTimestamp: DateTime.parse(map['registration_timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audience_category': audienceCategory.code,
      'class_level': classLevel,
      'phone_number': phoneNumber,
      'name': name,
      'consent_given': consentGiven ? 1 : 0,
      'registration_timestamp': registrationTimestamp.toIso8601String(),
    };
  }
}
