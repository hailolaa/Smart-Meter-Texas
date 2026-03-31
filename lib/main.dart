import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/session/smt_session_store.dart';
import 'core/settings/app_settings_store.dart';
import 'core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/data/repositories/smt_auth_repository.dart';
import 'features/auth/presentation/bloc/auth_session_bloc.dart';
import 'features/auth/presentation/bloc/auth_session_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SmtSessionStore.instance.load();
  await AppSettingsStore.instance.load();
  runApp(const SmartMeterApp());
}

class SmartMeterApp extends StatefulWidget {
  const SmartMeterApp({super.key});

  @override
  State<SmartMeterApp> createState() => _SmartMeterAppState();
}

class _SmartMeterAppState extends State<SmartMeterApp> {
  late final AuthSessionBloc _authSessionBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authSessionBloc = AuthSessionBloc(repository: SmtAuthRepository())
      ..add(const AppStarted());
    _router = createAppRouter(_authSessionBloc);
  }

  @override
  void dispose() {
    _authSessionBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authSessionBloc,
      child: MaterialApp.router(
        title: 'Electric Today Smart Energy',
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}