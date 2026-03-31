import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/features/auth/data/repositories/smt_auth_repository.dart';
import 'package:smart_meter_texas/features/auth/presentation/bloc/auth_session_bloc.dart';
import 'package:smart_meter_texas/features/auth/presentation/screens/welcome_back_screen.dart';

void main() {
  testWidgets('password field toggles visibility', (tester) async {
    final bloc = AuthSessionBloc(repository: SmtAuthRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: WelcomeBackScreen()),
      ),
    );

    TextField passwordField() =>
        tester.widgetList<TextField>(find.byType(TextField)).elementAt(1);
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('password-visibility-toggle')));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('Register here navigates to guide screen', (tester) async {
    final bloc = AuthSessionBloc(repository: SmtAuthRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: WelcomeBackScreen()),
      ),
    );

    await tester.tap(find.text('Register here'));
    await tester.pumpAndSettle();
    expect(find.text('SMT Account Setup'), findsOneWidget);
  });
}
