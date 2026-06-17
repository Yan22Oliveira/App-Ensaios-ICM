import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class RehearsalCreateView extends StatefulWidget {
  final Rehearsal? existing;
  const RehearsalCreateView({super.key, this.existing});

  @override
  State<RehearsalCreateView> createState() => _RehearsalCreateViewState();
}

class _RehearsalCreateViewState extends State<RehearsalCreateView> {
  final _form = GlobalKey<FormState>();
  final _placeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  /// Perfil do usuário: define escopo (secretário de maanaim/região/área/polo).
  UserProfile? _profile;

  /// Quando true, o formulário é restrito ao escopo do secretário (não admin/readonly).
  bool get _scoped => _profile != null &&
      _profile!.role != UserRole.admin &&
      _profile!.role != UserRole.readonly;

  bool get _isSecretaryMaanaim => _profile?.role == UserRole.maanaim;
  bool get _isSecretaryRegion  => _profile?.role == UserRole.region;
  bool get _isSecretaryArea    => _profile?.role == UserRole.area;
  bool get _isSecretaryPolo    => _profile?.role == UserRole.polo;

  // --- Regras por nível (o que o ensaio precisa ter) ---
  bool get _needRegion => true;  // documento sempre tem regionId quando aplicável
  bool get _needArea   => _level == RehearsalLevel.area || _level == RehearsalLevel.polo;
  bool get _needPolo   => _level == RehearsalLevel.polo;

  /// Exibir e permitir editar dropdown Área (admin ou secretário de região).
  bool get _showAreaSelect => _needArea && (!_scoped || _isSecretaryRegion);
  /// Exibir e permitir editar dropdown Polo (admin, secretário de região ou de área).
  bool get _showPoloSelect => _needPolo && (!_scoped || _isSecretaryRegion || _isSecretaryArea);
  bool get _isMaanaim => _level == RehearsalLevel.maanaim;

  DateTime? _date;
  TimeOfDay? _time;
  RehearsalLevel _level = RehearsalLevel.polo;

  // Geo
  List<Maanaim> _maanaims = const [];
  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];
  String? _regionId;
  String? _areaId;
  String? _poloId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = context.read<AuthController>().state.profile;
    _placeCtrl.addListener(_onHeaderChanged);
    _descCtrl.addListener(_onHeaderChanged);
    _bootstrap().then((_) {
      final r = widget.existing;
      if (r != null) {
        setState(() {
          _date = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          _time = TimeOfDay(hour: r.dateTime.hour, minute: r.dateTime.minute);
          _level = r.level;
          _regionId = r.regionId;
          _areaId = r.areaId;
          _poloId = r.poloId;
          _placeCtrl.text = r.place ?? '';
          _descCtrl.text = r.description ?? '';
        });
      }
    });
  }

  Future<void> _bootstrap() async {
    final geo = context.read<IGeoRepository>();
    final resolver = context.read<GeoNameResolver>();
    if (!resolver.isLoaded) await resolver.preloadAll();

    final profile = context.read<AuthController>().state.profile;
    setState(() => _profile = profile);

    if (profile != null && profile.role != UserRole.admin && profile.role != UserRole.readonly) {
      // Escopo do secretário: fixar nível e ids
      if (profile.role == UserRole.maanaim) {
        setState(() {
          _level = RehearsalLevel.maanaim;
          _regionId = profile.regionId;
          _areaId = null;
          _poloId = null;
          _areas = const [];
          _polos = const [];
        });
      } else if (profile.role == UserRole.polo) {
        setState(() {
          _level = RehearsalLevel.polo;
          _regionId = profile.regionId;
          _areaId = profile.areaId;
          _poloId = profile.poloId;
          _areas = const [];
          _polos = const [];
        });
      } else if (profile.role == UserRole.area) {
        final polos = await geo.polosByArea(profile.areaId ?? '');
        if (!mounted) return;
        setState(() {
          _regionId = profile.regionId;
          _areaId = profile.areaId;
          _poloId = null;
          _level = RehearsalLevel.area;
          _polos = polos;
        });
      } else if (profile.role == UserRole.region) {
        final areas = await geo.areasByRegion(profile.regionId ?? '');
        if (!mounted) return;
        setState(() {
          _regionId = profile.regionId;
          _areaId = null;
          _poloId = null;
          _level = RehearsalLevel.region;
          _areas = areas;
          _polos = const [];
        });
      }
      return;
    }

    // Admin / sem escopo: carregar maanaims e regiões
    final maanaims = await geo.maanaims();
    final regions = await geo.regions();
    setState(() {
      _maanaims = maanaims;
      _regions = regions;
      _regionId = regions.isNotEmpty ? regions.first.id : null;
    });
    if (_regionId != null) {
      final areas = await geo.areasByRegion(_regionId!);
      setState(() {
        _areas = areas;
        _areaId = null;
        _polos = const [];
        _poloId = null;
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

  Future<void> _onLevelChanged(RehearsalLevel v) async {
    if (_level == v) return;
    final prevLevel = _level;
    setState(() => _level = v);

    // Quando muda o nível, zere o que não se aplica
    if (!_needPolo) _poloId = null;
    if (!_needArea) {
      _areaId = null;
      _polos = const [];
      _poloId = null;
    }

    // Admin: ao alternar entre "Maanaim" e "Região", o _regionId muda de significado (maanaimId vs regionId).
    // Garante consistência para não misturar os ids e aparecer "Maanaim ..." indevidamente.
    if (!_scoped) {
      if (v == RehearsalLevel.maanaim) {
        // usando _regionId como maanaimId
        if (_maanaims.isNotEmpty && (_regionId == null || !_maanaims.any((m) => m.id == _regionId))) {
          setState(() {
            _regionId = _maanaims.first.id;
            _areas = const [];
            _areaId = null;
            _polos = const [];
            _poloId = null;
          });
        }
      } else if (prevLevel == RehearsalLevel.maanaim && v != RehearsalLevel.maanaim) {
        // voltando para Região/Área/Polo: _regionId precisa ser regionId
        if (_regions.isNotEmpty && (_regionId == null || !_regions.any((r) => r.id == _regionId))) {
          await _onRegionChanged(_regions.first.id);
        }
      }
    }

    // Para todos os níveis (incl. Maanaim) garanta região e listas de área/polo quando aplicável
    // Se não houver região selecionada, selecione a primeira disponível
    if (_regionId == null && _regions.isNotEmpty) {
      await _onRegionChanged(_regions.first.id);
    } else {
      // Se precisa de Área e já há região, carregue as áreas
      if (_needArea && _regionId != null) {
        final geo = context.read<IGeoRepository>();
        final areas = await geo.areasByRegion(_regionId!);
        setState(() => _areas = areas);
        // Se mudou para Polo e já tem área, carregue polos
        if (_needPolo && _areaId != null) {
          final polos = await geo.polosByArea(_areaId!);
          setState(() => _polos = polos);
        }
      }
    }
  }

  static String _stripLevelPrefix(String s) {
    final t = s.trim();
    const prefixes = ['Maanaim ', 'Região ', 'Área ', 'Polo '];
    for (final p in prefixes) {
      if (t.toLowerCase().startsWith(p.toLowerCase())) {
        return t.substring(p.length).trim();
      }
    }
    return t;
  }

  String _headerTitle(GeoNameResolver geo) {
    final levelLabel = switch (_level) {
      RehearsalLevel.polo => 'Polo',
      RehearsalLevel.area => 'Área',
      RehearsalLevel.region => 'Região',
      RehearsalLevel.maanaim => 'Maanaim',
    };

    String? name;
    if (_level == RehearsalLevel.polo && _poloId != null) name = geo.poloName(_poloId!) ?? _poloId!;
    if (_level == RehearsalLevel.area && _areaId != null) name = geo.areaName(_areaId!) ?? _areaId!;
    if (_level == RehearsalLevel.region && _regionId != null) name = geo.regionName(_regionId!) ?? _regionId!;
    if (_level == RehearsalLevel.maanaim && _regionId != null) name = geo.maanaimName(_regionId!) ?? geo.regionName(_regionId!) ?? _regionId!;

    if (name == null || name.trim().isEmpty) return levelLabel;
    return '$levelLabel ${_stripLevelPrefix(name)}';
  }

  static String _fmtTime(TimeOfDay? t) =>
      t == null ? '—:—' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _placeCtrl.removeListener(_onHeaderChanged);
    _descCtrl.removeListener(_onHeaderChanged);
    _placeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onHeaderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final geo = context.read<GeoNameResolver>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Criar Ensaio' : 'Editar Ensaio',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 360;
              final cancelBtn = OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Cancelar'),
                ),
              );
              final saveBtn = ElevatedButton(
                onPressed: _saving ? null : _onSubmit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.existing == null ? 'Salvar' : 'Salvar alterações'),
                ),
              );

              if (!isNarrow) {
                return Row(
                  children: [
                    Expanded(child: cancelBtn),
                    const SizedBox(width: 12),
                    Expanded(child: saveBtn),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  saveBtn,
                  const SizedBox(height: 10),
                  cancelBtn,
                ],
              );
            },
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Header estilizado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
                ),
                child: Row(
                  children: [
                    _HeaderDateBadge(date: _date, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _headerTitle(geo),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_fmtTime(_time)} • ${_placeCtrl.text.trim().isEmpty ? '—' : _placeCtrl.text.trim()}',
                          style: const TextStyle(color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_descCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _descCtrl.text.trim(),
                            style: const TextStyle(color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _SectionCard(
                title: 'Quando',
                child: _DateTimeField(
                  date: _date,
                  time: _time,
                  onPickDate: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      locale: const Locale('pt', 'BR'),
                      helpText: 'Selecionar data',
                      cancelText: 'Cancelar',
                      confirmText: 'Confirmar',
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                      initialDate: _date ?? now,
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  onPickTime: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time ?? const TimeOfDay(hour: 14, minute: 0),
                      helpText: 'Selecionar horário',
                      cancelText: 'Cancelar',
                      confirmText: 'Confirmar',
                      builder: (context, child) => Localizations.override(
                        context: context,
                        locale: const Locale('pt', 'BR'),
                        child: child!,
                      ),
                    );
                    if (t != null) setState(() => _time = t);
                  },
                ),
              ),

              if (!_isSecretaryMaanaim && !_isSecretaryPolo) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Tipo de ensaio',
                  child: _LevelField(
                    value: _level,
                    onChanged: _onLevelChanged,
                    allowedLevels: _isSecretaryArea
                        ? [RehearsalLevel.polo, RehearsalLevel.area]
                        : _isSecretaryRegion
                            ? [RehearsalLevel.region, RehearsalLevel.area, RehearsalLevel.polo]
                            : RehearsalLevel.values,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              _SectionCard(
                title: 'Localização',
                child: Column(
                  children: [
                    if (_isSecretaryMaanaim) ...[
                      _ReadOnlyGeoField(
                        label: 'Maanaim',
                        value: _regionId != null ? (geo.regionName(_regionId!) ?? _regionId!) : '—',
                        icon: Icons.church_rounded,
                        color: AppTheme.accentOrange,
                      ),
                    ] else if (_isSecretaryPolo) ...[
                      _ReadOnlyGeoField(
                        label: 'Polo',
                        value: _poloId != null ? (geo.poloName(_poloId!) ?? _poloId!) : '—',
                        icon: Icons.location_on_rounded,
                        color: AppTheme.success,
                      ),
                    ] else if (_isSecretaryArea) ...[
                      _ReadOnlyGeoField(
                        label: 'Área',
                        value: _areaId != null ? (geo.areaName(_areaId!) ?? _areaId!) : '—',
                        icon: Icons.map_rounded,
                        color: AppTheme.accentPurple,
                      ),
                      const SizedBox(height: 12),
                      _SelectField<String>(
                        label: _level == RehearsalLevel.polo ? 'Polo do ensaio' : 'Polo (opcional — ensaio de Área)',
                        value: _poloId,
                        icon: Icons.location_on_rounded,
                        color: AppTheme.success,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Ensaio de Área —')),
                          ..._polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (v) => setState(() => _poloId = v),
                        validator: _needPolo ? (v) => (v == null || v.isEmpty) ? 'Obrigatório para ensaio de Polo' : null : null,
                      ),
                    ] else if (_isSecretaryRegion) ...[
                      _ReadOnlyGeoField(
                        label: 'Região',
                        value: _regionId != null ? (geo.regionName(_regionId!) ?? _regionId!) : '—',
                        icon: Icons.public_rounded,
                        color: AppTheme.primary,
                      ),
                      if (_showAreaSelect) ...[
                        const SizedBox(height: 12),
                        _SelectField<String>(
                          label: 'Área',
                          value: _areaId,
                          icon: Icons.map_rounded,
                          color: AppTheme.accentPurple,
                          items: _areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                          onChanged: _onAreaChanged,
                          validator: !_needArea ? null : (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ],
                      if (_showPoloSelect) ...[
                        const SizedBox(height: 12),
                        _SelectField<String>(
                          label: 'Polo',
                          value: _poloId,
                          icon: Icons.location_on_rounded,
                          color: AppTheme.success,
                          items: _polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                          onChanged: (v) => setState(() => _poloId = v),
                          validator: !_needPolo ? null : (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ],
                    ] else ...[
                      // Admin
                      if (_isMaanaim)
                        _SelectField<String>(
                          label: 'Maanaim',
                          value: _regionId,
                          icon: Icons.music_note_rounded,
                          color: AppTheme.accentOrange,
                          items: _maanaims.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                          onChanged: (v) => setState(() {
                            _regionId = v;
                            _areas = const [];
                            _areaId = null;
                            _polos = const [];
                            _poloId = null;
                          }),
                          validator: (v) => (v == null || v.toString().trim().isEmpty) ? 'Selecione o Maanaim' : null,
                        )
                      else
                        _SelectField<String>(
                          label: 'Região',
                          value: _regionId,
                          icon: Icons.public_rounded,
                          color: AppTheme.primary,
                          items: _regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                          onChanged: _onRegionChanged,
                          validator: (v) => (v == null || v.toString().trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                      if (_needArea) ...[
                        const SizedBox(height: 12),
                        _SelectField<String>(
                          label: 'Área',
                          value: _areaId,
                          icon: Icons.map_rounded,
                          color: AppTheme.accentPurple,
                          items: _areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                          onChanged: _showAreaSelect ? _onAreaChanged : null,
                          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ],
                      if (_needPolo) ...[
                        const SizedBox(height: 12),
                        _SelectField<String>(
                          label: 'Polo',
                          value: _poloId,
                          icon: Icons.location_on_rounded,
                          color: AppTheme.success,
                          items: _polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                          onChanged: _showPoloSelect ? (v) => setState(() => _poloId = v) : null,
                          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              _SectionCard(
                title: 'Detalhes',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _placeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Local do ensaio*',
                        prefixIcon: Icon(Icons.place_rounded, color: Colors.redAccent, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o local do ensaio';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_form.currentState!.validate()) return;

    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecionar data e hora')),
      );
      return;
    }

    // Regras por nível
    if (_regionId == null || _regionId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isMaanaim ? 'Selecione qual Maanaim (Região)' : 'Selecione a Região')),
      );
      return;
    }
    if (_needArea && _areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a Área')),
      );
      return;
    }
    if (_needPolo && _poloId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o Polo')),
      );
      return;
    }

    // Limpa o que NÃO se aplica antes de salvar
    final regionId = _needRegion ? _regionId : null;
    final areaId   = _needArea   ? _areaId   : null;
    final poloId   = _needPolo   ? _poloId   : null;

    final dateTime = DateTime(
      _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute,
    );

    setState(() => _saving = true);
    try {
      final repo = context.read<IRehearsalRepository>();
      if (widget.existing == null) {
        final created = await repo.create(
          dateTime: dateTime,
          level: _level,
          regionId: regionId ?? '',
          areaId: areaId,
          poloId: poloId,
          place: _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.pop(context, created);
      } else {
        final updated = await repo.update(
          id: widget.existing!.id,
          dateTime: dateTime,
          level: _level,
          regionId: regionId ?? '',
          areaId: areaId,
          poloId: poloId,
          place: _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          closed: widget.existing!.closed,
          closedAt: widget.existing!.closedAt,
        );
        if (!mounted) return;
        Navigator.pop(context, updated);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}

// ---------------- COMPONENTES DE UI ----------------

class _DateTimeField extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeField({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = (date == null)
        ? 'Selecionar data'
        : '${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}';
    final timeStr = (time == null)
        ? 'Selecionar horário'
        : '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}';

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 420;

        final dateBtn = OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(dateStr, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );

        final timeBtn = OutlinedButton.icon(
          onPressed: onPickTime,
          icon: const Icon(Icons.access_time_rounded),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(timeStr, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );

        if (!isNarrow) {
          return Row(
            children: [
              Expanded(child: dateBtn),
              const SizedBox(width: 12),
              Expanded(child: timeBtn),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dateBtn,
            const SizedBox(height: 12),
            timeBtn,
          ],
        );
      },
    );
  }
}

class _LevelField extends StatelessWidget {
  final RehearsalLevel value;
  final ValueChanged<RehearsalLevel> onChanged;
  final List<RehearsalLevel> allowedLevels;

  const _LevelField({
    required this.value,
    required this.onChanged,
    List<RehearsalLevel>? allowedLevels,
  }) : allowedLevels = allowedLevels ?? RehearsalLevel.values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allowedLevels.map((lvl) {
        final selected = value == lvl;
        final label = switch (lvl) {
          RehearsalLevel.polo => 'Polo',
          RehearsalLevel.area => 'Área',
          RehearsalLevel.region => 'Região',
          RehearsalLevel.maanaim => 'Maanaim',
        };
        final color = switch (lvl) {
          RehearsalLevel.polo => AppTheme.primary,
          RehearsalLevel.area => AppTheme.accentPurple,
          RehearsalLevel.region => AppTheme.success,
          RehearsalLevel.maanaim => AppTheme.accentOrange,
        };
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onChanged(lvl),
          label: Text(label),
          selectedColor: color.withOpacity(.15),
          labelStyle: TextStyle(
            color: selected ? color : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}

/// Campo somente leitura com mesmo visual do _SelectField (label + ícone + valor).
class _ReadOnlyGeoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReadOnlyGeoField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black12.withOpacity(.2)),
    );
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: _IconBadge(icon: icon, color: color),
        border: border,
        enabledBorder: border,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      child: Text(value, style: const TextStyle(fontSize: 16)),
    );
  }
}

/// Dropdown estilizado (mesmo usado no cadastro de pessoa)
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

    // value deve existir em items; senão Flutter lança assertion
    final effectiveValue = value != null &&
            value.toString().trim().isNotEmpty &&
            items.any((item) => item.value == value)
        ? value
        : null;

    return DropdownButtonFormField<T>(
      value: effectiveValue,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HeaderDateBadge extends StatelessWidget {
  final DateTime? date;
  final Color color;

  const _HeaderDateBadge({required this.date, required this.color});

  String _mesAbreviado(int month) {
    const meses = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    return meses[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.calendar_month_rounded, color: color),
      );
    }

    final day = date!.day.toString().padLeft(2, '0');
    final month = _mesAbreviado(date!.month);
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
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
