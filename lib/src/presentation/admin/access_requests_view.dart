import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class AccessRequestsView extends StatelessWidget {
  const AccessRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IAccessRequestRepository>();

    return StreamBuilder<List<AccessRequest>>(
      stream: repo.watchPending(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) return const _EmptyState();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => _RequestCard(req: items[i]),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.verified_user_outlined, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('Nenhuma solicitação pendente', style: TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AccessRequest req;
  const _RequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    final created = req.createdAt;
    String when = '';
    if (created != null) {
      final d = '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}';
      final h = '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
      when = '$d $h';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 12, color: AppTheme.cardShadow)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accentTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(req.email, style: const TextStyle(color: Colors.black54)),
              if ((req.phone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(req.phone!, style: const TextStyle(color: Colors.black54)),
              ],
            ]),
          ),
          if (when.isNotEmpty)
            Text(when, style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Rejeitar'),
              ),
              onPressed: () async {
                final controller = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Rejeitar solicitação'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tem certeza que deseja rejeitar?'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Motivo (opcional)',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Rejeitar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await context
                        .read<IAccessRequestRepository>()
                        .reject(requestId: req.id, reason: controller.text.trim().isEmpty ? null : controller.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Solicitação rejeitada.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Aprovar'),
              ),
              onPressed: () async {
                final result = await showModalBottomSheet<_ApproveResult>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _ApproveSheet(displayName: req.displayName),
                );
                if (result != null) {
                  try {
                    await context.read<IAccessRequestRepository>().approve(
                      requestId: req.id,
                      role: result.role,
                      regionId: result.regionId,
                      areaId: result.areaId,
                      poloId: result.poloId,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${req.displayName} aprovado(a).')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ApproveResult {
  final UserRole role;
  final String? regionId;
  final String? areaId;
  final String? poloId;
  _ApproveResult({required this.role, this.regionId, this.areaId, this.poloId});
}

class _ApproveSheet extends StatefulWidget {
  final String displayName;
  const _ApproveSheet({required this.displayName});

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  UserRole _role = UserRole.readonly;

  String? _regionId;
  String? _areaId;
  String? _poloId;

  List<Maanaim> _maanaims = const [];
  List<Region> _regions = const [];
  List<Area> _areas = const [];
  List<Polo> _polos = const [];

  bool _loadingAreas = false;
  bool _loadingPolos = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _loadMaanaims();
  }

  Future<void> _loadRegions() async {
    final list = await context.read<IGeoRepository>().regions();
    if (mounted) setState(() => _regions = list);
  }

  Future<void> _loadMaanaims() async {
    final list = await context.read<IGeoRepository>().maanaims();
    if (mounted) setState(() => _maanaims = list);
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
    setState(() {
      _polos = list;
      _loadingPolos = false;
    });
  }

  /// Regras de negócio: quais campos exibir e validar por nível.
  /// Polo: Região, Área e Polo. Área: Região e Área (polo não aplicável). Região: só Região (área e polo não aplicável). Maanaim: só Maanaim/Região (área e polo não aplicável).
  bool get _showRegion => _role == UserRole.polo || _role == UserRole.area || _role == UserRole.region || _role == UserRole.maanaim;
  bool get _showArea => _role == UserRole.polo || _role == UserRole.area;
  bool get _showPolo => _role == UserRole.polo;

  String get _regionLabel => _role == UserRole.maanaim ? 'Maanaim' : 'Região';

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

  void _submit() {
    if (_showRegion && (_regionId == null || _regionId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_role == UserRole.maanaim ? 'Selecione o Maanaim.' : 'Selecione a Região.')),
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

    Navigator.pop(
      context,
      _ApproveResult(
        role: _role,
        regionId: _showRegion ? _regionId : null,
        areaId: _showArea ? _areaId : null,
        poloId: _showPolo ? _poloId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 48,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            'Aprovar ${widget.displayName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserRole>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Papel (role)'),
            items: const [
              DropdownMenuItem(value: UserRole.readonly, child: Text('Leitura (readonly)')),
              DropdownMenuItem(value: UserRole.polo, child: Text('Polo')),
              DropdownMenuItem(value: UserRole.area, child: Text('Área')),
              DropdownMenuItem(value: UserRole.region, child: Text('Região')),
              DropdownMenuItem(value: UserRole.maanaim, child: Text('Maanaim')),
              DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
            ],
            onChanged: (r) => _onRoleChanged(r ?? UserRole.readonly),
          ),
          if (_showRegion) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _regionId,
              decoration: InputDecoration(labelText: _regionLabel),
              items: _role == UserRole.maanaim
                  ? _maanaims.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList()
                  : _regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
              onChanged: (v) {
                setState(() => _regionId = v);
                if (v != null && _showArea && _role != UserRole.maanaim) _loadAreas(v);
              },
            ),
          ],
          if (_showArea) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _areaId,
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
              value: _poloId,
              decoration: InputDecoration(
                labelText: _loadingPolos ? 'Carregando polos...' : 'Polo',
              ),
              items: _polos
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: _loadingPolos ? null : (v) => setState(() => _poloId = v),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Confirmar'),
              ),
            ),
          ]),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
