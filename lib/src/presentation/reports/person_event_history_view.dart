import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class PersonEventHistoryView extends StatelessWidget {
  final PersonSummary summary;
  final GeoNameResolver geo;
  const PersonEventHistoryView({super.key, required this.summary, required this.geo});

  @override
  Widget build(BuildContext context) {
    final events = summary.events;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Histórico de eventos', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: events.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'O membro não possui eventos previstos no período selecionado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF66717D)),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: events.length + 1,
              separatorBuilder: (_, i) {
                if (i >= events.length - 1) return const SizedBox.shrink();
                return const Divider(height: 1, thickness: 1, color: AppTheme.neutralLight);
              },
              itemBuilder: (_, i) {
                if (i == events.length) {
                  return ReportsListFooter(
                    text: '${events.length} evento${events.length == 1 ? '' : 's'}',
                  );
                }
                final item = events[i];
                return PersonEventHistoryTile(
                  item: item,
                  geo: geo,
                  onTap: () => openPersonEventAttendance(context, item.rehearsal.id),
                );
              },
            ),
    );
  }
}

class PersonEventHistoryTile extends StatelessWidget {
  final PersonEventMark item;
  final GeoNameResolver geo;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  const PersonEventHistoryTile({
    super.key,
    required this.item,
    required this.geo,
    required this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final location = (item.rehearsal.place ?? '').trim().isNotEmpty
        ? item.rehearsal.place!
        : geo.levelName(item.rehearsal);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            ReportDateBlock(date: item.rehearsal.dateTime),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportEventTypeBadge(type: item.rehearsal.eventType),
                  const SizedBox(height: 4),
                  Text(
                    item.rehearsal.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF66717D)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF66717D), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AttendanceStatusBadge(status: item.status),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF66717D), size: 22),
          ],
        ),
      ),
    );
  }
}

void openPersonEventAttendance(BuildContext context, String rehearsalId) {
  final authRepo = context.read<IAuthRepository>();
  final currentUserId = authRepo.currentUserId ?? '';
  if (currentUserId.isEmpty) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) {
    return BlocProvider(
      create: (ctx) => AttendanceController(
        rehearsalRepo: context.read<IRehearsalRepository>(),
        personRepo: context.read<IPersonRepository>(),
        attendanceRepo: context.read<IAttendanceRepository>(),
        rehearsalId: rehearsalId,
        currentUserId: currentUserId,
      ),
      child: AttendanceView(rehearsalId: rehearsalId, currentUserId: currentUserId),
    );
  }));
}
