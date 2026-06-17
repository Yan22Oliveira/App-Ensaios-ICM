import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../src.dart';

typedef PersonSubmit = Future<void> Function(PersonInput input);

class PersonInput {
  final String fullName;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final String? phone;
  final String? email;
  final List<String> roles;
  final bool active;
  final RehearsalLevel worshipLevel;

  const PersonInput({
    required this.fullName,
    required this.regionId,
    this.areaId,
    this.poloId,
    this.phone,
    this.email,
    required this.roles,
    required this.active,
    required this.worshipLevel,
  });

  factory PersonInput.fromPerson(Person p) => PersonInput(
    fullName: p.fullName,
    regionId: p.regionId,
    areaId: p.areaId,
    poloId: p.poloId,
    phone: p.phone,
    email: p.email,
    roles: [...p.roles],
    active: p.active,
    worshipLevel: p.worshipLevel,
  );

  Person toPersonWithId(String id) => Person(
    id: id,
    fullName: fullName,
    regionId: regionId,
    areaId: areaId,
    poloId: poloId,
    phone: phone,
    email: email,
    roles: roles,
    active: active,
    worshipLevel: worshipLevel,
  );
}

/// Formulário reutilizável para Criar/Editar/Visualizar.
/// - Se [readOnly] = true, todos os campos ficam desabilitados e o botão de salvar some.
/// - Se [initial] != null, o formulário começa preenchido.
/// - Ao submeter, chama [onSubmit] com um [PersonInput] validado.
class PersonForm extends StatefulWidget {
  final PersonInput? initial;
  final bool readOnly;
  final PersonSubmit? onSubmit;
  final String title; // exibe no header

  const PersonForm({
    super.key,
    required this.title,
    this.initial,
    this.readOnly = false,
    this.onSubmit,
  });

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Worship
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final geoRepo = context.read<IGeoRepository>();
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) { await resolver.preloadAll(); }
    final editorProfile = context.read<AuthController>().state.profile;

    // Carrega roles
    try {
      final rolesRepo = context.read<IRolesRepository>();
      final groups = await rolesRepo.listGroups();
      groups.sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _roleGroups = groups;
        _rolesLoading = false;
      });
    } catch (_) {
      setState(() => _rolesLoading = false);
    }

    // Preenche controles se houver initial
    final initial = widget.initial;
    if (initial != null) {
      _phoneCtrl.text = BrPhoneFormatter.format(initial.phone ?? '');
      _nameCtrl.text = initial.fullName;
      _emailCtrl.text = initial.email ?? '';
      _worshipLevel = initial.worshipLevel;
      _roles
        ..clear()
        ..addAll(initial.roles);
    }

    // Aplica limite do secretário: não permite nível acima do permitido.
    final maxAllowed = _maxAllowedLevel(editorProfile);
    _worshipLevel = _capLevel(_worshipLevel, maxAllowed);

    // Carrega geos e posiciona seleção
    final regions = await geoRepo.regions();
    setState(() {
      _regions = regions;
      _regionId = initial?.regionId ?? (regions.isNotEmpty ? regions.first.id : null);
    });

    if (_regionId != null) {
      final areas = await geoRepo.areasByRegion(_regionId!);
      setState(() {
        _areas = areas;
        _areaId = initial?.areaId;
      });
    }
    if (_areaId != null) {
      final polos = await geoRepo.polosByArea(_areaId!);
      setState(() {
        _polos = polos;
        _poloId = initial?.poloId;
      });
    } else {
      setState(() {
        _polos = const [];
        _poloId = initial?.poloId; // se vier null, mantém null
      });
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
    final disabled = widget.readOnly || _saving;

    final page = Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: disabled ? null : () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: disabled ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar'),
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
                      Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              enabled: !disabled,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.badge_rounded,color: Colors.grey,size: 20,),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 16),

            // Telefone
            TextFormField(
              controller: _phoneCtrl,
              enabled: !disabled,
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

            // E-mail
            TextFormField(
              controller: _emailCtrl,
              enabled: !disabled,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail (opcional)',
                prefixIcon: Icon(Icons.email_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 8),

            // Worship level
            Text('Pertence a qual grupo de louvor?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _WorshipLevelField(
              value: _worshipLevel,
              maxLevel: _maxAllowedLevel(context.read<AuthController>().state.profile),
              onChanged: disabled ? null : (lvl) => setState(() => _worshipLevel = lvl),
            ),
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 8),
            Text('Endereço:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),

            _GeoSection(
              regions: _regions, areas: _areas, polos: _polos,
              regionId: _regionId, areaId: _areaId, poloId: _poloId,
              onRegionChanged: disabled ? null : _onRegionChanged,
              onAreaChanged: disabled ? null : _onAreaChanged,
              onPoloChanged: disabled ? null : (v) => setState(() => _poloId = v),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            if (_rolesLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else
              _RolesSection(
                groups: _roleGroups,
                selected: _roles,
                enabled: !disabled,
                onChanged: (role, selected) {
                  setState(() {
                    if (selected) {
                      _roles.add(role);
                    } else {
                      _roles.remove(role);
                    }
                  });
                },
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );

    return page;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;

    if (_regionId == null || _regionId!.trim().isEmpty) {
      _toast('Selecionar uma Região');
      return;
    }
    if (_areaId == null || _areaId!.trim().isEmpty) {
      _toast('Selecionar uma Área');
      return;
    }
    if ((_worshipLevel == RehearsalLevel.maanaim || _worshipLevel == RehearsalLevel.region) &&
        (_poloId == null || _poloId!.trim().isEmpty)) {
      _toast('Para nível ${_worshipLevel.name == 'maanaim' ? 'Maanaim' : 'Região'}, selecione um Polo');
      return;
    }
    // Área: exige polo
    if (_worshipLevel == RehearsalLevel.area && (_poloId == null || _poloId!.trim().isEmpty)) {
      _toast('Para nível Área, selecione um Polo');
      return;
    }
    // Polo: exige ao menos o polo
    if (_poloId == null || _poloId!.trim().isEmpty) {
      _toast('Selecionar um Polo');
      return;
    }
    if (_roles.isEmpty) {
      _toast('Selecione pelo menos um papel (role)');
      return;
    }

    final input = PersonInput(
      fullName: _nameCtrl.text.trim(),
      regionId: _regionId!,
      areaId: _areaId,
      poloId: _poloId,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      roles: _roles.toList()..sort(),
      active: true,
      worshipLevel: _worshipLevel,
    );

    setState(() => _saving = true);
    try {
      await widget.onSubmit?.call(input);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static int _levelRank(RehearsalLevel l) => switch (l) {
    RehearsalLevel.polo => 0,
    RehearsalLevel.area => 1,
    RehearsalLevel.region => 2,
    RehearsalLevel.maanaim => 3,
  };

  static RehearsalLevel _capLevel(RehearsalLevel current, RehearsalLevel max) {
    return _levelRank(current) <= _levelRank(max) ? current : max;
  }

  static RehearsalLevel _maxAllowedLevel(UserProfile? editor) {
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
}

// ======= Subcomponentes =======

class _WorshipLevelField extends StatelessWidget {
  final RehearsalLevel value;
  final RehearsalLevel maxLevel;
  final ValueChanged<RehearsalLevel>? onChanged;

  const _WorshipLevelField({
    required this.value,
    required this.maxLevel,
    required this.onChanged,
  });

  bool get _selPolo    => true;
  bool get _selArea    => value == RehearsalLevel.area   || value == RehearsalLevel.region || value == RehearsalLevel.maanaim;
  bool get _selRegion  => value == RehearsalLevel.region || value == RehearsalLevel.maanaim;
  bool get _selMaanaim => value == RehearsalLevel.maanaim;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;
    int rank(RehearsalLevel l) => switch (l) {
      RehearsalLevel.polo => 0,
      RehearsalLevel.area => 1,
      RehearsalLevel.region => 2,
      RehearsalLevel.maanaim => 3,
    };
    final maxRank = rank(maxLevel);

    final chips = <({
    String label,
    bool selected,
    RehearsalLevel level,
    })>[
      (label: 'Polo',    selected: _selPolo,    level: RehearsalLevel.polo),
      (label: 'Área',    selected: _selArea,    level: RehearsalLevel.area),
      (label: 'Região',  selected: _selRegion,  level: RehearsalLevel.region),
      (label: 'Maanaim', selected: _selMaanaim, level: RehearsalLevel.maanaim),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (value) {
            RehearsalLevel.maanaim => 'Inclui Região, Área e Polo',
            RehearsalLevel.region  => 'Inclui Área e Polo',
            RehearsalLevel.area    => 'Inclui Polo',
            RehearsalLevel.polo    => 'Somente Polo',
          },
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: chips.map((c) {
            final allowed = rank(c.level) <= maxRank;
            final enabled = isEnabled && allowed;
            return FilterChip(
              label: Text(c.label),
              selected: c.selected,
              onSelected: enabled ? (_) => onChanged!.call(c.level) : null,
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

class _GeoSection extends StatelessWidget {
  final List<Region> regions;
  final List<Area> areas;
  final List<Polo> polos;
  final String? regionId;
  final String? areaId;
  final String? poloId;
  final ValueChanged<String?>? onRegionChanged;
  final ValueChanged<String?>? onAreaChanged;
  final ValueChanged<String?>? onPoloChanged;

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
          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
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
          validator: (v) => (v == null || (v.isEmpty)) ? 'Obrigatório' : null,
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
      icon: Icon(
        Icons.expand_more_rounded,
        color: AppTheme.primary,
      ),
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

class _RolesSection extends StatefulWidget {
  final List<RoleGroup> groups;
  final Set<String> selected;
  final void Function(String role, bool selected) onChanged;
  final bool enabled;

  const _RolesSection({
    required this.groups,
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  @override
  State<_RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<_RolesSection> {
  final Set<String> _expanded = {};

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
    if (widget.groups.isEmpty) {
      return const Text('Nenhum role configurado ainda.');
    }

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
          enabled: widget.enabled,
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
  final bool enabled;

  const _GroupChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: AppTheme.primary,
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
                spacing: 8,
                runSpacing: 8,
                children: options.map((r) {
                  final isSel = selected.contains(r);
                  return ChoiceChip(
                    label: Text(r),
                    selected: isSel,
                    onSelected: enabled ? (v) => onChanged(r, v) : null,
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

// ======= Validadores reutilizáveis =======

String? _validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final s = v.trim();
  final re = RegExp(r'^\(\d{2}\)\s?\d{4,5}-\d{4}$');
  if (!re.hasMatch(s)) return 'Formato: (37) 98877-5544';
  return null;
}

String? _validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final s = v.trim();
  final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!re.hasMatch(s)) return 'E-mail inválido';
  return null;
}