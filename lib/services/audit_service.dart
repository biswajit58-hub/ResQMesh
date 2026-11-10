import 'package:uuid/uuid.dart';

import '../core/database/audit_repository.dart';
import '../models/audit_event.dart';
import '../models/enums.dart';

/// Append-only, locally persisted audit trail. There is deliberately no update
/// or delete operation for real events.
class AuditService {
  AuditService(this._repository);
  final AuditRepository _repository;
  final _uuid = const Uuid();

  Future<AuditEvent> log(
    AuditEventType type,
    String detail, {
    String? messageId,
    String? peerId,
    bool isDemo = false,
    DateTime? at,
  }) async {
    final event = AuditEvent(
      id: _uuid.v4(),
      type: type,
      detail: detail,
      messageId: messageId,
      peerId: peerId,
      createdAt: at ?? DateTime.now().toUtc(),
      isDemo: isDemo,
    );
    await _repository.insert(event);
    return event;
  }

  Future<List<AuditEvent>> list({
    bool demoOnly = false,
    int limit = 500,
  }) =>
      _repository.list(demoOnly: demoOnly, limit: limit);
}
