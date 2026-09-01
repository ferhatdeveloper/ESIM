import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/checkout/checkout_page.dart';
import '../../features/countries/country_plans_page.dart';
import '../../features/esims/esim_detail_page.dart';
import '../../features/esims/my_esims_page.dart';
import '../../features/explore/explore_page.dart';
import '../../features/home/home_page.dart';
import '../../features/installation/installation_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/orders/orders_page.dart';
import '../../features/plans/plan_detail_page.dart';
import '../../features/profile/profile_page.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/app_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final boot = ref.watch(bootstrapProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: GoRouterRefresh(ref),
    redirect: (context, state) {
      if (boot.isLoading) return null;
      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final authRoute = loc == '/login' || loc == '/register' || loc == '/reset';
      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && authRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
      GoRoute(path: '/reset', builder: (c, s) => const ResetPasswordPage()),
      GoRoute(
        path: '/plans/:id',
        builder: (c, s) => PlanDetailPage(planId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/countries/:id',
        builder: (c, s) => CountryPlansPage(
          countryId: s.pathParameters['id']!,
          title: s.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/regions/:id',
        builder: (c, s) => CountryPlansPage(
          regionId: s.pathParameters['id']!,
          title: s.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/checkout/:planId',
        builder: (c, s) => CheckoutPage(planId: s.pathParameters['planId']!),
      ),
      GoRoute(
        path: '/esims/:id',
        builder: (c, s) => EsimDetailPage(esimId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/esims/:id/install',
        builder: (c, s) => InstallationPage(esimId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (c, s) => const ExplorePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/esims', builder: (c, s) => const MyEsimsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (c, s) => const OrdersPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfilePage())]),
        ],
      ),
    ],
  );
});

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
    ref.listen(bootstrapProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
