import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class PersonCreateView extends StatefulWidget {
  final Person? existing; // ← null = criação, != null = edição
  const PersonCreateView({super.key, this.existing});

  @override
  State<PersonCreateView> createState() => _PersonCreateViewState();
}

class _PersonCreateViewState extends State<PersonCreateView> {
  final _form = GlobalKey<FormState>();

  // Inputs
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  RehearsalLevel _worshipLevel = RehearsalLevel.polo;

  // Geo
  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];
  String? _regionId;
  String? _areaId;
  String? _poloId;

  // Roles
  final Set<String> _roles = {};
  List<RoleGroup> _roleGroups = const [];
  bool _rolesLoading = true;

  bool _saving = false;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final geoRepo = context.read<IGeoRepository>();
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) await resolver.preloadAll();

    // carrega regiões
    final regions = await geoRepo.regions();

    // Pré-preenche se edição
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.fullName;
      _phoneCtrl.text = BrPhoneFormatter.format(p.phone ?? '');
      _emailCtrl.text = p.email ?? '';
      _regionId = p.regionId;
      _areaId   = p.areaId;
      _poloId   = p.poloId;
      _roles.addAll(p.roles);
      _worshipLevel = p.worshipLevel;
    } else {
      _regionId = regions.isNotEmpty ? regions.first.id : null;
    }

    setState(() => _regions = regions);

    // carrega áreas e polos respeitando pré-seleção
    if (_regionId != null) {
      final areas = await geoRepo.areasByRegion(_regionId!);
      setState(() => _areas = areas);
      if (_areaId != null) {
        final polos = await geoRepo.polosByArea(_areaId!);
        setState(() => _polos = polos);
      }
    }

    // carrega grupos de roles
    try {
      final rolesRepo = context.read<IRolesRepository>();
      final groups = await rolesRepo.listGroups()
        ..sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _roleGroups = groups;
        _rolesLoading = false;
      });
    } catch (_) {
      setState(() => _rolesLoading = false);
    }
  }

  Future<void> _onRegionChanged(String? id) async {
    if (id == null) return;
    final geo = context.read<IGeoRepository>();
    final areas = await geo.areasByRegion(id);
    setState(() {
      _regionId = id;
      _areas = areas;
      _areaId = null;
      _polos = const [];
      _poloId = null;
    });
  }

  Future<void> _onAreaChanged(String? id) async {
    final geo = context.read<IGeoRepository>();
    setState(() {
      _areaId = id;
      _polos = const [];
      _poloId = null;
    });
    if (id != null) {
      final polos = await geo.polosByArea(id);
      setState(() => _polos = polos);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolver = context.read<GeoNameResolver>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          _isEdit ? 'Editar Membro' : 'Novo Membro',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Salvar alterações' : 'Salvar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _isEdit ? 'Editar membro' : 'Criar novo membro',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (_regionId != null) (resolver.regionName(_regionId!) ?? _regionId!),
                          if (_areaId != null) (resolver.areaName(_areaId!) ?? _areaId!),
                          if (_poloId != null) (resolver.poloName(_poloId!) ?? _poloId!),
                        ].join(' • '),
                        style: const TextStyle(color: Colors.black54),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nome
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.badge_rounded, color: Colors.grey, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Telefone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // só números
                BrPhoneFormatter(),                     // mascara dinâmica
              ],
              decoration: const InputDecoration(
                labelText: 'Telefone (opcional)',
                prefixIcon: Icon(Icons.call_rounded),
                hintText: '(00) 90000-0000',
              ),
              validator: _validatePhone,
            ),

            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail (opcional)',
                prefixIcon: Icon(Icons.email_rounded),
              ),
              validator: _validateEmail,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Pertence a qual grupo de louvor?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            _WorshipLevelField(
              value: _worshipLevel,
              maxLevel: _maxAllowedLevel(context.read<AuthController>().state.profile),
              onChanged: (lvl) => setState(() => _worshipLevel = lvl),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text('Endereço:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            _GeoSection(
              regions: _regions, areas: _areas, polos: _polos,
              regionId: _regionId, areaId: _areaId, poloId: _poloId,
              onRegionChanged: _onRegionChanged,
              onAreaChanged: _onAreaChanged,
              onPoloChanged: (v) => setState(() => _poloId = v),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            if (_rolesLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else
              _RolesSection(
                groups: _roleGroups,
                selected: _roles,
                onChanged: (role, selected) {
                  setState(() {
                    if (selected) { _roles.add(role); } else { _roles.remove(role); }
                  });
                },
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;

    if (_regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecionar uma Região')),
      );
      return;
    }
    if (_areaId == null || _areaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecionar uma Área')),
      );
      return;
    }
    if (_poloId == null || _poloId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecionar um Polo')),
      );
      return;
    }
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um papel (role)')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = context.read<IPersonRepository>();
      final person = Person(
        id: widget.existing?.id ?? 'TEMP',
        fullName: _nameCtrl.text.trim(),
        regionId: _regionId!,
        areaId: _areaId,
        poloId: _poloId,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        roles: _roles.toList()..sort(),
        active: widget.existing?.active ?? true,
        worshipLevel: _worshipLevel,
      );

      final saved = _isEdit ? await repo.update(person) : await repo.create(person);

      if (!mounted) return;
      Navigator.pop(context, saved); // devolve o objeto salvo/atualizado
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================
// Helpers e Widgets faltantes
// =============================

// Valida formato (37) 98877-5544 ou (37) 8877-5544
String? _validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return null; // opcional
  final s = v.trim();
  final re = RegExp(r'^\(\d{2}\)\s?\d{4,5}-\d{4}$');
  if (!re.hasMatch(s)) return 'Formato: (37) 98877-5544';
  return null;
}

// Validação simples de e-mail
String? _validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return null; // opcional
  final s = v.trim();
  final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!re.hasMatch(s)) return 'E-mail inválido';
  return null;
}

// ---------------- Worship level ----------------

class _WorshipLevelField extends StatelessWidget {
  final RehearsalLevel value;
  final RehearsalLevel maxLevel;
  final ValueChanged<RehearsalLevel> onChanged;

  const _WorshipLevelField({
    required this.value,
    required this.maxLevel,
    required this.onChanged,
  });

  bool get _selPolo    => true; // sempre no mínimo polo
  bool get _selArea    => value == RehearsalLevel.area   || value == RehearsalLevel.region || value == RehearsalLevel.maanaim;
  bool get _selRegion  => value == RehearsalLevel.region || value == RehearsalLevel.maanaim;
  bool get _selMaanaim => value == RehearsalLevel.maanaim;

  @override
  Widget build(BuildContext context) {
    int rank(RehearsalLevel l) => switch (l) {
      RehearsalLevel.polo => 0,
      RehearsalLevel.area => 1,
      RehearsalLevel.region => 2,
      RehearsalLevel.maanaim => 3,
    };
    final maxRank = rank(maxLevel);

    final chips = <({String label, bool selected, RehearsalLevel level})>[
      (label: 'Polo',    selected: _selPolo,    level: RehearsalLevel.polo),
      (label: 'Área',    selected: _selArea,    level: RehearsalLevel.area),
      (label: 'Região',  selected: _selRegion,  level: RehearsalLevel.region),
      (label: 'Maanaim', selected: _selMaanaim, level: RehearsalLevel.maanaim),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          switch (value) {
            RehearsalLevel.maanaim => 'Inclui Região, Área e Polo',
            RehearsalLevel.region  => 'Inclui Área e Polo',
            RehearsalLevel.area    => 'Inclui Polo',
            RehearsalLevel.polo    => 'Somente Polo',
          },
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: chips.map((c) {
            final enabled = rank(c.level) <= maxRank;
            return FilterChip(
              label: Text(c.label),
              selected: c.selected,
              onSelected: enabled ? (_) => onChanged(c.level) : null,
              selectedColor: AppTheme.primary.withOpacity(.18),
              labelStyle: TextStyle(
                color: c.selected ? AppTheme.primary : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

RehearsalLevel _maxAllowedLevel(UserProfile? editor) {
  return switch (editor?.role) {
    UserRole.polo => RehearsalLevel.polo,
    UserRole.area => RehearsalLevel.area,
    UserRole.region => RehearsalLevel.region,
    UserRole.maanaim => RehearsalLevel.maanaim,
    UserRole.admin => RehearsalLevel.maanaim,
    UserRole.readonly => RehearsalLevel.maanaim,
    _ => RehearsalLevel.maanaim,
  };
}

// ---------------- Geo (Region/Area/Polo) ----------------

class _GeoSection extends StatelessWidget {
  final List<Region> regions;
  final List<Area> areas;
  final List<Polo> polos;
  final String? regionId;
  final String? areaId;
  final String? poloId;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<String?> onPoloChanged;

  const _GeoSection({
    required this.regions,
    required this.areas,
    required this.polos,
    required this.regionId,
    required this.areaId,
    required this.poloId,
    required this.onRegionChanged,
    required this.onAreaChanged,
    required this.onPoloChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SelectField<String>(
          label: 'Região',
          value: regionId,
          icon: Icons.public_rounded,
          color: AppTheme.primary,
          items: regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
          onChanged: onRegionChanged,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        _SelectField<String>(
          label: 'Área',
          value: areaId,
          icon: Icons.map_rounded,
          color: AppTheme.accentPurple,
          items: areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
          onChanged: onAreaChanged,
          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 12),
        _SelectField<String>(
          label: 'Polo',
          value: poloId,
          icon: Icons.location_on_rounded,
          color: AppTheme.success,
          items: polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
          onChanged: onPoloChanged,
          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
        ),
      ],
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final IconData icon;
  final Color color;

  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.color,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black12.withOpacity(.2)),
    );

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: _IconBadge(icon: icon, color: color),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: color.withOpacity(.6), width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      dropdownColor: Colors.white,
      menuMaxHeight: 320,
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

// ---------------- Roles dinâmicos ----------------

class _RolesSection extends StatefulWidget {
  final List<RoleGroup> groups;
  final Set<String> selected;
  final void Function(String role, bool selected) onChanged;

  const _RolesSection({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<_RolesSection> {
  final Set<String> _expanded = {}; // grupos abertos

  void _toggle(String groupKey) {
    setState(() {
      if (_expanded.contains(groupKey)) {
        _expanded.remove(groupKey);
      } else {
        _expanded.add(groupKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) return const Text('Nenhum papel (role) configurado ainda.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.groups.map((g) {
        final options = [...g.items]..sort();
        final groupKey = g.id.isNotEmpty ? g.id : g.name;
        final isOpen = _expanded.contains(groupKey);

        return _GroupChips(
          title: g.name,
          options: options,
          selected: widget.selected,
          isOpen: isOpen,
          onToggle: () => _toggle(groupKey),
          onChanged: widget.onChanged,
        );
      }).toList(),
    );
  }
}

class _GroupChips extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final bool isOpen;
  final VoidCallback onToggle;
  final void Function(String role, bool selected) onChanged;

  const _GroupChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          GestureDetector(
            onTap: onToggle,
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onToggle,
                    tooltip: isOpen ? 'Recolher' : 'Expandir',
                    icon: Icon(
                      isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: options.map((r) {
                  final isSel = selected.contains(r);
                  return ChoiceChip(
                    label: Text(r),
                    selected: isSel,
                    onSelected: (v) => onChanged(r, v),
                    selectedColor: AppTheme.primary.withOpacity(.18),
                    labelStyle: TextStyle(
                      color: isSel ? AppTheme.primary : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: (isSel ? AppTheme.primary : Colors.black26).withOpacity(.35),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
