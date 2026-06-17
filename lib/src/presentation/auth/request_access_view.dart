import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class RequestAccessView extends StatefulWidget {
  const RequestAccessView({super.key});

  @override
  State<RequestAccessView> createState() => _RequestAccessViewState();
}

class _RequestAccessViewState extends State<RequestAccessView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text('Solicitar acesso', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
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
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Preencha seus dados para criar sua conta e enviar a solicitação ao administrador.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
            ],

            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_loading,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Informe seu nome completo'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),

                  // TELEFONE (máscara brasil_fields + validação)
                  TextFormField(
                    controller: _phone,
                    enabled: !_loading,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11), // DDD + 8/9 dígitos
                      TelefoneInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Telefone (opcional)',
                      hintText: '(31) 91234-5678',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: _validatePhoneOptional,
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass,
                    enabled: !_loading,
                    obscureText: _obscure1,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscure1 ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Use ao menos 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass2,
                    enabled: !_loading,
                    obscureText: _obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscure2 ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscure2 = !_obscure2),
                      ),
                    ),
                    validator: (v) => (v != _pass.text) ? 'As senhas não conferem' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Criar conta e solicitar acesso'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Já tenho conta • Fazer login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SUBMIT ----------
  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() { _loading = true; _error = null; });

    final auth = FirebaseAuth.instance;
    final fs = FirebaseFirestore.instance;

    final name = _name.text.trim();
    final email = _email.text.trim();
    final phoneDigits = _digits(_phone.text); // salvar só dígitos
    final pass = _pass.text.trim();

    try {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: pass);
      final user = cred.user!;
      await user.updateDisplayName(name);

      await fs.collection('accessRequests').doc(user.uid).set({
        'requesterUid': user.uid,
        'email': email,
        'displayName': name,
        'phone': phoneDigits.isEmpty ? null : phoneDigits,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'decidedAt': null,
        'decidedBy': null,
        'reason': null,
      }, SetOptions(merge: true));

      await user.sendEmailVerification();
      await auth.signOut();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Solicitação enviada'),
          content: const Text(
              'Sua conta foi criada e a solicitação de acesso foi enviada.\n'
                  'Você receberá o acesso após aprovação do administrador.\n'
                  'Confirme seu e-mail para liberar o login.'
          ),
          actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')) ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Falha ao criar conta.';
      switch (e.code) {
        case 'email-already-in-use': msg = 'Este e-mail já está em uso.'; break;
        case 'invalid-email': msg = 'E-mail inválido.'; break;
        case 'weak-password': msg = 'Senha muito fraca. Use ao menos 6 caracteres.'; break;
      }
      setState(() { _error = msg; });
    } catch (e) {
      setState(() { _error = 'Erro inesperado: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ---------- VALIDATIONS ----------
  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Informe seu e-mail';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'E-mail inválido';
    return null;
  }

  /// Telefone opcional: se preenchido, exige 10 ou 11 dígitos (com DDD)
  String? _validatePhoneOptional(String? v) {
    final d = _digits(v ?? '');
    if (d.isEmpty) return null;
    if (d.length < 10 || d.length > 11) {
      return 'Telefone inválido (use 10 ou 11 dígitos)';
    }
    return null;
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');
}
