import 'dart:collection';

/// Sliding-window rate limiter for incoming mesh traffic.
///
/// Limits are intentionally generous for disasters while still bounding a
/// malicious or malfunctioning peer. Both per-origin and global windows apply.
class MeshRateLimiter {
  MeshRateLimiter({
    this.perOriginLimit = 20,
    this.globalLimit = 80,
    this.window = const Duration(minutes: 1),
  });

  final int perOriginLimit;
  final int globalLimit;
  final Duration window;

  final Map<String, Queue<DateTime>> _byOrigin = {};
  final Queue<DateTime> _global = Queue<DateTime>();

  bool allow(String originId, DateTime now) {
    _prune(now);
    final origin = _byOrigin.putIfAbsent(originId, Queue<DateTime>.new);
    if (origin.length >= perOriginLimit || _global.length >= globalLimit) {
      return false;
    }
    origin.add(now);
    _global.add(now);
    return true;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(window);
    while (_global.isNotEmpty && _global.first.isBefore(cutoff)) {
      _global.removeFirst();
    }
    for (final queue in _byOrigin.values) {
      while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
        queue.removeFirst();
      }
    }
    _byOrigin.removeWhere((_, queue) => queue.isEmpty);
  }

  void reset() {
    _byOrigin.clear();
    _global.clear();
  }
}
