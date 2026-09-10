import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class AdminUsersView extends StatelessWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AdminUsersController(
        profiles: ctx.read<IUserProfileRepository>(),
        requests: ctx.read<IAccessRequestRepository>(),
      )..load(),
      child: const _AdminUsersBody(),
    );
  }
}

class _AdminUsersBody extends StatefulWidget {
  const _AdminUsersBody();

  @override
  State<_AdminUsersBody> createState() => _AdminUsersBodyState();
}

class _AdminUsersBodyState extends State<_AdminUsersBody> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();
    return BlocBuilder<AdminUsersController, AdminUsersState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<AdminUsersController>().load(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        final visible = state.visible;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: context.read<AdminUsersController>().search,
                decoration: InputDecoration(
                  hintText: 'Pesquisar por nome, e-mail ou papel...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            context.read<AdminUsersController>().search('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum usuário encontrado.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context.read<AdminUsersController>().load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final u = visible[i];
                          final missing = state.isMissingProfile(u.uid);
                          return _UserTile(
                            user: u,
                            scope: missing
                                ? 'Aprovado, sem perfil'
                                : _scopeLine(u, geo),
                            missingProfile: missing,
                            onTap: () async {
                              final updated = await Navigator.push<UserProfile>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminUserEditView(
                                    user: u,
                                    missingProfile: missing,
                                  ),
                                ),
                              );
                              if (updated != null && context.mounted) {
                                context.read<AdminUsersController>().replace(updated);
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _scopeLine(UserProfile u, GeoNameResolver geo) {
    return switch (u.role) {
      UserRole.admin => 'Acesso total',
      UserRole.readonly => 'Somente leitura',
      UserRole.maanaim => geo.maanaimName(u.regionId) ?? geo.regionName(u.regionId) ?? u.regionId ?? '—',
      UserRole.region => geo.regionName(u.regionId) ?? u.regionId ?? '—',
      UserRole.area => geo.areaName(u.areaId) ?? u.areaId ?? '—',
      UserRole.polo => geo.poloName(u.poloId) ?? u.poloId ?? '—',
    };
  }
}

class _UserTile extends StatelessWidget {
  final UserProfile user;
  final String scope;
  final bool missingProfile;
  final VoidCallback onTap;
  const _UserTile({
    required this.user,
    required this.scope,
    required this.missingProfile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: .12),
                foregroundColor: AppTheme.primary,
                child: Text(_initials(user.displayName.isEmpty ? user.email : user.displayName)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isEmpty ? user.email : user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      missingProfile ? scope : '${user.role.label} • $scope',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (missingProfile
                          ? AppTheme.warning
                          : (user.active ? AppTheme.success : Colors.grey))
                      .withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  missingProfile
                      ? 'Sem perfil'
                      : (user.active ? 'Ativo' : 'Inativo'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: missingProfile
                        ? const Color(0xFFB7791F)
                        : (user.active ? AppTheme.success : Colors.grey.shade700),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
    if (parts.isEmpty) return '?';
    return parts.map((e) => e[0]).join().toUpperCase();
  }
}
