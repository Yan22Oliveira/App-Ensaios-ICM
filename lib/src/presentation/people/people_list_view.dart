import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class PeopleListView extends StatefulWidget {
  const PeopleListView({super.key});

  @override
  State<PeopleListView> createState() => _PeopleListViewState();
}

class _PeopleListViewState extends State<PeopleListView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthController>().state.profile;
    context.read<PeopleListController>().load(profile);
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) resolver.preloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          'Membros',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _createNew,
            tooltip: 'New Person',
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: BlocBuilder<PeopleListController, PeopleListState>(
        builder: (context, state) {
          final items = context.read<PeopleListController>().filtered;
          if (state.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              final profile = context.read<AuthController>().state.profile;
              await context.read<PeopleListController>().load(profile);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (kDebugMode && state.debugLines.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _DebugLogPanel(
                      lines: state.debugLines,
                      filteredCount: items.length,
                      totalCount: state.items.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => context.read<PeopleListController>().search(v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Pesquisar por nome, região, e-mail ou telefone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.zero,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PersonTile(
                          p: items[i],
                          profile: state.profile,
                          expandScope: state.expandScopeFilter,
                        ),
                      ),
                      childCount: items.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final state = context.watch<PeopleListController>().state;
          return _FilterFab(
            profile: state.profile,
            expandScope: state.expandScopeFilter,
            regionFilter: state.regionFilter,
            areaFilter: state.areaFilter,
            poloFilter: state.poloFilter,
          );
        },
      ),
    );
  }

  Future<void> _createNew() async {
    final created = await Navigator.push<Person?>(
      context,
      MaterialPageRoute(builder: (_) => const PersonCreateView()),
    );

    if (!mounted || created == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Membro criado')),
    );
  }
}

class _DebugLogPanel extends StatefulWidget {
  final List<String> lines;
  final int filteredCount;
  final int totalCount;

  const _DebugLogPanel({
    required this.lines,
    required this.filteredCount,
    required this.totalCount,
  });

  @override
  State<_DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<_DebugLogPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'DEBUG: listagem pessoas | total=${widget.totalCount} exibidos=${widget.filteredCount}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SelectableText(
                widget.lines.join('\n'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }
}

/// FAB que abre o bottom sheet de filtros (escopo por perfil).
class _FilterFab extends StatelessWidget {
  final UserProfile? profile;
  final bool expandScope;
  final String? regionFilter;
  final String? areaFilter;
  final String? poloFilter;

  const _FilterFab({
    this.profile,
    this.expandScope = false,
    this.regionFilter,
    this.areaFilter,
    this.poloFilter,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _openFilterSheet(context),
      tooltip: 'Filtros',
      child: const Icon(Icons.filter_list_rounded),
    );
  }

  void _openFilterSheet(BuildContext context) {
    final controller = context.read<PeopleListController>();
    final geoRepo = context.read<IGeoRepository>();
    final geo = context.read<GeoNameResolver>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _FilterSheetContent(
          controller: controller,
          profile: profile,
          expandScope: expandScope,
          regionFilter: regionFilter,
          areaFilter: areaFilter,
          poloFilter: poloFilter,
          geoRepo: geoRepo,
          geo: geo,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Conteúdo do bottom sheet: dropdowns (região/área/polo) + switch "Incluir níveis abaixo".
class _FilterSheetContent extends StatefulWidget {
  final PeopleListController controller;
  final UserProfile? profile;
  final bool expandScope;
  final String? regionFilter;
  final String? areaFilter;
  final String? poloFilter;
  final IGeoRepository geoRepo;
  final GeoNameResolver geo;
  final ScrollController scrollController;

  const _FilterSheetContent({
    required this.controller,
    this.profile,
    required this.expandScope,
    this.regionFilter,
    this.areaFilter,
    this.poloFilter,
    required this.geoRepo,
    required this.geo,
    required this.scrollController,
  });

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  List<Region> _regions = [];
  List<Area> _areas = [];
  List<Polo> _polos = [];
  bool _loading = true;
  bool _loadingAreas = false;
  bool _loadingPolos = false;

  @override
  void initState() {
    super.initState();
    _loadGeo();
  }

  Future<void> _loadGeo() async {
    final p = widget.profile;
    if (p == null) {
      setState(() { _loading = false; });
      return;
    }
    List<Region> regions = [];
    List<Area> areas = [];
    List<Polo> polos = [];

    final state = widget.controller.state;
    final selectedRegion = state.regionFilter;
    final selectedArea = state.areaFilter;

    if (p.role == UserRole.maanaim && (p.regionId ?? '').isNotEmpty) {
      // Carrega só regiões do Maanaim. Áreas/Polos são carregados sob demanda (cascata).
      regions = await widget.geoRepo.regionsByMaanaim(p.regionId!);
      if (selectedRegion != null && selectedRegion.isNotEmpty) {
        areas = await widget.geoRepo.areasByRegion(selectedRegion);
        if (selectedArea != null && selectedArea.isNotEmpty) {
          polos = await widget.geoRepo.polosByArea(selectedArea);
        }
      }
    } else if (p.role == UserRole.region && (p.regionId ?? '').isNotEmpty) {
      // Região fixa; carrega áreas. Polos carregados sob demanda ao escolher a área.
      regions = [Region(id: p.regionId!, name: widget.geo.regionName(p.regionId!) ?? p.regionId!)];
      areas = await widget.geoRepo.areasByRegion(p.regionId!);
      if (selectedArea != null && selectedArea.isNotEmpty) {
        polos = await widget.geoRepo.polosByArea(selectedArea);
      }
    } else if (p.role == UserRole.area && (p.areaId ?? '').isNotEmpty) {
      // Área fixa; carrega polos da área.
      final allAreas = await widget.geoRepo.areasByRegion(p.regionId ?? '');
      areas = allAreas.where((a) => a.id == p.areaId).toList();
      polos = await widget.geoRepo.polosByArea(p.areaId!);
    }

    if (mounted) {
      setState(() {
        if (_regions.isEmpty) _regions = regions;
        _areas = areas;
        _polos = polos;
        _loading = false;
      });
    }
  }

  Future<void> _onRegionChanged(String? regionId, PeopleListState state) async {
    widget.controller.setGeoFilters(regionId: regionId, areaId: null, poloId: null);
    if (!mounted) return;
    setState(() {
      _areas = [];
      _polos = [];
      _loadingAreas = regionId != null && regionId.isNotEmpty;
      _loadingPolos = false;
    });
    if (regionId == null || regionId.isEmpty) {
      setState(() => _loadingAreas = false);
      return;
    }
    final areas = await widget.geoRepo.areasByRegion(regionId);
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _loadingAreas = false;
    });
  }

  Future<void> _onAreaChanged(String? areaId, PeopleListState state) async {
    widget.controller.setGeoFilters(regionId: state.regionFilter, areaId: areaId, poloId: null);
    if (!mounted) return;
    setState(() {
      _polos = [];
      _loadingPolos = areaId != null && areaId.isNotEmpty;
    });
    if (areaId == null || areaId.isEmpty) {
      setState(() => _loadingPolos = false);
      return;
    }
    final polos = await widget.geoRepo.polosByArea(areaId);
    if (!mounted) return;
    setState(() {
      _polos = polos;
      _loadingPolos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return BlocBuilder<PeopleListController, PeopleListState>(
      bloc: widget.controller,
      builder: (context, state) {
        void clearFilters() {
          widget.controller.setGeoFilters(regionId: null, areaId: null, poloId: null);
          widget.controller.setExpandScopeFilter(false, p);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView(
              controller: widget.scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: (p == null || p.role == UserRole.polo) ? null : clearFilters,
                      child: const Text('Limpar'),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (p == null || p.role == UserRole.admin || p.role == UserRole.readonly)
                  _InfoCard(
                    icon: Icons.people_rounded,
                    title: 'Todos os membros',
                    subtitle: 'Admin / leitura: sem filtro de escopo',
                  )
                else if (p.role == UserRole.polo)
                  _InfoCard(
                    icon: Icons.location_on_rounded,
                    title: 'Meu polo',
                    subtitle: 'Sem filtros adicionais',
                  )
                else if (_loading)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else ...[
                  const SizedBox(height: 4),
                  _sectionLabel('LOCALIZAÇÃO'),
                  if (p.role == UserRole.maanaim) ...[
                    _padField(_dropdownRegiao(state)),
                    if (_loadingAreas)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    _padField(_dropdownArea(state)),
                    if (_loadingPolos)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    _padField(_dropdownPolo(state)),
                  ] else if (p.role == UserRole.region) ...[
                    _padField(_dropdownArea(state)),
                    if (_loadingPolos)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    _padField(_dropdownPolo(state)),
                  ] else if (p.role == UserRole.area) ...[
                    _padField(_dropdownPolo(state)),
                  ],
                  const SizedBox(height: 4),
                  _sectionLabel('ESCOPO'),
                  SwitchListTile.adaptive(
                    value: state.expandScopeFilter,
                    onChanged: (v) => widget.controller.setExpandScopeFilter(v, p),
                    title: const Text('Incluir níveis abaixo'),
                    subtitle: const Text('Mostra também os níveis inferiores do seu escopo'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _padField(Widget child) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: child,
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4, bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: Colors.grey.shade700,
      ),
    ),
  );

  Widget _dropdownRegiao(PeopleListState state) {
    final value = state.regionFilter;
    return DropdownButtonFormField<String?>(
      value: _regions.any((r) => r.id == value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'Região',
        filled: true,
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ..._regions.map((r) => DropdownMenuItem(value: r.id, child: Text(widget.geo.regionName(r.id) ?? r.id))),
      ],
      onChanged: (v) => _onRegionChanged(v, state),
    );
  }

  Widget _dropdownArea(PeopleListState state) {
    final p = widget.profile;
    final requiresRegion = p != null && p.role == UserRole.maanaim;
    final hasRegionSelected = (state.regionFilter ?? '').isNotEmpty;
    final enabled = !requiresRegion || hasRegionSelected;

    return DropdownButtonFormField<String?>(
      value: _areas.any((a) => a.id == state.areaFilter) ? state.areaFilter : null,
      decoration: const InputDecoration(
        labelText: 'Área',
        filled: true,
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ..._areas.map((a) => DropdownMenuItem(value: a.id, child: Text(widget.geo.areaName(a.id) ?? a.id))),
      ],
      onChanged: enabled ? (v) => _onAreaChanged(v, state) : null,
      hint: enabled
          ? null
          : const Text('Selecione uma região'),
    );
  }

  Widget _dropdownPolo(PeopleListState state) {
    final p = widget.profile;
    final requiresArea = p != null && (p.role == UserRole.maanaim || p.role == UserRole.region);
    final hasAreaSelected = (state.areaFilter ?? '').isNotEmpty;
    final enabled = !requiresArea || hasAreaSelected;

    return DropdownButtonFormField<String?>(
      value: _polos.any((p) => p.id == state.poloFilter) ? state.poloFilter : null,
      decoration: const InputDecoration(
        labelText: 'Polo',
        filled: true,
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ..._polos.map((p) => DropdownMenuItem(value: p.id, child: Text(widget.geo.poloName(p.id) ?? p.id))),
      ],
      onChanged: enabled
          ? (v) => widget.controller.setGeoFilters(regionId: state.regionFilter, areaId: state.areaFilter, poloId: v)
          : null,
      hint: enabled
          ? null
          : const Text('Selecione uma área'),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person p;
  final UserProfile? profile;
  final bool expandScope;

  const _PersonTile({
    required this.p,
    required this.profile,
    required this.expandScope,
  });

  bool get _isBelowPrimaryLevel {
    // Só faz sentido marcar quando o usuário explicitamente incluiu níveis abaixo.
    if (!expandScope) return false;
    final role = profile?.role;
    if (role == null) return false;
    // Polo não tem "níveis abaixo".
    if (role == UserRole.polo) return false;

    // "Principal" por perfil:
    // - Maanaim: principal = Maanaim; abaixo = Região/Área/Polo
    // - Região: principal = Região (+Maanaim entra como "acima"); abaixo = Área/Polo
    // - Área: principal = Área (+Região/Maanaim entram como "acima"); abaixo = Polo
    return switch (role) {
      UserRole.maanaim => p.worshipLevel != RehearsalLevel.maanaim,
      UserRole.region => p.worshipLevel == RehearsalLevel.area || p.worshipLevel == RehearsalLevel.polo,
      UserRole.area => p.worshipLevel == RehearsalLevel.polo,
      _ => false,
    };
  }

  Color get _indicatorColor {
    // Cor baseada no nível do item (ajuda a identificar rapidamente o que é Polo/Área/Região).
    return switch (p.worshipLevel) {
      RehearsalLevel.polo => AppTheme.primary,
      RehearsalLevel.area => AppTheme.accentPurple,
      RehearsalLevel.region => AppTheme.success,
      RehearsalLevel.maanaim => AppTheme.accentOrange,
    };
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();
    final location = geo.personLocationLine(p);
    final displayName = _abbreviateBrazilianName(p.fullName);

    return InkWell(
      onTap: () async {
        // 👉 Aguarda a tela de detalhes (que pode editar e dar pop com o Person atualizado)
        final updated = await Navigator.push<Person?>(
          context,
          MaterialPageRoute(builder: (_) => PersonView(person: p)),
        );

        if (updated != null && context.mounted) {
          final controller = context.read<PeopleListController>();
          if (!updated.active) {
            controller.removeOne(updated.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${updated.fullName} foi desativado')),
            );
          } else {
            controller.replaceOne(updated);
          }
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Conteúdo do card (não muda espaçamento quando a faixa aparece)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(child: Text(_initials(p.fullName))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 1),
                          if (p.roles.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.roles.where((e) => e.trim().isNotEmpty).join(' • '),
                              style: const TextStyle(color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                  ],
                ),
              ),

              // Faixa vertical (overlay) pega a altura inteira do card
              if (_isBelowPrimaryLevel)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: _indicatorColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const Set<String> _prepositions = {
    'de', 'da', 'do', 'das', 'dos', 'e',
  };

  static String _abbreviateBrazilianName(String fullName) {
    final raw = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return raw;

    final parts = raw.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length <= 2) return raw;

    String normalize(String w) => w.trim();

    final first = normalize(parts.first);
    final last = normalize(parts.last);

    final middle = parts.sublist(1, parts.length - 1).map((w) {
      final word = normalize(w);
      final lower = word.toLowerCase();
      if (_prepositions.contains(lower)) return word; // não abrevia preposições
      final firstChar = word.characters.first;
      return '$firstChar.';
    }).toList();

    // Remove duplicação de espaços resultantes (ex.: preposições seguidas)
    return ([first, ...middle, last].join(' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((e) => e[0])
      .join()
      .toUpperCase();
}


