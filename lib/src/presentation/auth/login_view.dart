import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: BlocBuilder<AuthController, AuthState>(
          builder: (context, state) {
            final loading = state.loading;
            final error = state.errorMessage;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(blurRadius: 16, color: AppTheme.cardShadow)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.lock_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Seja bem-vindo(a)', style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Acesse sua conta para continuar', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pass,
                        enabled: !loading,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 8),

                      // linha com "esqueci a senha" e erro
                      Row(
                        children: [
                          TextButton(
                            onPressed: loading ? null : _forgotPassword,
                            child: const Text('Esqueci minha senha'),
                          ),
                          const Spacer(),
                          if (error != null)
                            Flexible(
                              child: Text(error, textAlign: TextAlign.end, style: const TextStyle(color: Colors.redAccent)),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Entrar'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // --- NOVO: atalho para criar conta / solicitar acesso ---
                      TextButton(
                        onPressed: loading ? null : _goToRequestAccess,
                        child: const Text("Não tem conta? Solicitar acesso"),
                      ),
                      // --------------------------------------------------------
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await context.read<AuthController>().signInWithEmail(_email.text.trim(), _pass.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrando...')));
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    final err = _validateEmail(email);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um e-mail válido')));
      return;
    }
    await context.read<AuthController>().sendPasswordReset(email);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verifique seu e-mail'),
        content: Text('Enviamos instruções para $email.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok'))],
      ),
    );
  }

  void _goToRequestAccess() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestAccessView()));
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Informe seu e-mail';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'E-mail inválido';
    return null;
  }
}
