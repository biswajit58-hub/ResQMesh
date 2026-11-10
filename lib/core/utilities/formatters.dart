import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';

String relativeTime(BuildContext context, DateTime time) {
  final diff = DateTime.now().toUtc().difference(time.toUtc());
  if (diff.inSeconds < 60) return context.tr('just_now');
  if (diff.inMinutes < 60) {
    return context.tr('minutes_ago', {'count': diff.inMinutes});
  }
  if (diff.inHours < 24) {
    return context.tr('hours_ago', {'count': diff.inHours});
  }
  return context.tr('days_ago', {'count': diff.inDays});
}

String clockTime(DateTime time) {
  final local = time.toLocal();
  return DateFormat('HH:mm').format(local);
}

String dateTimeLabel(DateTime time) {
  final local = time.toLocal();
  return DateFormat('d MMM · HH:mm').format(local);
}

String shortId(String id) {
  if (id.length <= 12) return id;
  return '${id.substring(0, 8)}…';
}

String coordLabel(double lat, double lng, {int digits = 5}) =>
    '${lat.toStringAsFixed(digits)}, ${lng.toStringAsFixed(digits)}';

String distanceLabel(double meters) {
  if (!meters.isFinite) return '—';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}

String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

IconData locationSourceIcon(String wire) => switch (wire) {
      'gps' => Icons.gps_fixed_rounded,
      'manual' => Icons.edit_location_alt_rounded,
      'last_known' => Icons.history_rounded,
      'mesh_relay' => Icons.hub_rounded,
      _ => Icons.calculate_rounded,
    };
