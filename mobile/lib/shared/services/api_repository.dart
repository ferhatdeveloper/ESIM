import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/dio_client.dart';
import '../models/models.dart';

class ApiRepository {
  ApiRepository(this._client);

  final DioClient _client;
  final _uuid = const Uuid();

  Dio get _dio => _client.dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw const AppException('Unexpected response');
  }

  Future<AuthSession> login(String email, String password) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      return AuthSession.fromJson(_map(res.data));
    });
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String locale,
    required String currency,
  }) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.register, data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'locale': locale,
        'preferred_currency': currency,
      });
      return AuthSession.fromJson(_map(res.data));
    });
  }

  Future<AuthSession> refresh(String refreshToken) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.refreshSession, data: {
        'refresh_token': refreshToken,
      });
      return AuthSession.fromJson(_map(res.data));
    });
  }

  Future<void> logout(String refreshToken) {
    return _guard(() async {
      await _dio.post(ApiConstants.logout, data: {'refresh_token': refreshToken});
    });
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.requestPasswordReset, data: {'email': email});
      return _map(res.data);
    });
  }

  Future<void> resetPassword(String token, String password) {
    return _guard(() async {
      await _dio.post(ApiConstants.resetPassword, data: {
        'reset_token': token,
        'new_password': password,
      });
    });
  }

  Future<List<Country>> fetchCountries({bool popularOnly = false}) {
    return _guard(() async {
      final res = await _dio.get(
        ApiConstants.countries,
        queryParameters: {
          'order': 'sort_order.asc',
          if (popularOnly) 'is_popular': 'eq.true',
        },
      );
      return _list(res.data).map(Country.fromJson).toList();
    });
  }

  Future<List<Region>> fetchRegions() {
    return _guard(() async {
      final res = await _dio.get(ApiConstants.regions, queryParameters: {'order': 'sort_order.asc'});
      return _list(res.data).map(Region.fromJson).toList();
    });
  }

  Future<List<MarketplacePlan>> fetchPlans({
    String? countryId,
    String? regionId,
    bool featuredOnly = false,
    String? search,
    int offset = 0,
    int limit = 40,
  }) {
    return _guard(() async {
      final params = <String, dynamic>{
        'order': 'sort_order.asc',
        'limit': limit,
        'offset': offset,
      };
      if (countryId != null) params['country_id'] = 'eq.$countryId';
      if (regionId != null) params['region_id'] = 'eq.$regionId';
      if (featuredOnly) params['is_featured'] = 'eq.true';
      if (search != null && search.trim().isNotEmpty) {
        final q = '*${search.trim()}*';
        params['or'] = '(name_en.ilike.$q,country_name_en.ilike.$q,region_name_en.ilike.$q)';
      }
      final res = await _dio.get(ApiConstants.marketplacePlans, queryParameters: params);
      return _list(res.data).map(MarketplacePlan.fromJson).toList();
    });
  }

  Future<MarketplacePlan> fetchPlan(String id) {
    return _guard(() async {
      final res = await _dio.get(
        ApiConstants.marketplacePlans,
        queryParameters: {'id': 'eq.$id'},
      );
      final items = _list(res.data);
      if (items.isEmpty) throw const EmptyException();
      return MarketplacePlan.fromJson(items.first);
    });
  }

  Future<UserProfile> fetchMe() {
    return _guard(() async {
      final res = await _dio.get(ApiConstants.me);
      return UserProfile.fromJson(_map(res.data));
    });
  }

  Future<UserProfile> updateProfile({String? fullName, String? locale, String? currency}) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.updateProfile, data: {
        if (fullName != null) 'full_name': fullName,
        if (locale != null) 'locale': locale,
        if (currency != null) 'preferred_currency': currency,
      });
      return UserProfile.fromJson(_map(res.data));
    });
  }

  Future<List<UserEsim>> fetchEsims() {
    return _guard(() async {
      final res = await _dio.get(ApiConstants.myEsims, queryParameters: {'order': 'created_at.desc'});
      return _list(res.data).map(UserEsim.fromJson).toList();
    });
  }

  Future<UserEsim> fetchEsim(String id) {
    return _guard(() async {
      final res = await _dio.get(ApiConstants.myEsims, queryParameters: {'id': 'eq.$id'});
      final items = _list(res.data);
      if (items.isEmpty) throw const EmptyException();
      return UserEsim.fromJson(items.first);
    });
  }

  Future<List<EsimUsage>> fetchUsage(String esimId) {
    return _guard(() async {
      final res = await _dio.get(
        ApiConstants.myEsimUsage,
        queryParameters: {'esim_id': 'eq.$esimId', 'order': 'created_at.desc'},
      );
      return _list(res.data).map(EsimUsage.fromJson).toList();
    });
  }

  Future<List<Order>> fetchOrders() {
    return _guard(() async {
      final res = await _dio.get(ApiConstants.myOrders, queryParameters: {'order': 'created_at.desc'});
      return _list(res.data).map(Order.fromJson).toList();
    });
  }

  Future<List<AppNotification>> fetchNotifications() {
    return _guard(() async {
      final res = await _dio.get(
        ApiConstants.myNotifications,
        queryParameters: {'order': 'created_at.desc'},
      );
      return _list(res.data).map(AppNotification.fromJson).toList();
    });
  }

  Future<void> markNotificationRead(String id) {
    return _guard(() async {
      await _dio.post(ApiConstants.markNotificationRead, data: {'notification_id': id});
    });
  }

  Future<CheckoutQuote> createCheckout({
    required String planId,
    required String currency,
    String? idempotencyKey,
  }) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.createCheckout, data: {
        'plan_id': planId,
        'currency': currency,
        'idempotency_key': idempotencyKey ?? _uuid.v4(),
      });
      return CheckoutQuote.fromJson(_map(res.data));
    });
  }

  Future<PurchaseResult> confirmMockPayment({required String orderId, bool succeed = true}) {
    return _guard(() async {
      final res = await _dio.post(ApiConstants.confirmMockPayment, data: {
        'order_id': orderId,
        'succeed': succeed,
      });
      return PurchaseResult.fromJson(_map(res.data));
    });
  }

  Future<void> activateEsim(String esimId) {
    return _guard(() async {
      await _dio.post(ApiConstants.activateEsim, data: {'esim_id': esimId});
    });
  }
}
