import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class EventParticipantsPickerArgs {
  final RehearsalLevel level;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final Set<String> selectedIds;

  const EventParticipantsPickerArgs({
    required this.level,
    required this.regionId,
    this.areaId,
    this.poloId,
    required this.selectedIds,
  });
}

Future<Set<String>?> openEventParticipantsPicker(
  BuildContext context,
  EventParticipantsPickerArgs args,
) {
  return Navigator.push<Set<String>>(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (ctx) => EventParticipantsPickerController(
          resolver: EventParticipantsResolver(ctx.read<IPersonRepository>()),
          level: args.level,
          regionId: args.regionId,
          areaId: args.areaId,
          poloId: args.poloId,
          initialSelectedIds: args.selectedIds,
        )..load(),
        child: const EventParticipantsPickerView(),
      ),
    ),
  );
}

class EventParticipantsPickerView extends StatefulWidget {
  const EventParticipantsPickerView({super.key});

  @override
  State<EventParticipantsPickerView> createState() => _EventParticipantsPickerViewState();
}

class _EventParticipantsPickerViewState extends State<EventParticipantsPickerView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmPop(EventParticipantsPickerController c) async {
    if (!c.state.hasChanges) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'As alterações realizadas na seleção de participantes não foram confirmadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar editando')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descartar')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<EventParticipantsPickerController>();
    final geo = context.read<GeoNameResolver>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmPop(c) && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gerenciar participantes', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        bottomNavigationBar: SafeArea(
          child: BlocBuilder<EventParticipantsPickerController, EventParticipantsPickerState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.selectedIds.length} participantes selecionados',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (await _confirmPop(c) && context.mounted) Navigator.pop(context);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Cancelar'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, Set<String>.from(state.selectedIds)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Confirmar'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: BlocBuilder<EventParticipantsPickerController, EventParticipantsPickerState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: c.load, child: const Text('Tentar novamente')),
                    ],
                  ),
                ),
              );
            }

            final visible = c.visibleMembers;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: c.setSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por nome, instrumento ou função...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: state.search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                c.setSearch('');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: state.members.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Não há membros disponíveis para a estrutura selecionada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                      : visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhum membro encontrado.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final p = visible[index];
                                final selected = state.selectedIds.contains(p.id);
                                final location = [
                                  if (p.poloId != null) geo.poloName(p.poloId) ?? p.poloId!,
                                  if (p.areaId != null) geo.areaName(p.areaId) ?? p.areaId!,
                                ].join(' • ');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => c.toggle(p.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: selected,
                                              onChanged: (_) => c.toggle(p.id),
                                            ),
                                            CircleAvatar(child: Text(_initials(p.fullName))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.fullName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                  if (p.roles.isNotEmpty)
                                                    Text(
                                                      p.roles.join(' • '),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                                                    ),
                                                  if (location.isNotEmpty)
                                                    Text(
                                                      location,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((e) => e[0])
      .join()
      .toUpperCase();
}
