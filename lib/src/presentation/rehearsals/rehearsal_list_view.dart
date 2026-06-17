import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../src.dart';

class RehearsalListView extends StatefulWidget {
  final DateTime? initialDayFilter;
  const RehearsalListView({super.key, this.initialDayFilter});

  @override
  State<RehearsalListView> createState() => _RehearsalListViewState();
}

class _RehearsalListViewState extends State<RehearsalListView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('[RehearsalListView] initState()');
    if (widget.initialDayFilter != null) {
      context.read<RehearsalListController>().setDayFilter(widget.initialDayFilter);
    }
    context.read<RehearsalListController>().startWatch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          'Lista dos Ensaios',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              final showClosed = context.watch<RehearsalListController>().state.showClosed;
              if (showClosed) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final created = await Navigator.push<Rehearsal?>(
                    context,
                    MaterialPageRoute(builder: (_) => const RehearsalCreateView()),
                  );
                  if (created != null) {
                    context.read<RehearsalListController>().insert(created);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ensaio criado')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add),
                tooltip: 'Criar',
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<RehearsalListController, RehearsalListState>(
        builder: (context, state) {
          debugPrint('[RehearsalListView] build body: loading=${state.loading} items.length=${state.items.length} showClosed=${state.showClosed}');
          if (state.loading) return const Center(child: CircularProgressIndicator());

          final items = context.read<RehearsalListController>().filtered;
          final controller = context.read<RehearsalListController>();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => controller.search(v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Pesquisar por região, local ou descrição.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => controller.refresh(),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RehearsalTile(item: items[i]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final state = context.watch<RehearsalListController>().state;
          return FloatingActionButton(
            onPressed: () {
              final controller = context.read<RehearsalListController>();
              showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (ctx) => BlocProvider.value(
                  value: controller,
                  child: const SafeArea(child: _RehearsalFilterSheet()),
                ),
              );
            },
            tooltip: 'Filtros',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(state.showClosed ? Icons.lock_rounded : Icons.filter_list),
                if (state.levelFilter != null ||
                    (state.regionFilter ?? '').isNotEmpty ||
                    (state.areaFilter ?? '').isNotEmpty ||
                    (state.poloFilter ?? '').isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RehearsalFilterSheet extends StatefulWidget {
  const _RehearsalFilterSheet();

  @override
  State<_RehearsalFilterSheet> createState() => _RehearsalFilterSheetState();
}

class _RehearsalFilterSheetState extends State<_RehearsalFilterSheet> {
  bool _loading = true;
  List<Maanaim> _maanaims = const [];
  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final geo = context.read<IGeoRepository>();
    final profile = context.read<AuthController>().state.profile;

    // Admin: carrega todas as listas para permitir filtro global.
    // Outros perfis: apenas exibe o escopo atual (sem dropdowns de troca).
    if (profile?.role == UserRole.admin) {
      final maanaims = await geo.maanaims();
      final regions = await geo.regions();
      if (!mounted) return;
      setState(() {
        _maanaims = maanaims;
        _regions = regions;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
  }

  Future<void> _loadAreas(String regionId) async {
    final geo = context.read<IGeoRepository>();
    setState(() {
      _areas = const [];
      _polos = const [];
      _loading = true;
    });
    final areas = await geo.areasByRegion(regionId);
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _loading = false;
    });
  }

  Future<void> _loadPolos(String areaId) async {
    final geo = context.read<IGeoRepository>();
    setState(() {
      _polos = const [];
      _loading = true;
    });
    final polos = await geo.polosByArea(areaId);
    if (!mounted) return;
    setState(() {
      _polos = polos;
      _loading = false;
    });
  }

  List<DropdownMenuItem<String?>> _itemsWithAll(List<({String id, String name})> list) {
    // Garante que não existam ids duplicados (senão o Dropdown quebra com assert).
    final byId = <String, String>{};
    for (final e in list) {
      final id = e.id.trim();
      if (id.isEmpty) continue;
      byId[id] = e.name;
    }
    final unique = byId.entries
        .map((e) => (id: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [
      const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
      ...unique.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
    ];
  }

  String? _safeValue(String? value, List<({String id, String name})> list) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    final ids = list.map((e) => e.id.trim()).toSet();
    return ids.contains(v) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<RehearsalListController>();
    final geoNames = context.read<GeoNameResolver>();
    final profile = context.read<AuthController>().state.profile;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: BlocBuilder<RehearsalListController, RehearsalListState>(
        builder: (context, state) {
          final isAdmin = profile?.role == UserRole.admin;
          final role = profile?.role;

          List<RehearsalLevel> allowedLevels() {
            switch (role) {
              case UserRole.polo:
                return const [RehearsalLevel.polo];
              case UserRole.area:
                return const [RehearsalLevel.polo, RehearsalLevel.area];
              case UserRole.region:
                return const [RehearsalLevel.polo, RehearsalLevel.area, RehearsalLevel.region];
              case UserRole.maanaim:
                return const [
                  RehearsalLevel.polo,
                  RehearsalLevel.area,
                  RehearsalLevel.region,
                  RehearsalLevel.maanaim,
                ];
              case UserRole.readonly:
                if ((profile?.poloId ?? '').isNotEmpty) return const [RehearsalLevel.polo];
                if ((profile?.areaId ?? '').isNotEmpty) return const [RehearsalLevel.area];
                if ((profile?.regionId ?? '').isNotEmpty) return const [RehearsalLevel.region];
                return const [];
              default:
                return const [];
            }
          }

          final allowed = allowedLevels();

          void toggleLevel(RehearsalLevel l) {
            final next = {...state.levelsFilter};
            if (next.contains(l)) {
              next.remove(l);
            } else {
              next.add(l);
            }
            // Se selecionar tudo permitido, tratamos como "Todos" (set vazio).
            final all = allowed.toSet();
            if (next.isEmpty || next.containsAll(all) && all.containsAll(next)) {
              controller.setLevelsFilter(const {});
            } else {
              controller.setLevelsFilter(next);
            }
          }

          final hasAny =
              state.showClosed ||
              state.levelsFilter.isNotEmpty ||
              state.levelFilter != null ||
              (state.regionFilter ?? '').isNotEmpty ||
              (state.areaFilter ?? '').isNotEmpty ||
              (state.poloFilter ?? '').isNotEmpty;

          final effectiveLevel = state.levelFilter ?? (isAdmin ? null : switch (profile?.role) {
            UserRole.polo => RehearsalLevel.polo,
            UserRole.area => RehearsalLevel.area,
            UserRole.region => RehearsalLevel.region,
            UserRole.maanaim => RehearsalLevel.maanaim,
            UserRole.readonly => (profile?.poloId != null)
                ? RehearsalLevel.polo
                : (profile?.areaId != null)
                    ? RehearsalLevel.area
                    : RehearsalLevel.region,
            _ => null,
          });

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtros',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: hasAny ? controller.clearFilters : null,
                    child: const Text('Limpar'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.event_available, color: state.showClosed ? null : AppTheme.primary),
                      title: const Text('Próximos'),
                      trailing: state.showClosed ? null : const Icon(Icons.check),
                      onTap: () => controller.setShowClosed(false),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.lock_rounded, color: state.showClosed ? AppTheme.primary : null),
                      title: const Text('Encerrados'),
                      trailing: state.showClosed ? const Icon(Icons.check) : null,
                      onTap: () => controller.setShowClosed(true),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),

              // Admin: permite escolher nível + escopo. Outros: mostra "somente leitura" do escopo atual.
              if (isAdmin) ...[
                DropdownButtonFormField<RehearsalLevel?>(
                  value: effectiveLevel,
                  decoration: const InputDecoration(
                    labelText: 'Nível do ensaio',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<RehearsalLevel?>(value: null, child: Text('Todos')),
                    ...RehearsalLevel.values.map((l) => DropdownMenuItem(value: l, child: Text(geoNames.levelLabel(l)))),
                  ],
                  onChanged: (v) {
                    controller.setLevelFilter(v);
                    setState(() {
                      _areas = const [];
                      _polos = const [];
                    });
                  },
                ),
                const SizedBox(height: 10),

                if (effectiveLevel == RehearsalLevel.maanaim) ...[
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.regionFilter, _maanaims.map((m) => (id: m.id, name: m.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Maanaim',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_maanaims.map((m) => (id: m.id, name: m.name)).toList()),
                    onChanged: (v) => controller.setGeoFilters(regionId: v, areaId: null, poloId: null),
                  ),
                ] else if (effectiveLevel == RehearsalLevel.region) ...[
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.regionFilter, _regions.map((r) => (id: r.id, name: r.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Região',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_regions.map((r) => (id: r.id, name: r.name)).toList()),
                    onChanged: (v) => controller.setGeoFilters(regionId: v, areaId: null, poloId: null),
                  ),
                ] else if (effectiveLevel == RehearsalLevel.area) ...[
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.regionFilter, _regions.map((r) => (id: r.id, name: r.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Região',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_regions.map((r) => (id: r.id, name: r.name)).toList()),
                    onChanged: (v) async {
                      controller.setGeoFilters(regionId: v, areaId: null, poloId: null);
                      if (v != null) await _loadAreas(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.areaFilter, _areas.map((a) => (id: a.id, name: a.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Área',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_areas.map((a) => (id: a.id, name: a.name)).toList()),
                    onChanged: (v) => controller.setGeoFilters(
                      regionId: state.regionFilter,
                      areaId: v,
                      poloId: null,
                    ),
                  ),
                ] else if (effectiveLevel == RehearsalLevel.polo) ...[
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.regionFilter, _regions.map((r) => (id: r.id, name: r.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Região',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_regions.map((r) => (id: r.id, name: r.name)).toList()),
                    onChanged: (v) async {
                      controller.setGeoFilters(regionId: v, areaId: null, poloId: null);
                      if (v != null) await _loadAreas(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.areaFilter, _areas.map((a) => (id: a.id, name: a.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Área',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_areas.map((a) => (id: a.id, name: a.name)).toList()),
                    onChanged: (v) async {
                      controller.setGeoFilters(regionId: state.regionFilter, areaId: v, poloId: null);
                      if (v != null) await _loadPolos(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _safeValue(state.poloFilter, _polos.map((p) => (id: p.id, name: p.name)).toList()),
                    decoration: const InputDecoration(
                      labelText: 'Polo',
                      border: OutlineInputBorder(),
                    ),
                    items: _itemsWithAll(_polos.map((p) => (id: p.id, name: p.name)).toList()),
                    onChanged: (v) => controller.setGeoFilters(
                      regionId: state.regionFilter,
                      areaId: state.areaFilter,
                      poloId: v,
                    ),
                  ),
                ],
              ] else ...[
                if (allowed.length > 1) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Níveis', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Todos'),
                              selected: state.levelsFilter.isEmpty,
                              onSelected: (_) => controller.setLevelsFilter(const {}),
                              backgroundColor: const Color(0xFFF1F5F9),
                              selectedColor: AppTheme.primary.withValues(alpha: .18),
                              checkmarkColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: state.levelsFilter.isEmpty ? AppTheme.primary : Colors.black87,
                              ),
                            ),
                            ...allowed.map((l) {
                              // Quando "Todos" está ativo (levelsFilter vazio), mostramos os chips individuais como DESMARCADOS
                              // para ficar visualmente claro.
                              final selected = state.levelsFilter.contains(l);
                              return FilterChip(
                                label: Text(geoNames.levelLabel(l)),
                                selected: selected,
                                onSelected: (_) => toggleLevel(l),
                                backgroundColor: const Color(0xFFF1F5F9),
                                selectedColor: AppTheme.primary.withValues(alpha: .18),
                                checkmarkColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? AppTheme.primary : Colors.black87,
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Não-admin: exibe escopo atual do perfil (para ficar "profissional" e claro).
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seu escopo', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        switch (profile?.role) {
                          UserRole.maanaim => 'Maanaim: ${geoNames.maanaimName(profile?.regionId) ?? geoNames.regionName(profile?.regionId) ?? (profile?.regionId ?? '')}',
                          UserRole.region => 'Região: ${geoNames.regionName(profile?.regionId) ?? (profile?.regionId ?? '')}',
                          UserRole.area => 'Área: ${geoNames.areaName(profile?.areaId) ?? (profile?.areaId ?? '')}',
                          UserRole.polo => 'Polo: ${geoNames.poloName(profile?.poloId) ?? (profile?.poloId ?? '')}',
                          UserRole.readonly => 'Somente leitura (escopo configurado no acesso)',
                          _ => '',
                        },
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }
}

class _RehearsalTile extends StatelessWidget {
  final Rehearsal item;
  const _RehearsalTile({required this.item});

  @override
  Widget build(BuildContext context) {

    final geo = context.read<GeoNameResolver>();

    final closed = item.closed == true; // ← campo boolean do Rehearsal

    final colorBadge = switch (item.level) {
      RehearsalLevel.polo     => AppTheme.primary,
      RehearsalLevel.area     => AppTheme.accentPurple,
      RehearsalLevel.region   => AppTheme.success,
      RehearsalLevel.maanaim  => AppTheme.accentOrange,
    };

    final badgeColor = closed ? Colors.grey : colorBadge;

    return InkWell(
      onTap: () => _openAttendance(context, item.id),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
            ),
            child: Row(children: [
              _DateBadge(date: item.dateTime, color: badgeColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    //'${_levelLabel(item.level)} • ${item.regionId}',
                     geo.levelName(item),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_fmtHour(item.dateTime)}  •  ${item.place ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((item.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                  ],
                ]),
              ),
              if (!closed)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final updated = await Navigator.push<Rehearsal?>(
                        context,
                        MaterialPageRoute(builder: (_) => RehearsalCreateView(existing: item)),
                      );
                      if (updated != null && context.mounted) {
                        context.read<RehearsalListController>().replace(updated); // veja abaixo
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ensaio atualizado')),
                        );
                      }
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Excluir ensaio'),
                          content: const Text('Tem certeza que deseja excluir este ensaio? Essa ação não pode ser desfeita.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                          ],
                        ),
                      ) ?? false;

                      if (ok) {
                        final repo = context.read<IRehearsalRepository>();
                        await repo.delete(item.id);
                        if (context.mounted) {
                          context.read<RehearsalListController>().remove(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ensaio excluído')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Editar'))),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded), title: Text('Excluir'))),
                  ],
                ),
            ]),
          ),
          // Chip “Encerrado” no topo direito
          if (closed)
            Positioned(
              right: 22,
              top: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.successSoftBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.successSoftBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: const [
                    Icon(Icons.lock_rounded, size: 14, color: Colors.green), // azul médio
                    SizedBox(width: 6),
                    Text(
                      'Encerrado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green, // azul mais vivo
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  void _openAttendance(BuildContext context, String rehearsalId) {
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

  static String _fmtHour(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final Color color;
  const _DateBadge({required this.date, required this.color});

  String mesAbreviado(DateTime date) {
    const meses = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    return meses[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final day = date.day.toString().padLeft(2, '0');
    final month = mesAbreviado(date);

    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Column(
        children: [
          Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(month, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
