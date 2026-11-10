import 'enums.dart';

class VerificationVote {
  const VerificationVote({
    required this.id,
    required this.incidentId,
    required this.reporterId,
    required this.reporterName,
    required this.state,
    required this.createdAt,
    this.note = '',
    this.isResponder = false,
    this.isDemo = false,
  });

  final String id;
  final String incidentId;
  final String reporterId;
  final String reporterName;
  final VerificationState state;
  final DateTime createdAt;
  final String note;
  final bool isResponder;
  final bool isDemo;

  Map<String, Object?> toMap() => {
        'id': id,
        'incident_id': incidentId,
        'reporter_id': reporterId,
        'reporter_name': reporterName,
        'state': state.wire,
        'note': note,
        'is_responder': isResponder ? 1 : 0,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_demo': isDemo ? 1 : 0,
      };

  factory VerificationVote.fromMap(Map<String, Object?> map) =>
      VerificationVote(
        id: map['id'] as String,
        incidentId: map['incident_id'] as String,
        reporterId: map['reporter_id'] as String? ?? '',
        reporterName: map['reporter_name'] as String? ?? 'Unknown',
        state: VerificationState.fromWire(map['state'] as String?),
        note: map['note'] as String? ?? '',
        isResponder: ((map['is_responder'] as num?)?.toInt() ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
      );
}
