import 'package:bloc/bloc.dart';

import '../../src.dart';

class EventReportController extends Cubit<EventReportState> {
  final String eventId;
  final IRehearsalRepository rehearsalRepo;
  final IEventReportRepository reportRepo;
  final UserProfile? profile;

  EventReportController({
    required this.eventId,
    required this.rehearsalRepo,
    required this.reportRepo,
    this.profile,
  }) : super(EventReportState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearMessages: true));
    try {
      final event = await rehearsalRepo.getById(eventId);
      final report = await reportRepo.getByEventId(eventId);
      emit(state.copyWith(
        loading: false,
        event: event,
        report: report,
        editing: report?.status != EventReportStatus.finalized,
        clearMessages: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Falha ao carregar o relatório: $e',
        clearMessages: true,
      ));
    }
  }

  void startEditing() {
    if (state.event == null) return;
    emit(state.copyWith(editing: true, clearMessages: true));
  }

  Future<bool> saveDraft({
    required String title,
    String? responsible,
    required String overview,
    required String conclusion,
    String? notes,
  }) async {
    return _persist(
      title: title,
      responsible: responsible,
      overview: overview,
      conclusion: conclusion,
      notes: notes,
      status: EventReportStatus.draft,
      successMessage: 'Rascunho salvo',
      stayEditing: true,
    );
  }

  Future<bool> finalize({
    required String title,
    String? responsible,
    required String overview,
    required String conclusion,
    String? notes,
  }) async {
    final missing = <String>[];
    if (title.trim().isEmpty) missing.add('Título do relatório');
    if (overview.trim().isEmpty) missing.add('Panorama geral');
    if (conclusion.trim().isEmpty) missing.add('Conclusão');
    if (missing.isNotEmpty) {
      emit(state.copyWith(
        errorMessage: 'Preencha: ${missing.join(', ')}.',
        successMessage: null,
        clearMessages: true,
      ));
      return false;
    }

    return _persist(
      title: title,
      responsible: responsible,
      overview: overview,
      conclusion: conclusion,
      notes: notes,
      status: EventReportStatus.finalized,
      successMessage: 'Relatório finalizado',
      stayEditing: false,
    );
  }

  Future<bool> _persist({
    required String title,
    String? responsible,
    required String overview,
    required String conclusion,
    String? notes,
    required EventReportStatus status,
    required String successMessage,
    required bool stayEditing,
  }) async {
    if (state.event == null) return false;
    emit(state.copyWith(saving: true, clearMessages: true));
    try {
      final now = DateTime.now();
      final current = state.report;
      final report = EventReport(
        id: current?.id ?? eventId,
        eventId: eventId,
        title: title.trim(),
        responsible: _emptyToNull(responsible),
        overview: overview.trim(),
        conclusion: conclusion.trim(),
        notes: _emptyToNull(notes),
        status: status,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
        updatedByName: _emptyToNull(profile?.displayName),
      );
      final saved = await reportRepo.upsert(report);
      emit(state.copyWith(
        saving: false,
        report: saved,
        editing: stayEditing,
        successMessage: successMessage,
        clearMessages: true,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        saving: false,
        errorMessage: 'Não foi possível salvar: $e',
        clearMessages: true,
      ));
      return false;
    }
  }

  String? _emptyToNull(String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}
