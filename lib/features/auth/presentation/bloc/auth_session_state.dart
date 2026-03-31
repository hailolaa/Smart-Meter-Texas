import 'package:equatable/equatable.dart';

abstract class AuthSessionState extends Equatable {
  const AuthSessionState();

  @override
  List<Object?> get props => [];
}

class AuthUnknown extends AuthSessionState {
  const AuthUnknown();
}

class AuthLoading extends AuthSessionState {
  const AuthLoading();
}

class Authenticated extends AuthSessionState {
  const Authenticated({
    required this.sessionId,
    this.defaultEsiid,
  });

  final String sessionId;
  final String? defaultEsiid;

  @override
  List<Object?> get props => [sessionId, defaultEsiid];
}

class Unauthenticated extends AuthSessionState {
  const Unauthenticated({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}