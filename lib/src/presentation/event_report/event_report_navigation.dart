import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

Future<void> openEventReport(BuildContext context, String eventId) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (ctx) => EventReportController(
          eventId: eventId,
          rehearsalRepo: ctx.read<IRehearsalRepository>(),
          reportRepo: ctx.read<IEventReportRepository>(),
          profile: ctx.read<AuthController>().state.profile,
        )..load(),
        child: const EventReportView(),
      ),
    ),
  );
}
