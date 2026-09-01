import '../models/models.dart';

abstract class EsimRepository {
  Future<AuthSession> login(String email, String password);

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String locale,
    required String currency,
  });

  Future<AuthSession> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  Future<Map<String, dynamic>> requestPasswordReset(String email);

  Future<void> resetPassword(String token, String password);

  Future<List<Country>> fetchCountries({bool popularOnly = false});

  Future<List<Region>> fetchRegions();

  Future<List<MarketplacePlan>> fetchPlans({
    String? countryId,
    String? regionId,
    bool featuredOnly = false,
    String? search,
    int offset = 0,
    int limit = 40,
  });

  Future<MarketplacePlan> fetchPlan(String id);

  Future<UserProfile> fetchMe();

  Future<UserProfile> updateProfile({String? fullName, String? locale, String? currency});

  Future<List<UserEsim>> fetchEsims();

  Future<UserEsim> fetchEsim(String id);

  Future<List<EsimUsage>> fetchUsage(String esimId);

  Future<List<Order>> fetchOrders();

  Future<List<AppNotification>> fetchNotifications();

  Future<void> markNotificationRead(String id);

  Future<CheckoutQuote> createCheckout({
    required String planId,
    required String currency,
    String? idempotencyKey,
  });

  Future<PurchaseResult> confirmMockPayment({required String orderId, bool succeed = true});

  Future<void> activateEsim(String esimId);

  Future<void> applyEsimUsage({
    required String esimId,
    required double usageAmount,
    String source,
  });
}
