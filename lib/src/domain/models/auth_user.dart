import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isEmailVerified;
  final bool isAnonymous;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isEmailVerified = false,
    this.isAnonymous = false,
  });

  @override
  List<Object?> get props => [uid, email, displayName, isEmailVerified, isAnonymous];
}
