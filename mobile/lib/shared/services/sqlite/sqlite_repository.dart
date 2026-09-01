import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/security/password_hasher.dart';
import '../../models/models.dart';
import '../esim_repository.dart';
import 'sqlite_database.dart';

class SqliteRepository implements EsimRepository {
  SqliteRepository._();

  static final instance = SqliteRepository._();

  factory SqliteRepository.forDb(Database db) {
    return SqliteRepository._().._db = db;
  }

  static const _uuid = Uuid();

  Database? _db;
  String? _userId;

  Database get db {
    final database = _db;
    if (database == null) {
      throw const AppException('SQLite is not initialized');
    }
    return database;
  }

  Future<void> init({String? path}) async {
    _db ??= await openEsimDatabase(path: path);
  }

  String get _uid {
    final id = _userId;
    if (id == null) throw const UnauthorizedException();
    return id;
  }

  Future<AuthSession> _issue(Map<String, Object?> user) async {
    _userId = user['id'] as String;
    final refresh = PasswordHasher.hash('refresh');
    final refreshHash = sha256.convert(refresh.codeUnits).toString();
    await db.insert('refresh_tokens', {
      'token_hash': refreshHash,
      'user_id': user['id'],
      'expires_at': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
    });
    return AuthSession(
      accessToken: 'sqlite.${user['id']}',
      refreshToken: refresh,
      expiresIn: 900,
      userId: user['id'] as String,
      email: user['email'] as String,
      fullName: user['full_name'] as String,
      locale: user['locale'] as String,
      preferredCurrency: user['preferred_currency'] as String,
      appRole: user['app_role'] as String,
    );
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty || !PasswordHasher.verify(password, rows.first['password_hash'] as String)) {
      throw const AppException('Invalid credentials');
    }
    return _issue(rows.first);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String locale,
    required String currency,
  }) async {
    if (!email.contains('@') || password.length < 8 || fullName.trim().isEmpty) {
      throw const AppException('Invalid registration data');
    }
    final id = _uuid.v4();
    try {
      await db.insert('users', {
        'id': id,
        'email': email.trim().toLowerCase(),
        'password_hash': PasswordHasher.hash(password),
        'full_name': fullName.trim(),
        'locale': locale,
        'preferred_currency': currency,
        'app_role': 'customer',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AppException('Email already registered');
      }
      rethrow;
    }
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return _issue(rows.first);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final hash = sha256.convert(refreshToken.codeUnits).toString();
    final tokens = await db.query(
      'refresh_tokens',
      where: 'token_hash = ? AND revoked_at IS NULL AND expires_at > ?',
      whereArgs: [hash, DateTime.now().toUtc().toIso8601String()],
    );
    if (tokens.isEmpty) throw const UnauthorizedException();
    await db.update('refresh_tokens', {'revoked_at': DateTime.now().toUtc().toIso8601String()}, where: 'token_hash = ?', whereArgs: [hash]);
    final users = await db.query('users', where: 'id = ?', whereArgs: [tokens.first['user_id']]);
    if (users.isEmpty) throw const UnauthorizedException();
    return _issue(users.first);
  }

  @override
  Future<void> logout(String refreshToken) async {
    final hash = sha256.convert(refreshToken.codeUnits).toString();
    await db.update('refresh_tokens', {'revoked_at': DateTime.now().toUtc().toIso8601String()}, where: 'token_hash = ?', whereArgs: [hash]);
    _userId = null;
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty) return {'ok': true, 'delivery': 'none'};
    final raw = _uuid.v4().replaceAll('-', '');
    await db.insert('password_reset_tokens', {
      'token_hash': sha256.convert(raw.codeUnits).toString(),
      'user_id': rows.first['id'],
      'expires_at': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
    });
    return {'ok': true, 'delivery': 'development_response_only', 'reset_token': raw};
  }

  @override
  Future<void> resetPassword(String token, String password) async {
    if (password.length < 8) throw const AppException('Password must be at least 8 characters');
    final hash = sha256.convert(token.codeUnits).toString();
    final rows = await db.query(
      'password_reset_tokens',
      where: 'token_hash = ? AND used_at IS NULL AND expires_at > ?',
      whereArgs: [hash, DateTime.now().toUtc().toIso8601String()],
    );
    if (rows.isEmpty) throw const AppException('Invalid or expired reset token');
    await db.update('users', {'password_hash': PasswordHasher.hash(password)}, where: 'id = ?', whereArgs: [rows.first['user_id']]);
    await db.update('password_reset_tokens', {'used_at': DateTime.now().toUtc().toIso8601String()}, where: 'token_hash = ?', whereArgs: [hash]);
  }

  @override
  Future<List<Country>> fetchCountries({bool popularOnly = false}) async {
    final rows = await db.query(
      'countries',
      where: popularOnly ? 'is_popular = 1' : null,
      orderBy: 'sort_order ASC',
    );
    return rows.map(_country).toList();
  }

  @override
  Future<List<Region>> fetchRegions() async {
    final rows = await db.query('regions', orderBy: 'sort_order ASC');
    return rows.map(_region).toList();
  }

  @override
  Future<List<MarketplacePlan>> fetchPlans({
    String? countryId,
    String? regionId,
    bool featuredOnly = false,
    String? search,
    int offset = 0,
    int limit = 40,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (countryId != null) {
      where.add('p.country_id = ?');
      args.add(countryId);
    }
    if (regionId != null) {
      where.add('p.region_id = ?');
      args.add(regionId);
    }
    if (featuredOnly) where.add('p.is_featured = 1');
    if (search != null && search.trim().isNotEmpty) {
      where.add('(p.name_en LIKE ? OR c.name_en LIKE ? OR r.name_en LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q, q]);
    }
    final sql = '''
      SELECT p.*, c.name_en AS country_name_en, c.name_tr AS country_name_tr, c.name_ar AS country_name_ar,
             c.flag_emoji, r.name_en AS region_name_en
      FROM esim_plans p
      LEFT JOIN countries c ON c.id = p.country_id
      LEFT JOIN regions r ON r.id = p.region_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.sort_order ASC
      LIMIT ? OFFSET ?
    ''';
    final rows = await db.rawQuery(sql, [...args, limit, offset]);
    final plans = <MarketplacePlan>[];
    for (final row in rows) {
      plans.add(await _plan(row));
    }
    return plans;
  }

  @override
  Future<MarketplacePlan> fetchPlan(String id) async {
    final items = await fetchPlans(limit: 200);
    return items.firstWhere((e) => e.id == id, orElse: () => throw const EmptyException());
  }

  @override
  Future<UserProfile> fetchMe() async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [_uid]);
    if (rows.isEmpty) throw const EmptyException();
    return _profile(rows.first);
  }

  @override
  Future<UserProfile> updateProfile({String? fullName, String? locale, String? currency}) async {
    final patch = <String, Object?>{};
    if (fullName != null && fullName.trim().isNotEmpty) patch['full_name'] = fullName.trim();
    if (locale != null) patch['locale'] = locale;
    if (currency != null) patch['preferred_currency'] = currency;
    if (patch.isNotEmpty) {
      await db.update('users', patch, where: 'id = ?', whereArgs: [_uid]);
    }
    return fetchMe();
  }

  @override
  Future<List<UserEsim>> fetchEsims() async {
    final rows = await _esimRows(where: 'e.user_id = ?', args: [_uid]);
    return rows.map(_esim).toList();
  }

  @override
  Future<UserEsim> fetchEsim(String id) async {
    final rows = await _esimRows(where: 'e.user_id = ? AND e.id = ?', args: [_uid, id]);
    if (rows.isEmpty) throw const EmptyException();
    return _esim(rows.first);
  }

  @override
  Future<List<EsimUsage>> fetchUsage(String esimId) async {
    final owned = await db.query('user_esims', where: 'id = ? AND user_id = ?', whereArgs: [esimId, _uid]);
    if (owned.isEmpty) return const [];
    final rows = await db.query('esim_usage', where: 'esim_id = ?', whereArgs: [esimId], orderBy: 'created_at DESC');
    return rows.map(_usage).toList();
  }

  @override
  Future<List<Order>> fetchOrders() async {
    final rows = await db.rawQuery('''
      SELECT o.*, i.plan_id, p.name_en AS plan_name_en, p.data_amount_mb, p.validity_days,
             c.name_en AS destination_en, c.flag_emoji, pay.status AS payment_status,
             e.id AS esim_id, e.status AS esim_status
      FROM orders o
      JOIN order_items i ON i.order_id = o.id
      JOIN esim_plans p ON p.id = i.plan_id
      LEFT JOIN countries c ON c.id = p.country_id
      LEFT JOIN payments pay ON pay.order_id = o.id
      LEFT JOIN user_esims e ON e.order_id = o.id
      WHERE o.user_id = ?
      ORDER BY o.created_at DESC
    ''', [_uid]);
    return rows.map(_order).toList();
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await db.query('notifications', where: 'user_id = ?', whereArgs: [_uid], orderBy: 'created_at DESC');
    return rows.map(_notification).toList();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await db.update('notifications', {'is_read': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, _uid]);
  }

  @override
  Future<CheckoutQuote> createCheckout({
    required String planId,
    required String currency,
    String? idempotencyKey,
  }) async {
    final key = (idempotencyKey == null || idempotencyKey.isEmpty) ? _uuid.v4() : idempotencyKey;
    return db.transaction((txn) async {
      final existing = await txn.query('orders', where: 'user_id = ? AND idempotency_key = ?', whereArgs: [_uid, key]);
      if (existing.isNotEmpty) {
        return _quoteFromOrder(txn, existing.first);
      }
      final plans = await txn.rawQuery('''
        SELECT p.*, c.name_en AS country_name_en, r.name_en AS region_name_en
        FROM esim_plans p
        LEFT JOIN countries c ON c.id = p.country_id
        LEFT JOIN regions r ON r.id = p.region_id
        WHERE p.id = ?
      ''', [planId]);
      if (plans.isEmpty) throw const AppException('Plan not available');
      final prices = await txn.query('plan_prices', where: 'plan_id = ? AND currency = ?', whereArgs: [planId, currency]);
      if (prices.isEmpty) throw const AppException('Price not available for currency');
      final amount = (prices.first['amount'] as num).toDouble();
      final orderId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('orders', {
        'id': orderId,
        'user_id': _uid,
        'status': 'pending_payment',
        'currency': currency,
        'subtotal': amount,
        'tax': 0,
        'fees': 0,
        'total': amount,
        'idempotency_key': key,
        'created_at': now,
      });
      await txn.insert('order_items', {
        'order_id': orderId,
        'plan_id': planId,
        'unit_price': amount,
        'currency': currency,
      });
      await txn.insert('payments', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'provider': 'mock',
        'status': 'pending',
        'amount': amount,
        'currency': currency,
      });
      final plan = plans.first;
      return CheckoutQuote(
        orderId: orderId,
        planId: planId,
        destination: (plan['country_name_en'] as String?) ?? (plan['region_name_en'] as String?) ?? 'eSIM',
        planName: plan['name_en'] as String,
        dataAmountMb: (plan['data_amount_mb'] as num).toInt(),
        validityDays: (plan['validity_days'] as num).toInt(),
        currency: currency,
        subtotal: amount,
        tax: 0,
        fees: 0,
        total: amount,
        paymentMode: 'mock',
      );
    });
  }

  @override
  Future<PurchaseResult> confirmMockPayment({required String orderId, bool succeed = true}) async {
    return db.transaction((txn) async {
      final orders = await txn.query('orders', where: 'id = ? AND user_id = ?', whereArgs: [orderId, _uid]);
      if (orders.isEmpty) throw const AppException('Order not found');
      final existing = await txn.query('user_esims', where: 'order_id = ?', whereArgs: [orderId]);
      if (existing.isNotEmpty) {
        final esim = existing.first;
        return PurchaseResult(
          orderId: orderId,
          orderStatus: orders.first['status'] as String,
          paymentStatus: 'captured',
          isMockProvisioning: true,
          message: 'Already provisioned for this order',
          esimId: esim['id'] as String,
          esimStatus: esim['status'] as String,
        );
      }
      if (!succeed) {
        await txn.update('payments', {'status': 'failed'}, where: 'order_id = ?', whereArgs: [orderId]);
        await txn.update('orders', {'status': 'failed'}, where: 'id = ?', whereArgs: [orderId]);
        await _notify(txn, _uid, 'payment_failed', 'Payment failed', 'Ödeme başarısız', 'فشل الدفع', 'The mock payment did not capture. No eSIM was created.', 'Sahte ödeme alınamadı. eSIM oluşturulmadı.', 'لم يتم التقاط الدفع التجريبي. لم تُنشأ شريحة.');
        return PurchaseResult(
          orderId: orderId,
          orderStatus: 'failed',
          paymentStatus: 'failed',
          isMockProvisioning: true,
          message: 'Mock payment failed; no eSIM created',
        );
      }
      await txn.update('payments', {'status': 'captured'}, where: 'order_id = ?', whereArgs: [orderId]);
      await txn.update('orders', {'status': 'paid'}, where: 'id = ?', whereArgs: [orderId]);
      final items = await txn.rawQuery('''
        SELECT p.* FROM order_items i JOIN esim_plans p ON p.id = i.plan_id WHERE i.order_id = ?
      ''', [orderId]);
      final plan = items.first;
      final esimId = _uuid.v4();
      final short = orderId.replaceAll('-', '').substring(0, 12).toUpperCase();
      final expires = DateTime.now().toUtc().add(Duration(days: (plan['validity_days'] as num).toInt()));
      await txn.insert('user_esims', {
        'id': esimId,
        'user_id': _uid,
        'order_id': orderId,
        'plan_id': plan['id'],
        'iccid': 'MOCK-ICCID-$short',
        'smdp_address': 'mock-smdp.example.invalid',
        'activation_code': 'MOCK-ACT-$short',
        'confirmation_code': 'MOCK-CONF-${short.substring(0, 6)}',
        'original_balance': plan['data_amount_mb'],
        'remaining_balance': plan['data_amount_mb'],
        'balance_unit': 'MB',
        'status': 'ready',
        'expires_at': expires.toIso8601String(),
        'is_mock': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.update('orders', {'status': 'completed'}, where: 'id = ?', whereArgs: [orderId]);
      await _notify(txn, _uid, 'esim_ready', 'Your eSIM is ready', 'eSIM\'iniz hazır', 'شريحة eSIM جاهزة', 'Install the eSIM from My eSIMs. This is a one-time product with its own balance.', 'eSIM\'i eSIM\'lerim ekranından kurun.', 'ثبّت الشريحة من شاشتي.');
      return PurchaseResult(
        orderId: orderId,
        orderStatus: 'completed',
        paymentStatus: 'captured',
        isMockProvisioning: true,
        message: 'Mock provisioning completed; not a live carrier profile',
        esimId: esimId,
        esimStatus: 'ready',
      );
    });
  }

  @override
  Future<void> activateEsim(String esimId) async {
    final rows = await db.query('user_esims', where: 'id = ? AND user_id = ?', whereArgs: [esimId, _uid]);
    if (rows.isEmpty) throw const EmptyException();
    final status = rows.first['status'] as String;
    if (status == 'active') return;
    if (status != 'ready') throw const AppException('eSIM is not ready for activation');
    await db.update('user_esims', {
      'status': 'active',
      'activated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'id = ?', whereArgs: [esimId]);
  }

  @override
  Future<void> applyEsimUsage({
    required String esimId,
    required double usageAmount,
    String source = 'mock_sync',
  }) async {
    if (usageAmount <= 0) throw const AppException('usage_amount must be positive');
    await db.transaction((txn) async {
      final rows = await txn.query('user_esims', where: 'id = ? AND user_id = ?', whereArgs: [esimId, _uid]);
      if (rows.isEmpty) throw const EmptyException();
      final esim = rows.first;
      final status = esim['status'] as String;
      if (status != 'ready' && status != 'active') {
        throw const AppException('Usage cannot be applied in the current eSIM state');
      }
      final before = (esim['remaining_balance'] as num).toDouble();
      final after = (before - usageAmount).clamp(0, before).toDouble();
      final nextStatus = after == 0 ? 'depleted' : (status == 'ready' ? 'active' : status);
      await txn.update('user_esims', {
        'remaining_balance': after,
        'status': nextStatus,
        'activated_at': esim['activated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      }, where: 'id = ?', whereArgs: [esimId]);
      await txn.insert('esim_usage', {
        'id': _uuid.v4(),
        'esim_id': esimId,
        'usage_amount': usageAmount,
        'balance_before': before,
        'balance_after': after,
        'source': source,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> _esimRows({required String where, required List<Object> args}) {
    return db.rawQuery('''
      SELECT e.*, p.name_en AS plan_name_en, p.name_tr AS plan_name_tr, p.name_ar AS plan_name_ar,
             p.data_amount_mb, p.validity_days,
             COALESCE(c.name_en, r.name_en) AS destination_en,
             COALESCE(c.name_tr, r.name_tr) AS destination_tr,
             COALESCE(c.name_ar, r.name_ar) AS destination_ar,
             c.flag_emoji
      FROM user_esims e
      JOIN esim_plans p ON p.id = e.plan_id
      LEFT JOIN countries c ON c.id = p.country_id
      LEFT JOIN regions r ON r.id = p.region_id
      WHERE $where
      ORDER BY e.created_at DESC
    ''', args);
  }

  Future<CheckoutQuote> _quoteFromOrder(Transaction txn, Map<String, Object?> order) async {
    final items = await txn.rawQuery('''
      SELECT p.*, c.name_en AS country_name_en, r.name_en AS region_name_en
      FROM order_items i
      JOIN esim_plans p ON p.id = i.plan_id
      LEFT JOIN countries c ON c.id = p.country_id
      LEFT JOIN regions r ON r.id = p.region_id
      WHERE i.order_id = ?
    ''', [order['id']]);
    final plan = items.first;
    return CheckoutQuote(
      orderId: order['id'] as String,
      planId: plan['id'] as String,
      destination: (plan['country_name_en'] as String?) ?? (plan['region_name_en'] as String?) ?? 'eSIM',
      planName: plan['name_en'] as String,
      dataAmountMb: (plan['data_amount_mb'] as num).toInt(),
      validityDays: (plan['validity_days'] as num).toInt(),
      currency: order['currency'] as String,
      subtotal: (order['subtotal'] as num).toDouble(),
      tax: (order['tax'] as num).toDouble(),
      fees: (order['fees'] as num).toDouble(),
      total: (order['total'] as num).toDouble(),
      paymentMode: 'mock',
    );
  }

  Future<void> _notify(
    DatabaseExecutor txn,
    String userId,
    String type,
    String titleEn,
    String titleTr,
    String titleAr,
    String bodyEn,
    String bodyTr,
    String bodyAr,
  ) {
    return txn.insert('notifications', {
      'id': _uuid.v4(),
      'user_id': userId,
      'type': type,
      'title_en': titleEn,
      'title_tr': titleTr,
      'title_ar': titleAr,
      'body_en': bodyEn,
      'body_tr': bodyTr,
      'body_ar': bodyAr,
      'is_read': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<MarketplacePlan> _plan(Map<String, Object?> row) async {
    final prices = await db.query('plan_prices', where: 'plan_id = ?', whereArgs: [row['id']]);
    return MarketplacePlan(
      id: row['id'] as String,
      countryId: row['country_id'] as String?,
      regionId: row['region_id'] as String?,
      nameEn: row['name_en'] as String,
      nameTr: row['name_tr'] as String,
      nameAr: row['name_ar'] as String,
      dataAmountMb: (row['data_amount_mb'] as num).toInt(),
      validityDays: (row['validity_days'] as num).toInt(),
      isFeatured: (row['is_featured'] as int) == 1,
      prices: prices
          .map((e) => PlanPrice(currency: e['currency'] as String, amount: (e['amount'] as num).toDouble()))
          .toList(),
      countryNameEn: row['country_name_en'] as String?,
      countryNameTr: row['country_name_tr'] as String?,
      countryNameAr: row['country_name_ar'] as String?,
      flagEmoji: row['flag_emoji'] as String?,
      regionNameEn: row['region_name_en'] as String?,
    );
  }

  Country _country(Map<String, Object?> row) => Country(
        id: row['id'] as String,
        iso2: row['iso2'] as String,
        nameEn: row['name_en'] as String,
        nameTr: row['name_tr'] as String,
        nameAr: row['name_ar'] as String,
        flagEmoji: row['flag_emoji'] as String,
        isPopular: (row['is_popular'] as int) == 1,
      );

  Region _region(Map<String, Object?> row) => Region(
        id: row['id'] as String,
        slug: row['slug'] as String,
        nameEn: row['name_en'] as String,
        nameTr: row['name_tr'] as String,
        nameAr: row['name_ar'] as String,
        isPopular: (row['is_popular'] as int) == 1,
      );

  UserProfile _profile(Map<String, Object?> row) => UserProfile(
        id: row['id'] as String,
        email: row['email'] as String,
        fullName: row['full_name'] as String,
        locale: row['locale'] as String,
        preferredCurrency: row['preferred_currency'] as String,
        phone: row['phone'] as String?,
        appRole: row['app_role'] as String,
      );

  UserEsim _esim(Map<String, Object?> row) {
    final status = row['status'] as String;
    final showInstall = status == 'ready' || status == 'active';
    return UserEsim(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      status: status,
      originalBalance: (row['original_balance'] as num).toDouble(),
      remainingBalance: (row['remaining_balance'] as num).toDouble(),
      balanceUnit: row['balance_unit'] as String,
      isMock: (row['is_mock'] as int) == 1,
      planNameEn: row['plan_name_en'] as String? ?? '',
      planNameTr: row['plan_name_tr'] as String? ?? '',
      planNameAr: row['plan_name_ar'] as String? ?? '',
      destinationEn: row['destination_en'] as String? ?? '',
      destinationTr: row['destination_tr'] as String? ?? '',
      destinationAr: row['destination_ar'] as String? ?? '',
      dataAmountMb: (row['data_amount_mb'] as num?)?.toInt() ?? 0,
      validityDays: (row['validity_days'] as num?)?.toInt() ?? 0,
      flagEmoji: row['flag_emoji'] as String?,
      activatedAt: _dt(row['activated_at']),
      expiresAt: _dt(row['expires_at']),
      iccid: showInstall ? row['iccid'] as String? : null,
      smdpAddress: showInstall ? row['smdp_address'] as String? : null,
      activationCode: showInstall ? row['activation_code'] as String? : null,
      confirmationCode: showInstall ? row['confirmation_code'] as String? : null,
    );
  }

  Order _order(Map<String, Object?> row) => Order(
        id: row['id'] as String,
        status: row['status'] as String,
        currency: row['currency'] as String,
        total: (row['total'] as num).toDouble(),
        subtotal: (row['subtotal'] as num).toDouble(),
        tax: (row['tax'] as num).toDouble(),
        fees: (row['fees'] as num).toDouble(),
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
        planNameEn: row['plan_name_en'] as String? ?? '',
        dataAmountMb: (row['data_amount_mb'] as num?)?.toInt() ?? 0,
        validityDays: (row['validity_days'] as num?)?.toInt() ?? 0,
        destinationEn: row['destination_en'] as String?,
        flagEmoji: row['flag_emoji'] as String?,
        esimId: row['esim_id'] as String?,
        esimStatus: row['esim_status'] as String?,
        paymentStatus: row['payment_status'] as String?,
      );

  AppNotification _notification(Map<String, Object?> row) => AppNotification(
        id: row['id'] as String,
        type: row['type'] as String,
        titleEn: row['title_en'] as String,
        titleTr: row['title_tr'] as String,
        titleAr: row['title_ar'] as String,
        bodyEn: row['body_en'] as String,
        bodyTr: row['body_tr'] as String,
        bodyAr: row['body_ar'] as String,
        isRead: (row['is_read'] as int) == 1,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  EsimUsage _usage(Map<String, Object?> row) => EsimUsage(
        id: row['id'] as String,
        usageAmount: (row['usage_amount'] as num).toDouble(),
        balanceBefore: (row['balance_before'] as num).toDouble(),
        balanceAfter: (row['balance_after'] as num).toDouble(),
        source: row['source'] as String,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  DateTime? _dt(Object? value) => value is String ? DateTime.tryParse(value) : null;
}
