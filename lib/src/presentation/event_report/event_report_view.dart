import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../src.dart';

class EventReportView extends StatefulWidget {
  const EventReportView({super.key});

  @override
  State<EventReportView> createState() => _EventReportViewState();
}

class _EventReportViewState extends State<EventReportView> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _responsibleCtrl = TextEditingController();
  final _overviewCtrl = TextEditingController();
  final _conclusionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _bound = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _responsibleCtrl.dispose();
    _overviewCtrl.dispose();
    _conclusionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _bindFrom(EventReportState state) {
    if (_bound || state.event == null) return;
    _bound = true;
    final report = state.report;
    final event = state.event!;
    _titleCtrl.text = (report?.title.trim().isNotEmpty ?? false)
        ? report!.title
        : 'Relatório de Atividades – ${event.displayTitle}';
    _responsibleCtrl.text = report?.responsible ?? '';
    _overviewCtrl.text = report?.overview ?? '';
    _conclusionCtrl.text = report?.conclusion ?? '';
    _notesCtrl.text = report?.notes ?? '';
  }

  Future<void> _onSaveDraft() async {
    final c = context.read<EventReportController>();
    final ok = await c.saveDraft(
      title: _titleCtrl.text,
      responsible: _responsibleCtrl.text,
      overview: _overviewCtrl.text,
      conclusion: _conclusionCtrl.text,
      notes: _notesCtrl.text,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rascunho salvo')),
      );
    }
  }

  Future<void> _onFinalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar relatório?'),
        content: const Text(
          'Após finalizar, o relatório ficará disponível para consulta. Você poderá editá-lo novamente quando quiser.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final c = context.read<EventReportController>();
    final ok = await c.finalize(
      title: _titleCtrl.text,
      responsible: _responsibleCtrl.text,
      overview: _overviewCtrl.text,
      conclusion: _conclusionCtrl.text,
      notes: _notesCtrl.text,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório finalizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventReportController, EventReportState>(
      listenWhen: (p, c) => p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        final msg = state.errorMessage;
        if (msg == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      builder: (context, state) {
        _bindFrom(state);

        return Scaffold(
          backgroundColor: AppTheme.bgLight,
          appBar: AppBar(
            title: const Text(
              'Relatório do Evento',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (!state.editing && state.report != null)
                TextButton(
                  onPressed: () => context.read<EventReportController>().startEditing(),
                  child: const Text('Editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          bottomNavigationBar: state.editing && !state.loading
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: state.saving ? null : _onSaveDraft,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Salvar rascunho'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.saving ? null : _onFinalize,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: state.saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Finalizar relatório'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.event == null
                  ? const Center(child: Text('Evento não encontrado'))
                  : GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Form(
                        key: _form,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            _EventSummaryCard(event: state.event!),
                            const SizedBox(height: 12),
                            _StatusRow(report: state.report),
                            const SizedBox(height: 12),
                            if (state.editing)
                              ..._editSections()
                            else
                              ..._readSections(state),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  List<Widget> _editSections() {
    return [
      _SectionCard(
        title: 'Conteúdo',
        child: Column(
          children: [
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título do relatório *',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responsibleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Responsáveis',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.people_alt_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _overviewCtrl,
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Panorama geral *',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conclusionCtrl,
              minLines: 5,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Conclusão *',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              minLines: 4,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _readSections(EventReportState state) {
    final report = state.report;
    if (report == null) return const [];
    final event = state.event!;
    final geo = context.read<GeoNameResolver>();

    return [
      _SectionCard(
        title: report.title.isEmpty ? 'Relatório' : report.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaLine(label: 'Data', value: _fmtLongDate(event.dateTime)),
            _MetaLine(label: 'Local', value: _placeLine(event, geo)),
            if ((report.responsible ?? '').trim().isNotEmpty)
              _MetaLine(label: 'Responsáveis', value: report.responsible!.trim()),
            const SizedBox(height: 16),
            const Text('1. Panorama Geral', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _BodyText(report.overview),
            const SizedBox(height: 16),
            const Text('2. Conclusão', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _BodyText(report.conclusion),
            if ((report.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Observações', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _BodyText(report.notes!.trim()),
            ],
            const SizedBox(height: 16),
            Text(
              'Última atualização em ${_fmtDate(report.updatedAt)} às ${_fmtTime(report.updatedAt)}'
              '${(report.updatedByName ?? '').trim().isNotEmpty ? ' por ${report.updatedByName!.trim()}' : ''}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ];
  }

  String _placeLine(Rehearsal event, GeoNameResolver geo) {
    final parts = <String>[
      if ((event.place ?? '').trim().isNotEmpty) event.place!.trim(),
      geo.levelName(event),
    ];
    return parts.join(' • ');
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtLongDate(DateTime d) => _fmtDate(d);
}

class _EventSummaryCard extends StatelessWidget {
  final Rehearsal event;
  const _EventSummaryCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();
    final d = event.dateTime;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final place = (event.place ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EventTypeChip(type: event.eventType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$date • $time', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 2),
          Text(
            [if (place.isNotEmpty) place, geo.levelName(event)].join(' • '),
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final EventReport? report;
  const _StatusRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final label = report == null ? 'Não iniciado' : report!.status.label;
    final color = report == null
        ? Colors.blueGrey
        : report!.status == EventReportStatus.finalized
            ? AppTheme.success
            : AppTheme.accentOrange;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;
  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    final value = text.trim().isEmpty ? '—' : text.trim();
    return Text(value, style: const TextStyle(height: 1.45));
  }
}
