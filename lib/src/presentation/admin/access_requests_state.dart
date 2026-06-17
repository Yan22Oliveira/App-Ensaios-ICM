part of 'access_requests_controller.dart';

class AccessRequestsState extends Equatable {
  final bool loading;
  final bool working;
  final String? errorMessage;
  final List<AccessRequest> requests;

  const AccessRequestsState({
    required this.loading,
    required this.working,
    required this.requests,
    this.errorMessage,
  });

  const AccessRequestsState.loading()
      : loading = true,
        working = false,
        requests = const [],
        errorMessage = null;

  factory AccessRequestsState.loaded({required List<AccessRequest> requests}) =>
      AccessRequestsState(
        loading: false,
        working: false,
        requests: requests,
      );

  factory AccessRequestsState.error(String message) => AccessRequestsState(
    loading: false,
    working: false,
    requests: const [],
    errorMessage: message,
  );

  AccessRequestsState copy({
    bool? loading,
    bool? working,
    String? errorMessage,
    List<AccessRequest>? requests,
  }) =>
      AccessRequestsState(
        loading: loading ?? this.loading,
        working: working ?? this.working,
        requests: requests ?? this.requests,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [loading, working, errorMessage, requests];
}
