import 'package:flutter/material.dart';

import '../../../src.dart';

const _kPad = 16.0;
const _textPrimary = Color(0xFF151A1F);
const _textSecondary = Color(0xFF66717D);
const _border = Color(0xFFCDD3D8);

class PeriodSummarySection extends StatelessWidget {
  final ReportsState state;
  const PeriodSummarySection({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final pct = (s.attendanceRate * 100).round();
    final eventsLabel = s.totalRehearsals == 1 ? 'evento' : 'eventos';

    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMO DO PERÍODO',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: _textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Presença no período',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppTheme.neutralLight,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiBlock(
                    icon: Icons.calendar_today_outlined,
                    value: '${s.totalRehearsals}',
                    label: eventsLabel,
                  ),
                  const SizedBox(height: 10),
                  _KpiBlock(
                    icon: Icons.groups_outlined,
                    value: '${s.peopleCovered}',
                    label: 'participantes únicos',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: s.attendanceRate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.neutralLight,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendItem(color: AppTheme.success, value: '${s.presentCount}', label: 'presentes'),
              _LegendItem(color: AppTheme.error, value: '${s.unjustifiedCount}', label: 'faltas'),
              _LegendItem(color: AppTheme.warning, value: '${s.justifiedCount}', label: 'justificadas'),
              Container(width: 1, height: 14, color: AppTheme.neutralLight),
              Text(
                '${s.totalParticipations} participações',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _KpiBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _KpiBlock({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: _textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  const _LegendItem({required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _textPrimary),
              ),
              TextSpan(
                text: ' $label',
                style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EventReportTile extends StatelessWidget {
  final RehearsalSummary item;
  final GeoNameResolver geo;
  final VoidCallback onTap;
  const EventReportTile({super.key, required this.item, required this.geo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = item.rehearsal;
    final pct = (item.attendanceRate * 100).round();
    final location = (r.place ?? '').trim().isNotEmpty ? r.place! : geo.levelName(r);
    final peopleLabel = item.participantCount == 1 ? 'participante' : 'participantes';

    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '${r.displayTitle}, $pct por cento de presença, ${item.participantCount} participantes',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 12),
          child: Row(
            children: [
              ReportDateBlock(date: r.dateTime),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportEventTypeBadge(type: r.eventType),
                    const SizedBox(height: 4),
                    Text(
                      r.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _MetaLine(icon: Icons.location_on_outlined, text: location),
                    const SizedBox(height: 2),
                    _MetaLine(icon: Icons.groups_outlined, text: '${item.participantCount} $peopleLabel'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: attendanceRateColor(item.attendanceRate),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportDateBlock extends StatelessWidget {
  final DateTime date;
  const ReportDateBlock({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    const months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            months[date.month - 1],
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportEventTypeBadge extends StatelessWidget {
  final EventType type;
  const ReportEventTypeBadge({super.key, required this.type});

  Color get _accent => switch (type) {
        EventType.seminar => AppTheme.accentPurple,
        EventType.rehearsal => AppTheme.primary,
        EventType.meeting => const Color(0xFF607D8B),
        EventType.assistance => AppTheme.error,
        _ => eventTypeAccent(type),
      };

  @override
  Widget build(BuildContext context) {
    final color = _accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  const AttendanceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('Presente', AppTheme.success),
      AttendanceStatus.unjustifiedAbsence => ('Falta', AppTheme.error),
      AttendanceStatus.justifiedAbsence => ('Justificada', AppTheme.warning),
      AttendanceStatus.unmarked => ('Pendente', _textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class PersonReportTile extends StatelessWidget {
  final PersonSummary item;
  final GeoNameResolver geo;
  final VoidCallback onTap;
  const PersonReportTile({super.key, required this.item, required this.geo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = item.person;
    final pct = (item.attendanceRate * 100).round();
    final role = p.roles.isEmpty ? null : p.roles.first;
    final location = geo.poloName(p.poloId) ?? geo.personLocationLine(p);
    final initials = personInitials(p.fullName);

    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '${p.fullName}, $pct por cento de presença, ${item.present} de ${item.eventCount} eventos',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
                foregroundColor: AppTheme.primary,
                child: Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayPersonName(p.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary),
                    ),
                    if (role != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _MetaLine(icon: Icons.location_on_outlined, text: location),
                    ],
                    const SizedBox(height: 2),
                    _MetaLine(
                      icon: Icons.event_available_outlined,
                      text: '${item.present}/${item.eventCount} eventos',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: attendanceRateColor(item.attendanceRate),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

}

class ReportsPeriodBar extends StatelessWidget {
  final String rangeLabel;
  final VoidCallback onPickRange;
  final VoidCallback onOpenFilters;
  final EdgeInsetsGeometry padding;
  const ReportsPeriodBar({
    super.key,
    required this.rangeLabel,
    required this.onPickRange,
    required this.onOpenFilters,
    this.padding = const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPickRange,
                child: Semantics(
                  button: true,
                  label: 'Período, $rangeLabel',
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rangeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpenFilters,
              child: const SizedBox(
                height: 44,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_outlined, size: 18, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'Filtros',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsActiveFiltersLine extends StatelessWidget {
  final String line;
  final VoidCallback? onClear;
  const ReportsActiveFiltersLine({super.key, required this.line, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Limpar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class ReportsListFooter extends StatelessWidget {
  final String text;
  const ReportsListFooter({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _textSecondary, fontSize: 12),
      ),
    );
  }
}

class ReportsEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onChangePeriod;
  final VoidCallback? onClearFilters;
  const ReportsEmptyState({
    super.key,
    required this.title,
    this.message = 'Altere o período ou os filtros.',
    this.onChangePeriod,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 32, color: _textSecondary.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (onChangePeriod != null)
              TextButton(onPressed: onChangePeriod, child: const Text('Alterar período')),
            if (onClearFilters != null)
              TextButton(onPressed: onClearFilters, child: const Text('Limpar filtros')),
          ],
        ),
      ),
    );
  }
}
