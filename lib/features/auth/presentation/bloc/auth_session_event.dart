import 'package:equatable/equatable.dart';

abstract class AuthSessionEvent extends Equatable {
  const AuthSessionEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthSessionEvent {
  const AppStarted();
}

class LoginRequested extends AuthSessionEvent {
  const LoginRequested({
    required this.username,
    required this.password,
    this.esiid,
  });

  final String username;
  final String password;
  final String? esiid;

  @override
  List<Object?> get props => [username, password, esiid];
}

class LogoutRequested extends AuthSessionEvent {
  const LogoutRequested();
}

class SessionCheckRequested extends AuthSessionEvent {
  const SessionCheckRequested();
}

class SessionExpiredDetected extends AuthSessionEvent {
  const SessionExpiredDetected();
}
