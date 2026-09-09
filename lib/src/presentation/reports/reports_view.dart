import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../src.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  DateTimeRange? _range;
  EventType? _eventType;
  String? _regionId;
  String? _areaId;
  String? _poloId;
  bool _onlyWithRecords = true;

  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];

  /// Período padrão: mês atual, para que o relatório traga ensaios (listBetween) em vez de só próximos (listUpcoming).
  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0); // último dia do mês 00:00
    return DateTimeRange(start: start, end: end);
  }

  @override
  void initState() {
    super.initState();
    _range = _defaultRange();
    _initGeo();
    _apply();
  }

  Future<void> _initGeo() async {
    final geoRepo = context.read<IGeoRepository>();
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) await resolver.preloadAll();

    final controller = context.read<ReportsController>();
    final profile = controller.profile;

    if (profile == null ||
        profile.role == UserRole.admin ||
        profile.role == UserRole.readonly) {
      final rs = await geoRepo.regions();
      if (mounted) setState(() => _regions = rs);
      return;
    }

    // Limitar opções e pré-preencher conforme escopo do usuário
    if (profile.role == UserRole.polo && profile.poloId != null) {
      List<Region> regs = [];
      List<Area> areaList = [];
      List<Polo> poloList = [];
      if (profile.regionId != null) {
        regs = (await geoRepo.regions()).where((r) => r.id == profile.regionId).toList();
        areaList = await geoRepo.areasByRegion(profile.regionId!);
      }
      if (profile.areaId != null) poloList = await geoRepo.polosByArea(profile.areaId!);
      if (mounted) {
        setState(() {
          _regionId = profile.regionId;
          _areaId = profile.areaId;
          _poloId = profile.poloId;
          _regions = regs;
          _areas = areaList;
          _polos = poloList;
        });
        _apply();
      }
      return;
    }

    if (profile.role == UserRole.area && profile.areaId != null) {
      List<Region> regs = [];
      List<Area> areaList = [];
      List<Polo> poloList = [];
      if (profile.regionId != null) {
        regs = (await geoRepo.regions()).where((r) => r.id == profile.regionId).toList();
        areaList = await geoRepo.areasByRegion(profile.regionId!);
      }
      poloList = await geoRepo.polosByArea(profile.areaId!);
      if (mounted) {
        setState(() {
          _regionId = profile.regionId;
          _areaId = profile.areaId;
          _regions = regs;
          _areas = areaList;
          _polos = poloList;
        });
        _apply();
      }
      return;
    }

    if (profile.role == UserRole.region && profile.regionId != null) {
      final regs = (await geoRepo.regions()).where((r) => r.id == profile.regionId).toList();
      final areas = await geoRepo.areasByRegion(profile.regionId!);
      if (mounted) {
        setState(() {
          _regionId = profile.regionId;
          _regions = regs;
          _areas = areas;
        });
        _apply();
      }
      return;
    }

    if (profile.role == UserRole.maanaim && profile.regionId != null) {
      final regions = await geoRepo.regionsByMaanaim(profile.regionId!);
      if (mounted) {
        setState(() {
          _regionId = profile.regionId;
          _regions = regions;
        });
        _apply();
      }
      return;
    }

    final rs = await geoRepo.regions();
    if (mounted) setState(() => _regions = rs);
  }

  void _apply() {
    context.read<ReportsController>().setFilters(
      ReportFilters(
        range: _range,
        eventType: _eventType,
        regionId: _regionId,
        areaId: _areaId,
        poloId: _poloId,
        onlyWithRecords: _onlyWithRecords,
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = context.read<ReportsController>().buildCsvRaw();
    final fileName = 'relatorio_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26, borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Exportar CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        csv,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.25),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // Ações
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Compartilhar'),
                          onPressed: () async {
                            final dir = await getTemporaryDirectory();
                            final path = '${dir.path}/$fileName';
                            final f = File(path);
                            await f.writeAsString(csv);
                            await Share.shareXFiles([XFile(path, mimeType: 'text/csv', name: fileName)]);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Salvar arquivo'),
                          onPressed: () async {
                            final dir = await getTemporaryDirectory();
                            final path = '${dir.path}/$fileName';
                            final f = File(path);
                            await f.writeAsString(csv);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Arquivo salvo em: $path')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar conteúdo'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('CSV copiado para a área de transferência')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _previewPdf(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        // usa o tema do Dialog e limita tamanho para celular
        final mq = MediaQuery.of(context);
        final w = mq.size.width * 0.9;
        final h = mq.size.height * 0.56;

        return AlertDialog(
          title: const Text('Relatório PDF'),
          contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          content: SizedBox(
            width: w,
            height: h,
            // PdfPreview já exibe botões de share/print nativos
            child: PdfPreview(
              build: (format) => _buildPdfBytes(context),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: 'relatorio.pdf',
              initialPageFormat: PdfPageFormat.a4,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final bytes = await _buildPdfBytes(context);
    if (!mounted) return;

    // Abre o visualizador do próprio pacote printing (iOS/Android/Web/Desk)
    await Printing.layoutPdf(onLayout: (_) async => bytes);
    // Se quiser compartilhar direto, use:
    // await Printing.sharePdf(bytes: bytes, filename: 'relatorio.pdf');
  }

  Future<Uint8List> _buildPdfBytes(BuildContext context) async {
    final controller = context.read<ReportsController>();
    final reportRepo = context.read<IEventReportRepository>();
    final eventReports = <(Rehearsal, EventReport)>[];
    final events = controller.state.byRehearsal.map((e) => e.rehearsal).toList();
    const chunk = 8;
    for (var i = 0; i < events.length; i += chunk) {
      final slice = events.sublist(i, i + chunk > events.length ? events.length : i + chunk);
      final loaded = await Future.wait(slice.map((e) => reportRepo.getByEventId(e.id)));
      for (var j = 0; j < slice.length; j++) {
        final report = loaded[j];
        if (report != null) eventReports.add((slice[j], report));
      }
    }
    eventReports.sort((a, b) => a.$1.dateTime.compareTo(b.$1.dateTime));
    return ReportPdfBuilder(
      state: controller.state,
      geo: context.read<GeoNameResolver>(),
      profile: controller.profile,
      eventReports: eventReports,
    ).build();
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          'Relatórios',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocBuilder<ReportsController, ReportsState>(
        builder: (context, state) {
          return Column(
            children: [
              // FILTERS
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(color: Colors.white, boxShadow: const [BoxShadow(blurRadius: 6, color: AppTheme.cardShadowLight)]),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text(_range == null
                                ? 'Período'
                                : '${_d(_range!.start)} – ${_d(_range!.end)}'),
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(now.year - 2),
                                lastDate: DateTime(now.year + 2),
                                initialDateRange: _range ??
                                    DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
                              );
                              if (picked != null) setState(() => _range = picked);
                              _apply();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<EventType?>(
                      value: _eventType,
                      onChanged: (v) { setState(() => _eventType = v); _apply(); },
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ...EventType.values.map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.label))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Region / Area / Polo em cascata
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _regionId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Região', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todos')),
                              ..._regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                            ],
                            onChanged: (v) async {
                              setState(() { _regionId = v; _areaId = null; _poloId = null; _areas = const []; _polos = const []; });
                              if (v != null) {
                                final areas = await context.read<IGeoRepository>().areasByRegion(v);
                                setState(() => _areas = areas);
                              }
                              _apply();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _areaId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Área', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todos')),
                              ..._areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                            ],
                            onChanged: (v) async {
                              setState(() { _areaId = v; _poloId = null; _polos = const []; });
                              if (v != null) {
                                final polos = await context.read<IGeoRepository>().polosByArea(v);
                                setState(() => _polos = polos);
                              }
                              _apply();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _poloId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Polo', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todos')),
                              ..._polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                            ],
                            onChanged: (v) { setState(() => _poloId = v); _apply(); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Switch.adaptive(
                          value: _onlyWithRecords,
                          onChanged: (v) { setState(() => _onlyWithRecords = v); _apply(); },
                        ),
                        const Text('Somente com registros'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportCsv(context),
                              icon: const Icon(Icons.file_download_rounded),
                              label: const Text('Export CSV'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _previewPdf(context),   // <- em vez de _exportPdf
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text('Export PDF'),
                            ),
                          ],
                        ),
                      ],
                    )

                  ],
                ),
              ),

              // BODY
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : DefaultTabController(
                  length: 3,
                  initialIndex: 0,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: AppTheme.primary,
                        tabs: [
                          Tab(text: 'Visão geral'),
                          Tab(text: 'Por pessoa'),
                          Tab(text: 'Por evento'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OverviewTab(),
                            _ByPersonTab(),
                            _ByRehearsalTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ---------------- Tabs ----------------

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ReportsController>().state;
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Totais',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Eventos totais',
                value: '${s.totalRehearsals}',
                icon: Icons.event_rounded,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Presentes %',
                value: pct(s.attendanceRate),
                icon: Icons.check_circle_rounded,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Justificadas %',
                value: pct(s.justificationRate),
                icon: Icons.warning_amber_rounded,
                color: AppTheme.warning,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Membros',
                value: '${s.peopleCovered}',
                icon: Icons.people_alt_rounded,
                color: AppTheme.accentPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ByPersonTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ReportsController>().state;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: s.byPerson.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final it = s.byPerson[i];
        final pct = (it.attendanceRate * 100).toStringAsFixed(0);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(blurRadius: 8, color: AppTheme.cardShadowMedium)]),
          child: Row(
            children: [
              CircleAvatar(child: Text(it.person.fullName.substring(0,1))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.person.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('P ${it.present}   •   F ${it.unjustified}   •   J ${it.justified}', style: const TextStyle(color: Colors.black54)),
              ])),
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }
}

class _ByRehearsalTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<ReportsController>().state;
    final geo = context.read<GeoNameResolver>();
    String hhmm(DateTime d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: s.byRehearsal.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final it = s.byRehearsal[i];
        final r = it.rehearsal;
        final pct = (it.attendanceRate * 100).toStringAsFixed(0);
        final colorBadge = switch (r.level) {
          RehearsalLevel.polo     => AppTheme.primary,
          RehearsalLevel.area     => AppTheme.accentPurple,
          RehearsalLevel.region   => AppTheme.success,
          RehearsalLevel.maanaim  => AppTheme.accentOrange,
        };
        String mesAbreviado(DateTime date) {
          const meses = [
            'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
            'jul', 'ago', 'set', 'out', 'nov', 'dez'
          ];
          return meses[date.month - 1];
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(blurRadius: 8, color: AppTheme.cardShadowMedium,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colorBadge.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorBadge.withOpacity(.4)),
                ),
                child: Column(
                  children: [
                    Text(r.dateTime.day.toString().padLeft(2, '0'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorBadge,),),
                    Text(mesAbreviado(r.dateTime), style: TextStyle(fontSize: 12, color: colorBadge)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.eventType.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      geo.levelName(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${hhmm(r.dateTime)} • ${r.place ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'P ${it.present}  •  F ${it.unjustified}  •  J ${it.justified}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }

}
