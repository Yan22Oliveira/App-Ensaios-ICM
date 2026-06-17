import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/br_phone_formatter.dart';
import '../../src.dart'
    show IUserProfileRepository, IAuthRepository, UserProfile, UserRole, GeoNameResolver;
import 'profile_controller.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:
      case UserRole.polo:
        return AppTheme.primary;
      case UserRole.area:
        return AppTheme.accentPurple;
      case UserRole.region:
        return AppTheme.success;
      case UserRole.maanaim:
        return AppTheme.accentOrange;
      case UserRole.readonly:
        return Colors.grey;
    }
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.maanaim:
        return 'MAANAIM';
      case UserRole.region:
        return 'REGIÃO';
      case UserRole.area:
        return 'ÁREA';
      case UserRole.polo:
        return 'POLO';
      case UserRole.readonly:
        return 'READONLY';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileController(
        profiles: context.read<IUserProfileRepository>(),
        auth: context.read<IAuthRepository>(),
      ),
      child: BlocConsumer<ProfileController, ProfileState>(
        listenWhen: (p, c) =>
        p.working != c.working || p.errorMessage != c.errorMessage,
        listener: (context, state) {
          if (state.working) return;
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          } else if (!_editing) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Perfil atualizado')),
            );
          }
        },
        builder: (context, state) {
          final loading = state.loading;
          final working = state.working;
          final profile = state.profile;

          if (loading || profile == null) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppTheme.primary,
                title: const Text('Perfil',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Preenche campos quando entra em edição
          if (_editing && _nameCtrl.text.isEmpty) {
            _nameCtrl.text = profile.displayName;
            _phoneCtrl.text = profile.phone ?? '';
          }

          final roleColor = _roleColor(profile.role);
          final geo = context.read<GeoNameResolver>();
          final regionName =
          profile.regionId != null ? geo.regionName(profile.regionId!) : null;
          final areaName =
          profile.areaId != null ? geo.areaName(profile.areaId!) : null;
          final poloName =
          profile.poloId != null ? geo.poloName(profile.poloId!) : null;

          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              title:
              const Text('Perfil', style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                  tooltip: _editing ? 'Cancelar edição' : 'Editar',
                  icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
                  onPressed: working
                      ? null
                      : () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _editing = !_editing;
                      if (_editing) {
                        _nameCtrl.text = profile.displayName;
                        _phoneCtrl.text = profile.phone ?? '';
                      } else {
                        FocusScope.of(context).unfocus();
                        _nameCtrl.clear();
                        _phoneCtrl.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            body: ListView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              children: [
                // HEADER
                _Card(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: _Avatar(profile: profile, color: roleColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () => _copy(profile.email, 'E-mail copiado'),
                              onLongPress: () =>
                                  _copy(profile.email, 'E-mail copiado'),
                              child: Text(
                                profile.email,
                                style: const TextStyle(
                                    color: Colors.black54,
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _PillChip(label: _roleLabel(profile.role), color: roleColor),
                                _PillChip(
                                  label: profile.active ? 'ATIVO' : 'INATIVO',
                                  color: profile.active
                                      ? AppTheme.successAlt
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ESCOPO — chips com ícone + tooltip; só aparecem se houver valor
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitleRow(
                        icon: Icons.map_outlined,
                        title: 'Escopo',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (regionName != null)
                            _ScopeChip(
                              label: 'Região',
                              value: regionName,
                              color: AppTheme.success,
                              icon: Icons.public,
                            ),
                          if (areaName != null)
                            _ScopeChip(
                              label: 'Área',
                              value: areaName,
                              color: AppTheme.accentPurple,
                              icon: Icons.map_rounded,
                            ),
                          if (poloName != null)
                            _ScopeChip(
                              label: 'Polo',
                              value: poloName,
                              color: AppTheme.primary,
                              icon: Icons.place_rounded,
                            ),
                          if (regionName == null &&
                              areaName == null &&
                              poloName == null)
                            const Text('— Sem escopo definido —',
                                style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // DADOS BÁSICOS
                _Card(
                  child: _editing
                      ? Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe seu nome'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [BrPhoneFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            hintText: '(99) 99999-9999',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  )
                      : Column(
                    children: [
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        title: 'Nome',
                        subtitle: profile.displayName,
                        onTap: () =>
                            _copy(profile.displayName, 'Nome copiado'),
                      ),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        title: 'Telefone',
                        subtitle: profile.phone ?? '—',
                        onTap: profile.phone == null
                            ? null
                            : () => _dial(profile.phone!),
                        onLongPress: profile.phone == null
                            ? null
                            : () =>
                            _copy(profile.phone!, 'Telefone copiado'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // AÇÕES
                _Card(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_reset),
                        title: const Text('Alterar senha'),
                        subtitle:
                        Text('Enviaremos um e-mail para ${profile.email}'),
                        trailing: TextButton(
                          onPressed: () async {
                            await context
                                .read<ProfileController>()
                                .sendPasswordReset();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text('E-mail de redefinição enviado.')),
                            );
                          },
                          child: const Text('Enviar'),
                        ),
                      ),
                      const Divider(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Sair'),
                          ),
                          onPressed: () => _confirmSignOut(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== helpers de ação =====

  Future<void> _copy(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador.')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
            'Você precisará fazer login novamente para acessar o app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ProfileController>().signOut();
    }
  }
}

// ----------------- UI Helpers alinhados com a Home -----------------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 16, color: AppTheme.cardShadow)],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PillChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitleRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  final Color color;
  const _Avatar({required this.profile, required this.color});

  @override
  Widget build(BuildContext context) {
    final init = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim().substring(0, 1).toUpperCase()
        : 'U';

    if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          profile.photoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }

    return Text(
      init,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 22),
    );
  }
}

/// Chip de escopo com ícone + valor e tooltip para nomes longos.
class _ScopeChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ScopeChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(.10);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 8),
          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return Tooltip(message: '$label • $value', child: child);
  }
}
