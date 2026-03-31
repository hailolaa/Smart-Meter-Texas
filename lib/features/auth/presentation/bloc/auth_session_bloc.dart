import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../data/repositories/smt_auth_repository.dart';
import 'auth_session_event.dart';
import 'auth_session_state.dart';

class AuthSessionBloc extends Bloc<AuthSessionEvent, AuthSessionState> {
  AuthSessionBloc({required SmtAuthRepository repository})
      : _repository = repository,
        super(const AuthUnknown()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionCheckRequested>(_onSessionCheckRequested);
    on<SessionExpiredDetected>(_onSessionExpiredDetected);
  }

  final SmtAuthRepository _repository;

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthSessionState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.checkSession();
      if (session == null) {
        emit(const Unauthenticated());
        return;
      }
      emit(Authenticated(
        sessionId: session.sessionId,
        defaultEsiid: session.defaultEsiid,
      ));
    } catch (_) {
      await _repository.clearLocalSession();
      emit(const Unauthenticated(reason: 'Session expired. Please log in again.'));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.login(
        username: event.username,
        password: event.password,
        esiid: event.esiid,
      );
      emit(Authenticated(
        sessionId: session.sessionId,
        defaultEsiid: session.defaultEsiid,
      ));
    } on AppException catch (e) {
      emit(Unauthenticated(reason: loginMessageFor(e)));
    } catch (e) {
      final fallback = AppException(
        code: 'SMT_REQUEST_ERROR',
        message: e.toString(),
      );
      emit(Unauthenticated(reason: loginMessageFor(fallback)));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    emit(const AuthLoading());
    await _repository.logout();
    emit(const Unauthenticated());
  }

  Future<void> _onSessionCheckRequested(
    SessionCheckRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    try {
      final session = await _repository.checkSession();
      if (session == null) {
        emit(const Unauthenticated());
        return;
      }
      emit(Authenticated(
        sessionId: session.sessionId,
        defaultEsiid: session.defaultEsiid,
      ));
    } catch (_) {
      await _repository.clearLocalSession();
      emit(const Unauthenticated(reason: 'Session expired. Please log in again.'));
    }
  }

  Future<void> _onSessionExpiredDetected(
    SessionExpiredDetected event,
    Emitter<AuthSessionState> emit,
  ) async {
    await _repository.clearLocalSession();
    emit(const Unauthenticated(reason: 'Session expired. Please log in again.'));
  }
}