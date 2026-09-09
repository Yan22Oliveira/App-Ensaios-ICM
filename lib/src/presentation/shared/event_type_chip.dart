import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/event_type.dart';

Color eventTypeAccent(EventType type) => switch (type) {
      EventType.rehearsal => AppTheme.primary,
      EventType.worship => AppTheme.accentPurple,
      EventType.vigil => AppTheme.accentTeal,
      EventType.evangelism => AppTheme.accentOrange,
      EventType.assistance => AppTheme.success,
      EventType.seminar => AppTheme.accentPurple,
      EventType.meeting => AppTheme.primary,
      EventType.cantata => AppTheme.accentOrange,
      EventType.mutirao => AppTheme.success,
      EventType.other => Colors.blueGrey,
    };

/// Chip compacto com o tipo do evento (Ensaio, Vigília, etc.).
class EventTypeChip extends StatelessWidget {
  final EventType type;
  const EventTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = eventTypeAccent(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
