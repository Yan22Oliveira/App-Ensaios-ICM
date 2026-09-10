import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../src.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTimeRange? _range;
  EventType? _eventType;
  String? _regionId;
  String? _areaId;
  String? _poloId;
  bool _onlyWithRecords = true;

  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];

  bool _lockRegion = false;
  bool _lockArea = false;
  bool _lockPolo = false;

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!mounted || _tabs.indexIsChanging) return;
      context.read<ReportsController>().setTab(
            _tabs.index == 0 ? ReportsTab.byRehearsal : ReportsTab.byPerson,
          );
    });
    _range = _defaultRange();
    _initGeo();
    _apply();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _initGeo() async {
    final geoRepo = context.read<IGeoRepository>();
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) await resolver.preloadAll();
    if (!mounted) return;

    final controller = context.read<ReportsController>();
    final profile = controller.profile;

    if (profile == null ||
        profile.role == UserRole.admin ||
        profile.role == UserRole.readonly) {
      final rs = await geoRepo.regions();
      if (mounted) setState(() => _regions = rs);
      return;
    }

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
          _lockRegion = true;
          _lockArea = true;
          _lockPolo = true;
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
          _lockRegion = true;
          _lockArea = true;
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
          _lockRegion = true;
        });
        _apply();
      }
      return;
    }

    if (profile.role == UserRole.maanaim && profile.regionId != null) {
      final regions = await geoRepo.regionsByMaanaim(profile.regionId!);
      if (mounted) {
        setState(() {
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

  int get _activeFilterCount {
    var n = 0;
    if (_eventType != null) n++;
    if (!_lockRegion && _regionId != null) n++;
    if (!_lockArea && _areaId != null) n++;
    if (!_lockPolo && _poloId != null) n++;
    if (!_onlyWithRecords) n++;
    return n;
  }

  bool get _canClearFilters => _activeFilterCount > 0;

  void _clearFilters() {
    setState(() {
      _eventType = null;
      if (!_lockRegion) {
        _regionId = null;
        _areas = const [];
      }
      if (!_lockArea) {
        _areaId = null;
        _polos = const [];
      }
      if (!_lockPolo) _poloId = null;
      _onlyWithRecords = true;
    });
    _apply();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _apply();
    }
  }

  Future<void> _openFilters() async {
    final result = await showReportsFiltersSheet(
      context: context,
      initial: ReportsFiltersDraft(
        eventType: _eventType,
        regionId: _regionId,
        areaId: _areaId,
        poloId: _poloId,
        onlyWithRecords: _onlyWithRecords,
        regions: _regions,
        areas: _areas,
        polos: _polos,
      ),
      lockRegion: _lockRegion,
      lockArea: _lockArea,
      lockPolo: _lockPolo,
    );
    if (result == null || !mounted) return;
    setState(() {
      _eventType = result.eventType;
      _regionId = result.regionId;
      _areaId = result.areaId;
      _poloId = result.poloId;
      _onlyWithRecords = result.onlyWithRecords;
      _regions = result.regions;
      _areas = result.areas;
      _polos = result.polos;
    });
    _apply();
  }

  String _rangeLabel(DateTimeRange range) {
    String part(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${part(range.start)} – ${part(range.end)}';
  }

  String _filtersSummaryLine(GeoNameResolver geo) {
    final type = _eventType?.label ?? 'Todos os tipos';
    final region = _regionId == null ? 'Todos' : (geo.regionName(_regionId) ?? _regionId!);
    final area = _areaId == null ? 'Todos' : (geo.areaName(_areaId) ?? _areaId!);
    final polo = _poloId == null ? 'Todos' : (geo.poloName(_poloId) ?? _poloId!);
    return '$type • Região: $region • Área: $area • Polo: $polo';
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
        final mq = MediaQuery.of(context);
        final w = mq.size.width * 0.9;
        final h = mq.size.height * 0.56;

        return AlertDialog(
          title: const Text('Relatório PDF'),
          contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          content: SizedBox(
            width: w,
            height: h,
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

  void _openAttendance(String rehearsalId) {
    final authRepo = context.read<IAuthRepository>();
    final currentUserId = authRepo.currentUserId ?? '';
    if (currentUserId.isEmpty) return;
    final rehearsalRepo = context.read<IRehearsalRepository>();
    final personRepo = context.read<IPersonRepository>();
    final attendanceRepo = context.read<IAttendanceRepository>();

    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return BlocProvider(
        create: (_) => AttendanceController(
          rehearsalRepo: rehearsalRepo,
          personRepo: personRepo,
          attendanceRepo: attendanceRepo,
          rehearsalId: rehearsalId,
          currentUserId: currentUserId,
        ),
        child: AttendanceView(rehearsalId: rehearsalId, currentUserId: currentUserId),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();
    final rangeLabel = _range == null ? 'Período' : _rangeLabel(_range!);
    final filtersLine = _filtersSummaryLine(geo);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Relatórios', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'pdf') _previewPdf(context);
              if (v == 'csv') _exportCsv(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
              PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<ReportsController, ReportsState>(
        builder: (context, state) {
          if (state.errorMessage != null) {
            return Column(
              children: [
                ReportsPeriodBar(rangeLabel: rangeLabel, onPickRange: _pickRange, onOpenFilters: _openFilters),
                ReportsActiveFiltersLine(line: filtersLine, onClear: _canClearFilters ? _clearFilters : null),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _apply, child: const Text('Tentar novamente')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportsPeriodBar(rangeLabel: rangeLabel, onPickRange: _pickRange, onOpenFilters: _openFilters),
                    ReportsActiveFiltersLine(line: filtersLine, onClear: _canClearFilters ? _clearFilters : null),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Divider(height: 1, thickness: 1, color: AppTheme.neutralLight),
                    ),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      PeriodSummarySection(state: state),
                  ],
                ),
              ),
              if (!state.loading)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ReportsTabsHeader(controller: _tabs),
                ),
            ],
            body: state.loading
                ? const SizedBox.shrink()
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _EventsList(
                        items: state.byRehearsal,
                        geo: geo,
                        onTap: (id) => _openAttendance(id),
                        onChangePeriod: _pickRange,
                        onClearFilters: _canClearFilters ? _clearFilters : null,
                      ),
                      _PeopleList(
                        items: state.byPerson,
                        geo: geo,
                        filters: state.filters,
                        regions: _regions,
                        areas: _areas,
                        polos: _polos,
                        lockRegion: _lockRegion,
                        lockArea: _lockArea,
                        lockPolo: _lockPolo,
                        onChangePeriod: _pickRange,
                        onClearFilters: _canClearFilters ? _clearFilters : null,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _ReportsTabsHeader extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _ReportsTabsHeader({required this.controller});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.bgLight,
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.primary,
        unselectedLabelColor: const Color(0xFF66717D),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 2.5, color: AppTheme.primary),
          insets: EdgeInsets.symmetric(horizontal: 24),
        ),
        dividerColor: AppTheme.neutralLight,
        tabs: const [
          Tab(text: 'Por evento', height: 48),
          Tab(text: 'Por pessoa', height: 48),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ReportsTabsHeader oldDelegate) => oldDelegate.controller != controller;
}

class _EventsList extends StatelessWidget {
  final List<RehearsalSummary> items;
  final GeoNameResolver geo;
  final ValueChanged<String> onTap;
  final VoidCallback onChangePeriod;
  final VoidCallback? onClearFilters;
  const _EventsList({
    required this.items,
    required this.geo,
    required this.onTap,
    required this.onChangePeriod,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ReportsEmptyState(
        title: 'Nenhum evento encontrado',
        onChangePeriod: onChangePeriod,
        onClearFilters: onClearFilters,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length + 1,
      separatorBuilder: (_, i) {
        if (i >= items.length - 1) return const SizedBox.shrink();
        return const Divider(height: 1, thickness: 1, color: AppTheme.neutralLight);
      },
      itemBuilder: (_, i) {
        if (i == items.length) {
          return ReportsListFooter(
            text: '${items.length} evento${items.length == 1 ? '' : 's'} encontrado${items.length == 1 ? '' : 's'}',
          );
        }
        final item = items[i];
        return EventReportTile(
          item: item,
          geo: geo,
          onTap: () => onTap(item.rehearsal.id),
        );
      },
    );
  }
}

class _PeopleList extends StatelessWidget {
  final List<PersonSummary> items;
  final GeoNameResolver geo;
  final ReportFilters filters;
  final List<Region> regions;
  final List<Area> areas;
  final List<Polo> polos;
  final bool lockRegion;
  final bool lockArea;
  final bool lockPolo;
  final VoidCallback onChangePeriod;
  final VoidCallback? onClearFilters;
  const _PeopleList({
    required this.items,
    required this.geo,
    required this.filters,
    required this.regions,
    required this.areas,
    required this.polos,
    required this.lockRegion,
    required this.lockArea,
    required this.lockPolo,
    required this.onChangePeriod,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ReportsEmptyState(
        title: 'Nenhuma pessoa encontrada',
        onChangePeriod: onChangePeriod,
        onClearFilters: onClearFilters,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length + 1,
      separatorBuilder: (_, i) {
        if (i >= items.length - 1) return const SizedBox.shrink();
        return const Divider(height: 1, thickness: 1, color: AppTheme.neutralLight);
      },
      itemBuilder: (_, i) {
        if (i == items.length) {
          return ReportsListFooter(
            text: '${items.length} pessoa${items.length == 1 ? '' : 's'} encontrada${items.length == 1 ? '' : 's'}',
          );
        }
        return PersonReportTile(
          item: items[i],
          geo: geo,
          onTap: () {
            final reports = context.read<ReportsController>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => IndividualReportController(
                    initialSummary: items[i],
                    initialFilters: filters,
                    attendanceRepo: reports.attendanceRepo,
                    rehearsalRepo: reports.rehearsalRepo,
                    geoRepo: reports.geoRepo,
                    profile: reports.profile,
                    regions: regions,
                    areas: areas,
                    polos: polos,
                    lockRegion: lockRegion,
                    lockArea: lockArea,
                    lockPolo: lockPolo,
                  ),
                  child: const PersonReportDetailView(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

