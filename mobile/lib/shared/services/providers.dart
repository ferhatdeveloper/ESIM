import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/security/token_store.dart';
import '../models/models.dart';
import 'api_repository.dart';
import 'esim_repository.dart';
import 'sqlite/sqlite_repository.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

final currencyOverrideProvider = StateProvider<String?>((ref) => null);

class AuthState {
  const AuthState({this.session});

  final AuthSession? session;

  bool get isAuthenticated => session != null;
}

class AuthController extends Notifier<AuthState> {
  late TokenStore _store;
  late EsimRepository _api;

  @override
  AuthState build() {
    _store = ref.read(tokenStoreProvider);
    return const AuthState();
  }

  void attachApi(EsimRepository api) => _api = api;

  Future<void> restore() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      state = const AuthState();
      return;
    }
    try {
      final session = await _api.refresh(refresh);
      await _store.writeTokens(access: session.accessToken, refresh: session.refreshToken);
      state = AuthState(session: session);
      _syncPrefs(session);
    } catch (_) {
      await _store.clear();
      state = const AuthState();
    }
  }

  Future<bool> refreshSession() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null) return false;
    try {
      final session = await _api.refresh(refresh);
      await _store.writeTokens(access: session.accessToken, refresh: session.refreshToken);
      state = AuthState(session: session);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final session = await _api.login(email, password);
    await _accept(session);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String locale,
    required String currency,
  }) async {
    final session = await _api.register(
      email: email,
      password: password,
      fullName: fullName,
      locale: locale,
      currency: currency,
    );
    await _accept(session);
  }

  Future<void> logout() async {
    final refresh = await _store.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {}
    }
    await _store.clear();
    state = const AuthState();
  }

  Future<void> _accept(AuthSession session) async {
    await _store.writeTokens(access: session.accessToken, refresh: session.refreshToken);
    state = AuthState(session: session);
    _syncPrefs(session);
  }

  void _syncPrefs(AuthSession session) {
    ref.read(localeOverrideProvider.notifier).state = Locale(session.locale);
    ref.read(currencyOverrideProvider.notifier).state = session.preferredCurrency;
  }

  void dropSession() {
    state = const AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final dioClientProvider = Provider<DioClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final controller = ref.read(authControllerProvider.notifier);
  return DioClient(
    tokenStore: store,
    onRefresh: controller.refreshSession,
    onSessionLost: () async {
      await store.clear();
      controller.dropSession();
    },
  );
});

final apiRepositoryProvider = Provider<EsimRepository>((ref) {
  final EsimRepository api = AppConstants.useSqlite
      ? SqliteRepository.instance
      : ApiRepository(ref.watch(dioClientProvider));
  ref.read(authControllerProvider.notifier).attachApi(api);
  return api;
});

final bootstrapProvider = FutureProvider<void>((ref) async {
  final api = ref.read(apiRepositoryProvider);
  if (api is SqliteRepository) {
    await api.init();
  }
  ref.read(authControllerProvider.notifier).attachApi(api);
  await ref.read(authControllerProvider.notifier).restore();
});

final countriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchCountries();
});

final regionsProvider = FutureProvider.autoDispose<List<Region>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchRegions();
});

final featuredPlansProvider = FutureProvider.autoDispose<List<MarketplacePlan>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchPlans(featuredOnly: true, limit: 12);
});

final plansByCountryProvider = FutureProvider.autoDispose.family<List<MarketplacePlan>, String>((ref, countryId) {
  return ref.watch(apiRepositoryProvider).fetchPlans(countryId: countryId);
});

final plansByRegionProvider = FutureProvider.autoDispose.family<List<MarketplacePlan>, String>((ref, regionId) {
  return ref.watch(apiRepositoryProvider).fetchPlans(regionId: regionId);
});

final searchPlansProvider = FutureProvider.autoDispose.family<List<MarketplacePlan>, String>((ref, query) {
  if (query.trim().isEmpty) return const [];
  return ref.watch(apiRepositoryProvider).fetchPlans(search: query);
});

final planProvider = FutureProvider.autoDispose.family<MarketplacePlan, String>((ref, id) {
  return ref.watch(apiRepositoryProvider).fetchPlan(id);
});

final myEsimsProvider = FutureProvider.autoDispose<List<UserEsim>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchEsims();
});

final esimDetailProvider = FutureProvider.autoDispose.family<UserEsim, String>((ref, id) {
  return ref.watch(apiRepositoryProvider).fetchEsim(id);
});

final esimUsageProvider = FutureProvider.autoDispose.family<List<EsimUsage>, String>((ref, id) {
  return ref.watch(apiRepositoryProvider).fetchUsage(id);
});

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchOrders();
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(apiRepositoryProvider).fetchNotifications();
});

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(apiRepositoryProvider).fetchMe();
});

String currentCurrency(WidgetRef ref) {
  return ref.watch(currencyOverrideProvider) ??
      ref.watch(authControllerProvider).session?.preferredCurrency ??
      'USD';
}

String currentLocaleCode(WidgetRef ref) {
  return ref.watch(localeOverrideProvider)?.languageCode ??
      ref.watch(authControllerProvider).session?.locale ??
      'en';
}
