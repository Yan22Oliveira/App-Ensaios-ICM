import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../src.dart';
import '../shared/geo_lookup.dart';
import 'person_create_view.dart';

class PersonView extends StatefulWidget {
  final Person person; // recebe o objeto atual
  const PersonView({super.key, required this.person});

  @override
  State<PersonView> createState() => _PersonViewState();
}

class _PersonViewState extends State<PersonView> {
  late Person _person; // cópia mutável para atualizar após a edição
  bool _dirty = false; // indica se houve alteração (para retornar ao voltar)
  bool _deactivating = false;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
  }

  void _popWithResult() {
    Navigator.pop(context, _dirty ? _person : null);
  }

  Future<void> _confirmDeactivate() async {
    if (_deactivating || !_person.active) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar membro'),
        content: Text(
          'Deseja desativar "${_person.fullName}"?\n\n'
          'O membro não aparecerá mais nas listagens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deactivating = true);
    try {
      final repo = context.read<IPersonRepository>();
      final deactivated = await repo.update(_person.copyWith(active: false));
      if (!mounted) return;
      Navigator.pop(context, deactivated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao desativar: $e')),
      );
    } finally {
      if (mounted) setState(() => _deactivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();

    final region = geo.regionName(_person.regionId) ?? _person.regionId;
    final area   = geo.areaName(_person.areaId) ?? _person.areaId ?? '';
    final polo   = geo.poloName(_person.poloId) ?? _person.poloId ?? '';

    final headerLine = [
      if (region.isNotEmpty) region,
      if (area.isNotEmpty) area,
      if (polo.isNotEmpty) polo,
    ].join(' • ');

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          leading: BackButton(onPressed: _popWithResult),
          title: const Text(
            'Detalhes do Membro',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final updated = await Navigator.push<Person?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonCreateView(existing: _person),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() {
                    _person = updated;
                    _dirty = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dados atualizados')),
                  );
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detalhes do Membro', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          headerLine,
                          style: const TextStyle(color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _StatusChip(active: _person.active),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Campos “desabilitados” com o mesmo look do form
            _ReadOnlyField(
              label: 'Nome completo',
              icon: Icons.badge_rounded,
              value: _person.fullName,
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              label: 'Telefone (opcional)',
              icon: Icons.call_rounded,
              value: _person.phone ?? '',
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              label: 'E-mail (opcional)',
              icon: Icons.email_rounded,
              value: _person.email ?? '',
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Pertence a qual grupo de louvor?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _WorshipLevelReadOnly(level: _person.worshipLevel ?? RehearsalLevel.polo),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text('Endereço:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            _ReadOnlyField(
              label: 'Região',
              icon: Icons.public_rounded,
              value: region,
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              label: 'Área',
              icon: Icons.map_rounded,
              value: area,
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              label: 'Polo',
              icon: Icons.location_on_rounded,
              value: polo,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            if (_person.roles.isNotEmpty) ...[
              const Text('Vozes / Funções', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _person.roles.map((r) {
                  return Chip(
                    label: Text(r),
                    backgroundColor: AppTheme.primary.withOpacity(.10),
                    side: BorderSide(color: AppTheme.primary.withOpacity(.5)),
                    labelStyle: TextStyle(
                      color: AppTheme.primary.withOpacity(.5),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              )
            ],

            if (_person.active) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _deactivating ? null : _confirmDeactivate,
                icon: _deactivating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_off_rounded),
                label: const Text('Desativar membro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? AppTheme.successAlt : Colors.grey).withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ATIVO' : 'INATIVO',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppTheme.successAlt : Colors.grey.shade700,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

/// Campo “fake” de leitura com o mesmo visual dos seus TextFormField
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  const _ReadOnlyField({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black12.withOpacity(.2)),
    );

    return InputDecorator(
      isFocused: false,
      isEmpty: value.isEmpty,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: _IconBadge(icon: icon, color: AppTheme.primary),
        filled: true,
        fillColor: Colors.grey.shade100,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      child: Text(
        value.isEmpty ? '—' : value,
        style: const TextStyle(color: Colors.black87),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 8),
      width: 34,
      height: 34,
      child: Icon(icon, color: color, size: 18),
    );
  }
}

/// Leitura dos “níveis de louvor” com mesma regra hierárquica:
class _WorshipLevelReadOnly extends StatelessWidget {
  final RehearsalLevel level;
  const _WorshipLevelReadOnly({required this.level});

  bool get _selPolo    => true; // sempre incluso
  bool get _selArea    => level == RehearsalLevel.area   || level == RehearsalLevel.region || level == RehearsalLevel.maanaim;
  bool get _selRegion  => level == RehearsalLevel.region || level == RehearsalLevel.maanaim;
  bool get _selMaanaim => level == RehearsalLevel.maanaim;

  @override
  Widget build(BuildContext context) {
    final hint = switch (level) {
      RehearsalLevel.maanaim => 'Inclui Região, Área e Polo',
      RehearsalLevel.region  => 'Inclui Área e Polo',
      RehearsalLevel.area    => 'Inclui Polo',
      RehearsalLevel.polo    => 'Somente Polo',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _chip('Polo',    _selPolo),
            _chip('Área',    _selArea),
            _chip('Região',  _selRegion),
            _chip('Maanaim', _selMaanaim),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: null,
      selectedColor: AppTheme.primary.withOpacity(.10),
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppTheme.primary : Colors.black26,
      ),
      showCheckmark: false,
    );
  }
}
