import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src.dart';
import '../admin/access_requests_view.dart';
import '../profile/profile.dart';
import '../rehearsals/rehearsal_list_view.dart' as rehe;
import '../people/people_list_view.dart' as ppl;

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _hasToday = false;
  int _monthCount = 0;
  int _todayCount = 0;
  String? _lastCsv;
  String? _lastPdf;
  List<DateTime> _daysWithRehearsal = const [];

  @override
  void initState() {
    super.initState();
    _loadResolver();
    _loadExportHistory();
    // NÃO chamamos _refreshBadgesAndStats aqui.
  }

  // garante um refresh quando a tela volta com perfil já disponível
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = context.read<AuthController>().state.profile;
      if (!mounted || profile == null) return;
      // dá um "respiro" para o _ScopeBinder fazer repo.setScope(profile)
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (mounted) _refreshBadgesAndStats();
    });
  }

  Future<void> _loadResolver() async {
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) await resolver.preloadAll();
  }

  Future<void> _loadExportHistory() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastCsv = sp.getString('last_export_csv');
      _lastPdf = sp.getString('last_export_pdf');
    });
  }

  Future<void> _refreshBadgesAndStats() async {
    final repo = context.read<IRehearsalRepository>();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    // Consultas já respeitam escopo no repositório.
    final todays = await repo.listBetween(todayStart, todayEnd);
    final monthly = await repo.listBetween(monthStart, monthEnd);

    // próximos 30 dias para o calendário (inclusive o 30º dia)
    final horizonStart = todayStart;
    final horizonEnd = todayStart
        .add(const Duration(days: 30))
        .subtract(const Duration(milliseconds: 1));
    final next30 = await repo.listBetween(horizonStart, horizonEnd);

    if (!mounted) return;
    setState(() {
      _hasToday = todays.any((r) => !r.closed);
      _todayCount = todays.length;
      _monthCount = monthly.length;
      _daysWithRehearsal = next30
          .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
          .toSet()
          .toList()
        ..sort((a, b) => a.compareTo(b));
    });
  }

  // Helpers de “histórico de export”
  Future<void> _markCsvExportedNow() async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await sp.setString('last_export_csv', _fmtDateTime(now));
    if (mounted) setState(() => _lastCsv = _fmtDateTime(now));
  }

  Future<void> _markPdfExportedNow() async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await sp.setString('last_export_pdf', _fmtDateTime(now));
    if (mounted) setState(() => _lastPdf = _fmtDateTime(now));
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} ${_fmtTime(d)}';

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthController>().state;
    final isAdmin = authState.profile?.role == UserRole.admin;

    final quickActions = isAdmin
        ? StreamBuilder<int>(
      stream: context.read<IAccessRequestRepository>().watchPendingCount(),
      initialData: 0,
      builder: (context, snap) {
        final pending = snap.data ?? 0;
        return _QuickActionsGrid(
          hasToday: _hasToday,
          isAdmin: true,
          pendingRequests: pending,
        );
      },
    )
        : _QuickActionsGrid(hasToday: _hasToday);

    return BlocListener<AuthController, AuthState>(
      listenWhen: (p, c) => p.profile != c.profile || p.isSignedOut != c.isSignedOut,
      listener: (context, state) async {
        if (state.profile != null && !state.isSignedOut) {
          // espera o _ScopeBinder aplicar o setScope(profile)
          await Future<void>.delayed(const Duration(milliseconds: 60));
          if (mounted) await _refreshBadgesAndStats();
        } else if (mounted) {
          setState(() {
            _hasToday = false;
            _todayCount = 0;
            _monthCount = 0;
            _daysWithRehearsal = const [];
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          title: const Text(
            'Ensaios ICM',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: const [_AccountButton()],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshBadgesAndStats,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              const _SectionTitle('Atalhos'),
              const SizedBox(height: 12),
              quickActions,

              const _SectionTitle('Calendário'),
              const SizedBox(height: 12),
              _CalendarStrip(
                daysWithRehearsal: _daysWithRehearsal,
                onTapDay: (day) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) {
                    final repo = context.read<IRehearsalRepository>();
                    return BlocProvider(
                      create: (_) => RehearsalListController(repo),
                      child: rehe.RehearsalListView(initialDayFilter: day),
                    );
                  }));
                },
              ),
              const SizedBox(height: 24),

              const _SectionTitle('Próximos Ensaios'),
              const SizedBox(height: 12),
              _NextRehearsalCard(
                onOpenList: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) {
                    final repo = context.read<IRehearsalRepository>();
                    return BlocProvider(
                      create: (_) => RehearsalListController(repo),
                      child: const rehe.RehearsalListView(),
                    );
                  }));
                },
                onOpenAttendance: (rehearsalId) {
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
                      child: AttendanceView(
                        rehearsalId: rehearsalId,
                        currentUserId: currentUserId,
                      ),
                    );
                  }));
                },
              ),

              const SizedBox(height: 24),
              const _SectionTitle('Resumo rápido'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Ensaios\n no mês',
                      value: '$_monthCount',
                      icon: Icons.event_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Hoje',
                      value: '$_todayCount',
                      icon: Icons.today_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== Widgets ======================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final bool hasToday;
  final bool isAdmin;
  final int pendingRequests;

  const _QuickActionsGrid({
    required this.hasToday,
    this.isAdmin = false,
    this.pendingRequests = 0,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_QuickActionItem>[
      _QuickActionItem(
        label: 'Ensaios',
        icon: Icons.event_note_rounded,
        color: AppTheme.accentPurple,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) {
            final repo = context.read<IRehearsalRepository>();
            return BlocProvider(
              create: (_) => RehearsalListController(repo),
              child: const rehe.RehearsalListView(),
            );
          }));
        },
        badge: hasToday ? 'Hoje' : null,
      ),
      _QuickActionItem(
        label: 'Membros',
        icon: Icons.people_alt_rounded,
        color: AppTheme.success,
        onTap: () {
          final repo = context.read<IPersonRepository>();
          final geo = context.read<IGeoRepository>();
          Navigator.push(context, MaterialPageRoute(builder: (_) {
            return BlocProvider(
              create: (ctx) => PeopleListController(repo, geo),
              child: const ppl.PeopleListView(),
            );
          }));
        },
      ),
      _QuickActionItem(
        label: 'Relatórios',
        icon: Icons.pie_chart_rounded,
        color: AppTheme.accentOrange,
        onTap: () {
          final attendanceRepo = context.read<IAttendanceRepository>();
          final rehearsalRepo = context.read<IRehearsalRepository>();
          final personRepo = context.read<IPersonRepository>();
          final geo = context.read<GeoNameResolver>();
          final geoRepo = context.read<IGeoRepository>();
          final profile = context.read<AuthController>().state.profile;
          Navigator.push(context, MaterialPageRoute(builder: (_) {
            return BlocProvider(
              create: (_) => ReportsController(
                attendanceRepo: attendanceRepo,
                rehearsalRepo: rehearsalRepo,
                personRepo: personRepo,
                geoRepo: geoRepo,
                geo: geo,
                profile: profile,
              ),
              child: const ReportsView(),
            );
          }));
        },
      ),
    ];

    if (isAdmin) {
      items.add(
        _QuickActionItem(
          label: 'Solicitações',
          icon: Icons.verified_user_outlined,
          color: AppTheme.accentTeal,
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AccessRequestsView()));
          },
          badge: pendingRequests > 0 ? pendingRequests.toString() : null,
        ),
      );
    }

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 110,
      ),
      itemBuilder: (_, i) => _QuickActionCard(item: items[i]),
    );
  }
}

class _QuickActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  _QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 16, color: AppTheme.cardShadow)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (item.badge != null)
            Positioned(
              right: 10,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  border: Border.all(color: AppTheme.success),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard(
      {required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 16, color: AppTheme.cardShadow)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final List<DateTime> daysWithRehearsal; // datas normalizadas (00:00)
  final void Function(DateTime day) onTapDay;
  const _CalendarStrip({required this.daysWithRehearsal, required this.onTapDay});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final days = List.generate(14, (i) => start.add(Duration(days: i)));

    bool hasMarker(DateTime d) =>
        daysWithRehearsal.any((x) => x.year == d.year && x.month == d.month && x.day == d.day);

    String mon(DateTime d) {
      const m = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
      return m[d.month - 1];
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final d = days[i];
          final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
          final marker = hasMarker(d);

          final bg = isToday
              ? AppTheme.primary.withOpacity(.08)
              : (marker ? AppTheme.successBg : Colors.white);
          final border = isToday ? AppTheme.primary : (marker ? AppTheme.success : Colors.black12);
          final textColor = isToday ? AppTheme.primary : Colors.black87;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTapDay(d),
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1.2),
                boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadowLight)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    d.day.toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(mon(d), style: TextStyle(fontSize: 12, color: textColor)),
                  const SizedBox(height: 6),
                  if (marker)
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============== Próximo Ensaio (mesma lógica, com UI do app) ==============

class _NextRehearsalCard extends StatelessWidget {
  final VoidCallback onOpenList;
  final void Function(String rehearsalId) onOpenAttendance;

  const _NextRehearsalCard({
    required this.onOpenList,
    required this.onOpenAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IRehearsalRepository>();

    return FutureBuilder<Rehearsal?>(
      future: repo.nextUpcoming(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) return _ErrorRehearsalCard(onOpenList: onOpenList);

        final r = snap.data;
        if (r == null) return _EmptyRehearsalCard(onOpenList: onOpenList);

        final resolver = context.read<GeoNameResolver>();
        final d = r.dateTime;
        final hour = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        final level = resolver.levelLabel(r.level);
        final location = resolver.locationLabel(r);

        return InkWell(
          onTap: () => onOpenAttendance(r.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(blurRadius: 16, color: AppTheme.cardShadow)],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Próximo ensaio • $level', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${_dateLabel(d)} • $hour', maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(location, style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        );
      },
    );
  }

  static String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Hoje';
    if (date == today.add(const Duration(days: 1))) return 'Amanhã';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

class _EmptyRehearsalCard extends StatelessWidget {
  final VoidCallback onOpenList;
  const _EmptyRehearsalCard({required this.onOpenList});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenList,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: const [
          _Leading(color: Colors.grey, icon: Icons.event_busy_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nenhum ensaio agendado', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Toque para ver/criar ensaios', maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _ErrorRehearsalCard extends StatelessWidget {
  final VoidCallback onOpenList;
  const _ErrorRehearsalCard({required this.onOpenList});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenList,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: const [
          _Leading(color: Colors.orange, icon: Icons.error_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Falha ao carregar', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Toque para abrir a lista de ensaios', maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Leading({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}

enum _AccountAction { profile, signOut }

class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthController, AuthState>(
      buildWhen: (p, c) => p.profile != c.profile,
      builder: (context, state) {
        final name = state.profile?.displayName.trim() ?? '';
        final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';

        return PopupMenuButton<_AccountAction>(
          tooltip: 'Conta',
          onSelected: (action) {
            switch (action) {
              case _AccountAction.profile:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileView()),
                );
                break;
              case _AccountAction.signOut:
                context.read<AuthController>().signOut();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _AccountAction.profile,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline),
                title: Text('Meu perfil'),
              ),
            ),
            PopupMenuItem(
              value: _AccountAction.signOut,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout),
                title: Text('Sair'),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                letter,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
