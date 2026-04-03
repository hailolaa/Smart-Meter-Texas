import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/welcome_back_screen.dart';
import '../../features/auth/presentation/screens/smt_signup_guide_screen.dart';
import '../../features/onboarding/presentation/screens/select_home_type_screen.dart';
import '../../features/onboarding/presentation/screens/choose_network_screen.dart';
import '../../features/onboarding/presentation/screens/meter_details.dart';
import '../../features/onboarding/presentation/screens/select_retail_provider_screen.dart';
import '../../features/monetization/presentation/screens/paywall_screen.dart';
import '../../features/monetization/presentation/screens/payment_method_screen.dart';
import '../../features/monetization/presentation/screens/setup_success_screen.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/providers/presentation/screens/providers_list_screen.dart';
import '../navigation/presentation/screens/main_scaffold.dart';
import 'app_routes.dart';
import '../router/go_router_refresh_stream.dart';
import '../settings/app_settings_store.dart';
import '../session/smt_session_store.dart';
import '../../features/auth/presentation/bloc/auth_session_bloc.dart';
import '../../features/auth/presentation/bloc/auth_session_state.dart';

String resolveAuthenticatedLandingRoute(AppSettingsStore settings) {
  if ((SmtSessionStore.instance.userRole ?? '').toLowerCase() == 'admin') {
    return AppRoutes.admin;
  }
  if (!settings.hasCompletedOnboarding) {
    return AppRoutes.homeType;
  }
  if (settings.isFreeTrialActive) {
    return AppRoutes.dashboard;
  }
  return AppRoutes.paywall;
}

GoRouter createAppRouter(AuthSessionBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isSignupGuideRoute =
          state.matchedLocation == AppRoutes.smtSignupGuide;
      final isPaymentRoute = state.matchedLocation == AppRoutes.payment;
      final isSuccessRoute = state.matchedLocation == AppRoutes.success;
      final isPublicRoute = isLoginRoute || isSignupGuideRoute;
      final isAuthenticated = authState is Authenticated;

      // Avoid redirect churn while app is checking session at startup.
      if (authState is! Authenticated && authState is! Unauthenticated) {
        return null;
      }

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isLoginRoute) {
        return resolveAuthenticatedLandingRoute(AppSettingsStore.instance);
      }

      if (isAuthenticated &&
          (isPaymentRoute || isSuccessRoute) &&
          AppSettingsStore.instance.isFreeTrialActive) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const WelcomeBackScreen(),
      ),
      GoRoute(
        path: AppRoutes.providers,
        builder: (context, state) => const ProvidersListScreen(),
      ),
      GoRoute(
        path: AppRoutes.smtSignupGuide,
        builder: (context, state) => const SmtSignupGuideScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeType,
        builder: (context, state) => const SelectHomeTypeScreen(),
      ),
      GoRoute(
        path: AppRoutes.network,
        builder: (context, state) => const ChooseNetworkScreen(),
      ),
      GoRoute(
        path: AppRoutes.meter,
        builder: (context, state) => const MeterDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.provider,
        builder: (context, state) => const SelectRetailProviderScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) => const PaymentMethodScreen(),
      ),
      GoRoute(
        path: AppRoutes.success,
        builder: (context, state) => const SetupSuccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminPanelScreen(),
      ),
    ],
  );
}
