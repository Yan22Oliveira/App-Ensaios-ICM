import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/core.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/domain.dart';
import '../../domain/entities.dart';
import '../presentation.dart';
import '../shared/geo_lookup.dart';

class AttendanceView extends StatefulWidget {
  final String rehearsalId;
  final String currentUserId;
  const AttendanceView({
    super.key,
    required this.rehearsalId,
    required this.currentUserId,
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // carrega dados de presença
    context.read<AttendanceController>().load();
    // garante nomes de geo
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) {
      resolver.preloadAll().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  String _fmtDateOnly(DateTime? d) {
    if (d == null) return '--/--/----';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtHour(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.read<AttendanceController>();

    return BlocBuilder<AttendanceController, AttendanceState>(
      buildWhen: (prev, curr) =>
          prev.loading != curr.loading ||
          prev.errorMessage != curr.errorMessage ||
          prev.rehearsal != curr.rehearsal ||
          prev.participants != curr.participants ||
          prev.records != curr.records,
      builder: (context, state) {
        if (state.errorMessage != null && !state.loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chamada', style: TextStyle(fontWeight: FontWeight.w700))),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text(state.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => c.load(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: BlocBuilder<AttendanceController, AttendanceState>(
              builder: (context, state) {
                if (state.loading) {
                  return const Text('Carregando chamada...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  );
                }
                final d = c.state.rehearsal?.dateTime;
            final dateStr = _fmtDateOnly(d);
            return Text(
             'Chamada - $dateStr',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
      ),

      // Rodapé só quando NÃO estiver finalizada
      bottomNavigationBar: SafeArea(
        child: BlocBuilder<AttendanceController, AttendanceState>(
          builder: (context, state) {
            if (state.loading || state.isClosed) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await _confirmFinish(context);
                  if (ok == true) {
                    await c.finalize();
                    if (context.mounted) {
                      await _showCallFinishedSheet(context, c);
                    }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Finalizar chamada'),
                ),
              ),
            );
          },
        ),
      ),

      body: BlocBuilder<AttendanceController, AttendanceState>(
        buildWhen: (prev, curr) =>
            prev.loading != curr.loading ||
            prev.participants != curr.participants ||
            prev.records != curr.records ||
            prev.rehearsal != curr.rehearsal,
        builder: (context, state) {
          if (state.loading) return const Center(child: CircularProgressIndicator());

          final controller = context.read<AttendanceController>();
          final participants = controller.filteredParticipants;
          final geo = context.read<GeoNameResolver>();

          if (state.rehearsal != null && participants.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeaderBlock(
                    controller: controller,
                    locationLabel: geo.locationLabel(state.rehearsal!),
                    timeLabel:
                    '${_fmtDateOnly(state.rehearsal!.dateTime)} • ${_fmtHour(state.rehearsal!.dateTime)}',
                    place: state.rehearsal!.place,
                    isClosed: state.isClosed,
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: Colors.black38),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum participante encontrado para este evento.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Verifique se há pessoas cadastradas com o mesmo nível (polo/área/região) e escopo do evento.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              if (state.rehearsal != null)
                SliverToBoxAdapter(
                  child: _HeaderBlock(
                    controller: controller,
                    locationLabel: geo.locationLabel(state.rehearsal!),
                    timeLabel:
                    '${_fmtDateOnly(state.rehearsal!.dateTime)} • ${_fmtHour(state.rehearsal!.dateTime)}',
                    place: state.rehearsal!.place,
                    isClosed: state.isClosed,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  child: _BulkActions(controller: controller),
                ),
              ),
              SliverList.separated(
                itemBuilder: (_, i) {
                  final p = participants[i];
                  final record = state.records[p.id];
                  final st = record?.status ?? AttendanceStatus.unmarked;
                  final warn = controller.needsJustification(p);

                  return Opacity(
                    opacity: state.isClosed ? 0.6 : 1,
                    child: IgnorePointer(
                      ignoring: state.isClosed, // bloqueia interação quando finalizada
                      child: PersonCard(
                        person: p,
                        status: st,
                        showWarn: warn,
                        onMarkP: () => controller.setStatus(p, AttendanceStatus.present),
                        onMarkF: () => controller.setStatus(p, AttendanceStatus.unjustifiedAbsence),
                        onMarkJ: () async {
                          final text = await _justifyDialog(context);
                          if (text != null && text.trim().isNotEmpty) {
                            await controller.setStatus(
                              p,
                              AttendanceStatus.justifiedAbsence,
                              justification: text.trim(),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: participants.length,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
        );
      },
    );
  }

  Future<String?> _justifyDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Justificativa'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Descreva a justificativa'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<bool?> _confirmFinish(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar chamada?'),
        content: const Text('Depois de finalizada, a chamada fica bloqueada para edição.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
  }

  Future<void> _showCallFinishedSheet(BuildContext context, AttendanceController c) async {
    EventReport? report;
    try {
      report = await context.read<IEventReportRepository>().getByEventId(widget.rehearsalId);
    } catch (_) {}
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chamada finalizada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                  '${c.presentCount} presentes\n${c.unjustifiedCount} faltas\n${c.justifiedCount} justificadas',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openEventReport(context, widget.rehearsalId);
                    },
                    child: Text(report == null ? 'Criar relatório do evento' : 'Ver relatório do evento'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Concluir'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final AttendanceController controller;
  final String locationLabel;
  final String timeLabel;
  final String? place;
  final bool isClosed;

  const _HeaderBlock({
    required this.controller,
    required this.locationLabel,
    required this.timeLabel,
    required this.place,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner/Badge quando finalizado
            if (isClosed) ...[
              Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successSoftBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.successSoftBorder),
                    ),
                    child: const Text(
                      'Chamada finalizada',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            Text(
              controller.state.rehearsal?.displayTitle ?? locationLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (controller.state.rehearsal != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  EventTypeChip(type: controller.state.rehearsal!.eventType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationLabel,
                      style: const TextStyle(color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [timeLabel, if ((place ?? '').isNotEmpty) place!].join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.state.participants.length} participantes',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(children: [
              CountChip(label: 'P', value: controller.presentCount, color: AppTheme.success),
              const SizedBox(width: 8),
              CountChip(label: 'F', value: controller.unjustifiedCount, color: AppTheme.error),
              const SizedBox(width: 8),
              CountChip(
                label: 'J',
                value: controller.justifiedCount,
                color: AppTheme.warning,
                textColor: Colors.black87,
              ),
            ]),
            if (controller.unmarkedCount > 0 && !isClosed) ...[
              const SizedBox(height: 8),
              Text(
                'Falta marcar: ${controller.unmarkedCount}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
            if (controller.state.rehearsal != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              _EventReportAccessRow(eventId: controller.state.rehearsal!.id),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  final AttendanceController controller;
  const _BulkActions({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isClosed = context.select<AttendanceController, bool>((c) => c.state.isClosed);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: isClosed ? null : () => controller.markAll(AttendanceStatus.present),
      child: const Text('Lançar presença para todos'),
    );
  }
}

class _EventReportAccessRow extends StatefulWidget {
  final String eventId;
  const _EventReportAccessRow({required this.eventId});

  @override
  State<_EventReportAccessRow> createState() => _EventReportAccessRowState();
}

class _EventReportAccessRowState extends State<_EventReportAccessRow> {
  EventReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final report = await context.read<IEventReportRepository>().getByEventId(widget.eventId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _loading
        ? '…'
        : (_report == null ? 'Não iniciado' : _report!.status.label);
    final color = _report == null
        ? Colors.blueGrey
        : _report!.status == EventReportStatus.finalized
            ? AppTheme.success
            : AppTheme.accentOrange;

    return InkWell(
      onTap: () async {
        await openEventReport(context, widget.eventId);
        if (mounted) _reload();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: AppTheme.primary.withValues(alpha: .9)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Relatório do evento', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(statusLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
