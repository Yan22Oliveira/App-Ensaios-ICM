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
                    // Se preferir sair da tela ao finalizar, descomente:
                    // if (mounted) Navigator.pop(context);
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
                            'Nenhum participante encontrado para este ensaio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Verifique se há pessoas cadastradas com o mesmo nível (polo/área/região) e escopo do ensaio.',
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

            Text(locationLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              [timeLabel, if ((place ?? '').isNotEmpty) place!].join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 12),
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
