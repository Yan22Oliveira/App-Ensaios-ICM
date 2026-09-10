import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class PersonReportDetailView extends StatelessWidget {
  const PersonReportDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();
    return BlocBuilder<IndividualReportController, IndividualReportState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.bgLight,
          appBar: AppBar(
            title: const Text('Relatório Individual', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: state.errorMessage != null
              ? _ErrorBody(message: state.errorMessage!, onRetry: () => context.read<IndividualReportController>().reload())
              : Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _MemberHeader(summary: state.summary, geo: geo),
                        ReportsPeriodBar(
                          rangeLabel: _rangeLabel(state.filters.range),
                          onPickRange: () => _pickRange(context, state),
                          onOpenFilters: () => _openFilters(context, state, geo),
                          padding: const EdgeInsets.only(top: 16),
                        ),
                        if (_extraFiltersLine(state, geo).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                            child: Text(
                              _extraFiltersLine(state, geo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF66717D), fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (state.summary.eventCount == 0)
                          ReportsEmptyState(
                            title: 'Nenhum evento encontrado',
                            message: 'O membro não possui eventos previstos no período selecionado.',
                            onChangePeriod: () => _pickRange(context, state),
                            onClearFilters: _canClear(state)
                                ? () => context.read<IndividualReportController>().setFilters(
                                      ReportFilters(
                                        range: state.filters.range,
                                        regionId: state.lockRegion ? state.filters.regionId : null,
                                        areaId: state.lockArea ? state.filters.areaId : null,
                                        poloId: state.lockPolo ? state.filters.poloId : null,
                                      ),
                                    )
                                : null,
                          )
                        else ...[
                          const _SectionLabel('RESUMO NO PERÍODO'),
                          const SizedBox(height: 16),
                          _SummaryBlock(summary: state.summary),
                          const SizedBox(height: 8),
                          const Text(
                            'Considera apenas os eventos em que o membro foi convocado.',
                            style: TextStyle(color: Color(0xFF66717D), fontSize: 12, height: 1.3),
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel('DESEMPENHO'),
                          const SizedBox(height: 12),
                          _PerformanceRow(summary: state.summary),
                          const SizedBox(height: 16),
                          if (frequencyInsightFromRate(state.summary.attendanceRate, hasEvents: true) != null)
                            _InsightCard(
                              insight: frequencyInsightFromRate(state.summary.attendanceRate, hasEvents: true)!,
                            ),
                          const SizedBox(height: 24),
                          const _SectionLabel('HISTÓRICO'),
                          const SizedBox(height: 4),
                          _HistoryPreview(
                            summary: state.summary,
                            geo: geo,
                          ),
                        ],
                      ],
                    ),
                    if (state.loading)
                      const ColoredBox(
                        color: Color(0x66FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
        );
      },
    );
  }

  bool _canClear(IndividualReportState state) {
    return state.filters.eventType != null ||
        (!state.lockRegion && state.filters.regionId != null) ||
        (!state.lockArea && state.filters.areaId != null) ||
        (!state.lockPolo && state.filters.poloId != null);
  }

  String _extraFiltersLine(IndividualReportState state, GeoNameResolver geo) {
    final f = state.filters;
    return [
      if (f.eventType != null) f.eventType!.label,
      if (!state.lockRegion && f.regionId != null) geo.regionName(f.regionId) ?? f.regionId!,
      if (!state.lockArea && f.areaId != null) geo.areaName(f.areaId) ?? f.areaId!,
      if (!state.lockPolo && f.poloId != null) geo.poloName(f.poloId) ?? f.poloId!,
    ].join(' • ');
  }

  String _rangeLabel(DateTimeRange? range) {
    if (range == null) return 'Período';
    String part(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${part(range.start)} – ${part(range.end)}';
  }

  Future<void> _pickRange(BuildContext context, IndividualReportState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: state.filters.range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0)),
    );
    if (picked == null || !context.mounted) return;
    await context.read<IndividualReportController>().setFilters(state.filters.copyWith(range: picked));
  }

  Future<void> _openFilters(BuildContext context, IndividualReportState state, GeoNameResolver geo) async {
    final result = await showReportsFiltersSheet(
      context: context,
      initial: ReportsFiltersDraft(
        eventType: state.filters.eventType,
        regionId: state.filters.regionId,
        areaId: state.filters.areaId,
        poloId: state.filters.poloId,
        onlyWithRecords: true,
        regions: state.regions,
        areas: state.areas,
        polos: state.polos,
      ),
      lockRegion: state.lockRegion,
      lockArea: state.lockArea,
      lockPolo: state.lockPolo,
    );
    if (result == null || !context.mounted) return;
    await context.read<IndividualReportController>().setFilters(
          ReportFilters(
            range: state.filters.range,
            eventType: result.eventType,
            regionId: result.regionId,
            areaId: result.areaId,
            poloId: result.poloId,
            onlyWithRecords: true,
          ),
          regions: result.regions,
          areas: result.areas,
          polos: result.polos,
        );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  final PersonSummary summary;
  final GeoNameResolver geo;
  const _MemberHeader({required this.summary, required this.geo});

  @override
  Widget build(BuildContext context) {
    final person = summary.person;
    final name = displayPersonName(person.fullName);
    final role = person.roles.isEmpty ? null : person.roles.first;
    final location = [
      if (geo.poloName(person.poloId) != null) geo.poloName(person.poloId)!,
      if (geo.areaName(person.areaId) != null) geo.areaName(person.areaId)!,
      if (geo.regionName(person.regionId) != null) geo.regionName(person.regionId)!,
    ].join(' • ');
    return Semantics(
      label:
          '$name, frequência ${formatAttendancePercent(summary.attendanceRate)}, ${summary.present} presenças em ${summary.eventCount} eventos previstos.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
            foregroundColor: AppTheme.primary,
            child: Text(personInitials(name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: Color(0xFF151A1F)),
                ),
                if (role != null) ...[
                  const SizedBox(height: 4),
                  Text(role, style: const TextStyle(color: Color(0xFF66717D), fontSize: 13)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(location, style: const TextStyle(color: Color(0xFF66717D), fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF66717D),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final PersonSummary summary;
  const _SummaryBlock({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = formatAttendancePercent(summary.attendanceRate);
    final metrics = [
      (summary.eventCount.toString(), summary.eventCount == 1 ? 'evento previsto' : 'eventos previstos'),
      (summary.present.toString(), summary.present == 1 ? 'presença' : 'presenças'),
      (summary.unjustified.toString(), summary.unjustified == 1 ? 'falta' : 'faltas'),
      (summary.justified.toString(), summary.justified == 1 ? 'justificada' : 'justificadas'),
    ];

    return Semantics(
      label:
          '${summary.person.fullName}, frequência ${formatAttendancePercent(summary.attendanceRate)}, ${summary.present} presenças em ${summary.eventCount} eventos previstos.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 340;
          final ring = _AttendanceRing(value: summary.attendanceRate, label: pct);
          final list = Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final m in metrics)
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
                      Text(m.$2, style: const TextStyle(color: Color(0xFF66717D), fontSize: 12)),
                    ],
                  ),
                ),
            ],
          );
          if (stack) {
            return Column(
              children: [
                ring,
                const SizedBox(height: 16),
                list,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              Container(
                width: 1,
                height: 132,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppTheme.neutralLight,
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceRing extends StatelessWidget {
  final double value;
  final String label;
  const _AttendanceRing({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _RingPainter(value: value.clamp(0.0, 1.0), color: attendanceRateColor(value)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF151A1F))),
              const Text('Frequência', style: TextStyle(color: Color(0xFF66717D), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final track = Paint()
      ..color = AppTheme.neutralLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _HistoryPreview extends StatelessWidget {
  final PersonSummary summary;
  final GeoNameResolver geo;
  const _HistoryPreview({required this.summary, required this.geo});

  @override
  Widget build(BuildContext context) {
    final events = summary.events.take(3).toList();
    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          PersonEventHistoryTile(
            item: events[i],
            geo: geo,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onTap: () => openPersonEventAttendance(context, events[i].rehearsal.id),
          ),
          if (i < events.length - 1) const Divider(height: 1, color: AppTheme.neutralLight),
        ],
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonEventHistoryView(summary: summary, geo: geo),
              ),
            );
          },
          child: Text(
            summary.events.length > 3
                ? 'Ver todos os ${summary.events.length} eventos'
                : 'Ver histórico de eventos',
          ),
        ),
      ],
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final PersonSummary summary;
  const _PerformanceRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.eventCount;
    double share(int n) => total == 0 ? 0 : n / total;
    return Row(
      children: [
        _PerfCard(
          icon: Icons.check_circle_outline,
          color: AppTheme.success,
          value: '${summary.present}',
          label: 'Presentes',
          percent: formatAttendancePercent(share(summary.present)),
          emphasize: summary.present > 0,
        ),
        const SizedBox(width: 8),
        _PerfCard(
          icon: Icons.close_rounded,
          color: AppTheme.error,
          value: '${summary.unjustified}',
          label: 'Faltas',
          percent: formatAttendancePercent(share(summary.unjustified)),
          emphasize: summary.unjustified > 0,
        ),
        const SizedBox(width: 8),
        _PerfCard(
          icon: Icons.info_outline,
          color: AppTheme.warning,
          value: '${summary.justified}',
          label: 'Justificadas',
          percent: formatAttendancePercent(share(summary.justified)),
          emphasize: summary.justified > 0,
        ),
      ],
    );
  }
}

class _PerfCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String percent;
  final bool emphasize;
  const _PerfCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.percent,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF66717D);
    final accent = emphasize ? color : muted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF66717D), fontSize: 11)),
            const SizedBox(height: 4),
            Text(percent, style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final FrequencyInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final warning = insight == FrequencyInsight.low || insight == FrequencyInsight.regular;
    final bg = warning ? AppTheme.warning.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.08);
    final iconColor = warning ? const Color(0xFFD4A017) : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(insight.body, style: const TextStyle(color: Color(0xFF66717D), fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
