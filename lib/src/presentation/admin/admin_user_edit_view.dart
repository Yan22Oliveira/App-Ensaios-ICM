import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class AdminUserEditView extends StatefulWidget {
  final UserProfile user;
  final bool missingProfile;
  const AdminUserEditView({
    super.key,
    required this.user,
    this.missingProfile = false,
  });

  @override
  State<AdminUserEditView> createState() => _AdminUserEditViewState();
}

class _AdminUserEditViewState extends State<AdminUserEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  late UserRole _role;
  late bool _active;
  String? _regionId;
  String? _areaId;
  String? _poloId;

  List<Maanaim> _maanaims = const [];
  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];

  bool _loadingGeo = true;
  bool _loadingAreas = false;
  bool _loadingPolos = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.displayName);
    _phoneCtrl = TextEditingController(text: BrPhoneFormatter.format(u.phone ?? ''));
    _role = u.role;
    _active = u.active;
    _regionId = u.regionId;
    _areaId = u.areaId;
    _poloId = u.poloId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateGeo());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _showRegion =>
      _role == UserRole.polo ||
      _role == UserRole.area ||
      _role == UserRole.region ||
      _role == UserRole.maanaim;
  bool get _showArea => _role == UserRole.polo || _role == UserRole.area;
  bool get _showPolo => _role == UserRole.polo;
  String get _regionLabel => _role == UserRole.maanaim ? 'Maanaim' : 'Região';

  String? get _regionValue {
    final ids = _role == UserRole.maanaim
        ? _maanaims.map((e) => e.id)
        : _regions.map((e) => e.id);
    return ids.contains(_regionId) ? _regionId : null;
  }

  String? get _areaValue =>
      _areas.any((a) => a.id == _areaId) ? _areaId : null;

  String? get _poloValue =>
      _polos.any((p) => p.id == _poloId) ? _poloId : null;

  Future<void> _hydrateGeo() async {
    final geo = context.read<IGeoRepository>();
    final regions = await geo.regions();
    final maanaims = await geo.maanaims();
    if (!mounted) return;
    setState(() {
      _regions = regions;
      _maanaims = maanaims;
    });

    if (_showArea && _regionId != null && _regionId!.trim().isNotEmpty) {
      setState(() => _loadingAreas = true);
      final areas = await geo.areasByRegion(_regionId!);
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _loadingAreas = false;
      });
    }

    if (_showPolo && _areaId != null && _areaId!.trim().isNotEmpty) {
      setState(() => _loadingPolos = true);
      final polos = await geo.polosByArea(_areaId!);
      if (!mounted) return;
      setState(() {
        _polos = polos;
        _loadingPolos = false;
      });
    }

    if (mounted) setState(() => _loadingGeo = false);
  }

  Future<void> _loadAreas(String regionId) async {
    setState(() {
      _loadingAreas = true;
      _areas = [];
      _areaId = null;
      _polos = [];
      _poloId = null;
    });
    final list = await context.read<IGeoRepository>().areasByRegion(regionId);
    if (!mounted) return;
    setState(() {
      _areas = list;
      _loadingAreas = false;
    });
  }

  Future<void> _loadPolos(String areaId) async {
    setState(() {
      _loadingPolos = true;
      _polos = [];
      _poloId = null;
    });
    final list = await context.read<IGeoRepository>().polosByArea(areaId);
    if (!mounted) return;
    setState(() {
      _polos = list;
      _loadingPolos = false;
    });
  }

  void _onRoleChanged(UserRole r) {
    setState(() {
      _role = r;
      _regionId = null;
      _areaId = null;
      _poloId = null;
      _areas = const [];
      _polos = const [];
    });
  }

  Future<bool> _confirmSelfRisk() async {
    final me = context.read<AuthController>().state.profile;
    if (me?.uid != widget.user.uid) return true;
    if (_active && _role == UserRole.admin) return true;

    final risks = <String>[];
    if (!_active) {
      risks.add('desativar sua própria conta (você perderá o acesso agora)');
    }
    if (_role != UserRole.admin) {
      risks.add('remover seu papel de administrador');
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar alteração'),
        content: Text(
          'Você está prestes a ${risks.join(' e ')}. Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_showRegion && (_regionId == null || _regionId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_role == UserRole.maanaim
              ? 'Selecione o Maanaim.'
              : 'Selecione a Região.'),
        ),
      );
      return;
    }
    if (_showArea && (_areaId == null || _areaId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a Área.')),
      );
      return;
    }
    if (_showPolo && (_poloId == null || _poloId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o Polo.')),
      );
      return;
    }

    if (!await _confirmSelfRisk()) return;
    if (!mounted) return;

    final phone = _phoneCtrl.text.trim();
    final updated = UserProfile(
      uid: widget.user.uid,
      displayName: _nameCtrl.text.trim(),
      email: widget.user.email,
      role: _role,
      active: _active,
      regionId: _showRegion ? _regionId : null,
      areaId: _showArea ? _areaId : null,
      poloId: _showPolo ? _poloId : null,
      phone: phone.isEmpty ? null : phone,
      photoUrl: widget.user.photoUrl,
      createdAt: widget.user.createdAt,
    );

    final repo = context.read<IUserProfileRepository>();
    setState(() => _saving = true);
    try {
      await repo.updateById(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário atualizado.')),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar usuário', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loadingGeo
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.missingProfile) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Este acesso foi aprovado, mas não existe um perfil em users. Defina o papel e salve para criar o cadastro.',
                        style: TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: widget.user.email,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      helperText: 'O e-mail vem da conta de login e não pode ser alterado aqui.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [BrPhoneFormatter()],
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    value: _role,
                    decoration: const InputDecoration(labelText: 'Papel'),
                    items: const [
                      DropdownMenuItem(value: UserRole.readonly, child: Text('Somente leitura')),
                      DropdownMenuItem(value: UserRole.polo, child: Text('Polo')),
                      DropdownMenuItem(value: UserRole.area, child: Text('Área')),
                      DropdownMenuItem(value: UserRole.region, child: Text('Região')),
                      DropdownMenuItem(value: UserRole.maanaim, child: Text('Maanaim')),
                      DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
                    ],
                    onChanged: (r) => _onRoleChanged(r ?? UserRole.readonly),
                  ),
                  if (_showRegion) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _regionValue,
                      decoration: InputDecoration(labelText: _regionLabel),
                      items: _role == UserRole.maanaim
                          ? _maanaims
                              .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                              .toList()
                          : _regions
                              .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                              .toList(),
                      onChanged: (v) {
                        setState(() => _regionId = v);
                        if (v != null && _showArea && _role != UserRole.maanaim) {
                          _loadAreas(v);
                        }
                      },
                    ),
                  ],
                  if (_showArea) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _areaValue,
                      decoration: InputDecoration(
                        labelText: _loadingAreas ? 'Carregando áreas...' : 'Área',
                      ),
                      items: _areas
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: _loadingAreas
                          ? null
                          : (v) {
                              setState(() => _areaId = v);
                              if (v != null && _showPolo) _loadPolos(v);
                            },
                    ),
                  ],
                  if (_showPolo) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _poloValue,
                      decoration: InputDecoration(
                        labelText: _loadingPolos ? 'Carregando polos...' : 'Polo',
                      ),
                      items: _polos
                          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                          .toList(),
                      onChanged: _loadingPolos ? null : (v) => setState(() => _poloId = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Conta ativa'),
                    subtitle: const Text('Desative para bloquear o acesso sem excluir o usuário.'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ),
            ),
    );
  }
}
