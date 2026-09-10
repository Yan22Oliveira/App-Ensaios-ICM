import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../src.dart';

class ReportsFiltersDraft {
  EventType? eventType;
  String? regionId;
  String? areaId;
  String? poloId;
  bool onlyWithRecords;
  List<Region> regions;
  List<Area> areas;
  List<Polo> polos;

  ReportsFiltersDraft({
    required this.eventType,
    required this.regionId,
    required this.areaId,
    required this.poloId,
    required this.onlyWithRecords,
    required this.regions,
    required this.areas,
    required this.polos,
  });
}

Future<ReportsFiltersDraft?> showReportsFiltersSheet({
  required BuildContext context,
  required ReportsFiltersDraft initial,
  required bool lockRegion,
  required bool lockArea,
  required bool lockPolo,
}) {
  return showModalBottomSheet<ReportsFiltersDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _ReportsFiltersSheet(
      initial: initial,
      lockRegion: lockRegion,
      lockArea: lockArea,
      lockPolo: lockPolo,
    ),
  );
}

class _ReportsFiltersSheet extends StatefulWidget {
  final ReportsFiltersDraft initial;
  final bool lockRegion;
  final bool lockArea;
  final bool lockPolo;
  const _ReportsFiltersSheet({
    required this.initial,
    required this.lockRegion,
    required this.lockArea,
    required this.lockPolo,
  });

  @override
  State<_ReportsFiltersSheet> createState() => _ReportsFiltersSheetState();
}

class _ReportsFiltersSheetState extends State<_ReportsFiltersSheet> {
  late EventType? _eventType;
  late String? _regionId;
  late String? _areaId;
  late String? _poloId;
  late bool _onlyWithRecords;
  late List<Region> _regions;
  late List<Area> _areas;
  late List<Polo> _polos;

  @override
  void initState() {
    super.initState();
    _eventType = widget.initial.eventType;
    _regionId = widget.initial.regionId;
    _areaId = widget.initial.areaId;
    _poloId = widget.initial.poloId;
    _onlyWithRecords = widget.initial.onlyWithRecords;
    _regions = widget.initial.regions;
    _areas = widget.initial.areas;
    _polos = widget.initial.polos;
  }

  Future<void> _onRegion(String? v) async {
    setState(() {
      _regionId = v;
      _areaId = null;
      _poloId = null;
      _areas = const [];
      _polos = const [];
    });
    if (v != null) {
      final areas = await context.read<IGeoRepository>().areasByRegion(v);
      if (mounted) setState(() => _areas = areas);
    }
  }

  Future<void> _onArea(String? v) async {
    setState(() {
      _areaId = v;
      _poloId = null;
      _polos = const [];
    });
    if (v != null) {
      final polos = await context.read<IGeoRepository>().polosByArea(v);
      if (mounted) setState(() => _polos = polos);
    }
  }

  void _clear() {
    setState(() {
      _eventType = null;
      if (!widget.lockRegion) {
        _regionId = null;
        _areas = const [];
      }
      if (!widget.lockArea) {
        _areaId = null;
        _polos = const [];
      }
      if (!widget.lockPolo) _poloId = null;
      _onlyWithRecords = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 12),
          const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<EventType?>(
            value: _eventType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de evento'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ...EventType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))),
            ],
            onChanged: (v) => setState(() => _eventType = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _regionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Região'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ..._regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
            ],
            onChanged: widget.lockRegion ? null : _onRegion,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _areaId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Área'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ..._areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
            ],
            onChanged: widget.lockArea ? null : _onArea,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _poloId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Polo'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ..._polos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
            ],
            onChanged: widget.lockPolo ? null : (v) => setState(() => _poloId = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Somente com registros'),
            value: _onlyWithRecords,
            onChanged: (v) => setState(() => _onlyWithRecords = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Limpar filtros'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      ReportsFiltersDraft(
                        eventType: _eventType,
                        regionId: _regionId,
                        areaId: _areaId,
                        poloId: _poloId,
                        onlyWithRecords: _onlyWithRecords,
                        regions: _regions,
                        areas: _areas,
                        polos: _polos,
                      ),
                    );
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
