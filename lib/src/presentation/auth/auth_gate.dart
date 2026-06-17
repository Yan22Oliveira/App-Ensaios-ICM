// lib/src/presentation/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/repositories/i_user_profile_repository.dart';
import 'auth_controller.dart';

class AuthGate extends StatelessWidget {
  final Widget home;
  final Widget loginView;
  const AuthGate({super.key, required this.home, required this.loginView});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthController, AuthState>(
        builder: (context, state) {
          if (state.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.errorMessage != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 8),
                      Text(state.errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.read<AuthController>().signOut(),
                        child: const Text('Voltar ao login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state.isSignedOut) return loginView;
          if (state.isAwaitingApproval) {
            return _PendingAccessView(
              onSignOut: () => context.read<AuthController>().signOut(),
            );
          }
          return home;
        },
    );
  }
}

/// UI de "Acesso pendente" com visual mais rico e no padrão do app.

class _PendingAccessView extends StatefulWidget {
  final VoidCallback onSignOut;
  const _PendingAccessView({required this.onSignOut});

  @override
  State<_PendingAccessView> createState() => _PendingAccessViewState();
}

class _PendingAccessViewState extends State<_PendingAccessView> {
  bool _sending = false;
  bool _requested = false; // vira true após enviar
  String? _emailHint;

  @override
  void initState() {
    super.initState();
    _loadEmailHint();
  }

  Future<void> _loadEmailHint() async {
    // pega do perfil (se já existir). Se não existir, deixa vazio mesmo.
    try {
      final me = await context.read<IUserProfileRepository>().getCurrent();
      if (!mounted) return;
      setState(() => _emailHint = me?.email?.trim().isNotEmpty == true ? me!.email : null);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _requestAccess() async {
    if (_sending || _requested) return;
    setState(() => _sending = true);
    try {
      final profiles = context.read<IUserProfileRepository>();
      final me = await profiles.getCurrent();
      await profiles.createAccessRequest(
        email: (me?.email ?? '').trim(),
        displayName: (me?.displayName?.trim().isNotEmpty ?? false) ? me!.displayName : 'Usuário',
        phone: me?.phone,
      );
      if (!mounted) return;
      setState(() {
        _requested = true;
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação enviada. Aguarde aprovação.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao solicitar acesso: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bgPending;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Blob(size: 260, color: AppTheme.primary.withOpacity(.10)),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Blob(size: 300, color: AppTheme.primary.withOpacity(.06)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - t) * 18),
                      child: Opacity(opacity: t, child: child),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(blurRadius: 18, color: AppTheme.cardShadow)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.lock_clock_rounded, color: AppTheme.primary, size: 32),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Acesso pendente',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: .2),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Seu perfil ainda não está ativo.\nAguarde a aprovação do administrador.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, height: 1.3),
                        ),
                        const SizedBox(height: 12),

                        // Chips de status + (opcional) chip com email do usuário para facilitar suporte
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            const _ChipPill(label: 'sem perfil', color: Colors.orange),
                            const _ChipPill(label: 'aguardando aprovação', color: AppTheme.successAlt),
                            if (_emailHint != null && _emailHint!.isNotEmpty)
                              GestureDetector(
                                onLongPress: () async {
                                  await Clipboard.setData(ClipboardData(text: _emailHint??''));
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('E-mail copiado')),
                                  );
                                },
                                child: _ChipPill(label: _emailHint!, color: AppTheme.primary),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                  _requested ? AppTheme.primary.withOpacity(.55) : AppTheme.primary,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: (_sending || _requested) ? null : _requestAccess,
                                icon: _sending
                                    ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : Icon(_requested ? Icons.check_circle_rounded : Icons.send_rounded),
                                label: Text(_requested ? 'Solicitado' : 'Solicitar acesso'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _sending ? null : widget.onSignOut,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Sair'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// bolha para o fundo
class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(size)),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        border: Border.all(color: color.withOpacity(.30)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
