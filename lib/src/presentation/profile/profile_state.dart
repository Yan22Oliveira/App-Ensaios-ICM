part of 'profile_controller.dart';

class ProfileState extends Equatable {
  final bool loading;
  final bool working; // salvando/ação em andamento
  final UserProfile? profile;
  final String? errorMessage;

  const ProfileState({
    required this.loading,
    required this.working,
    required this.profile,
    this.errorMessage,
  });

  const ProfileState.loading()
      : loading = true,
        working = false,
        profile = null,
        errorMessage = null;

  const ProfileState.error(this.errorMessage)
      : loading = false,
        working = false,
        profile = null;

  const ProfileState.loaded(this.profile)
      : loading = false,
        working = false,
        errorMessage = null;

  ProfileState copy({bool? loading, bool? working, UserProfile? profile, String? errorMessage}) {
    return ProfileState(
      loading: loading ?? this.loading,
      working: working ?? this.working,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [loading, working, profile?.uid, errorMessage];
}
