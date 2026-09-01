import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/security/password_hasher.dart';
import 'sqlite_schema.dart';

const demoUserId = '22222222-2222-2222-2222-222222222222';
const adminUserId = '33333333-3333-3333-3333-333333333333';

Future<String> defaultEsimDbPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'esim.db');
}

Future<Database> openEsimDatabase({String? path}) async {
  return openDatabase(
    path ?? await defaultEsimDbPath(),
    version: 1,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, version) async {
      await createEsimSchema(db);
      await seedEsimDatabase(db);
    },
  );
}

Future<void> seedEsimDatabase(Database db) async {
  const uuid = Uuid();
  final now = DateTime.now().toUtc().toIso8601String();

  await db.insert('users', {
    'id': demoUserId,
    'email': 'demo@esim.app',
    'password_hash': PasswordHasher.hash('Demo12345!'),
    'full_name': 'Demo Traveler',
    'locale': 'en',
    'preferred_currency': 'USD',
    'app_role': 'customer',
    'created_at': now,
  });
  await db.insert('users', {
    'id': adminUserId,
    'email': 'admin@esim.app',
    'password_hash': PasswordHasher.hash('Admin12345!'),
    'full_name': 'Platform Admin',
    'locale': 'en',
    'preferred_currency': 'USD',
    'app_role': 'admin',
    'created_at': now,
  });

  const countries = [
    ('TR', 'Turkey', 'Türkiye', 'تركيا', '🇹🇷', 1, 10),
    ('AE', 'United Arab Emirates', 'Birleşik Arap Emirlikleri', 'الإمارات', '🇦🇪', 1, 20),
    ('IQ', 'Iraq', 'Irak', 'العراق', '🇮🇶', 1, 30),
    ('SA', 'Saudi Arabia', 'Suudi Arabistan', 'السعودية', '🇸🇦', 1, 40),
    ('US', 'United States', 'Amerika Birleşik Devletleri', 'الولايات المتحدة', '🇺🇸', 1, 50),
    ('GB', 'United Kingdom', 'Birleşik Krallık', 'المملكة المتحدة', '🇬🇧', 1, 60),
    ('DE', 'Germany', 'Almanya', 'ألمانيا', '🇩🇪', 1, 70),
    ('FR', 'France', 'Fransa', 'فرنسا', '🇫🇷', 1, 80),
    ('IT', 'Italy', 'İtalya', 'إيطاليا', '🇮🇹', 1, 90),
    ('ES', 'Spain', 'İspanya', 'إسبانيا', '🇪🇸', 0, 100),
    ('JP', 'Japan', 'Japonya', 'اليابان', '🇯🇵', 1, 110),
    ('TH', 'Thailand', 'Tayland', 'تايلاند', '🇹🇭', 0, 120),
  ];

  final countryIds = <String, String>{};
  for (final c in countries) {
    final id = uuid.v4();
    countryIds[c.$1] = id;
    await db.insert('countries', {
      'id': id,
      'iso2': c.$1,
      'name_en': c.$2,
      'name_tr': c.$3,
      'name_ar': c.$4,
      'flag_emoji': c.$5,
      'is_popular': c.$6,
      'sort_order': c.$7,
    });
  }

  const regions = [
    ('europe', 'Europe', 'Avrupa', 'أوروبا', 1, 10),
    ('middle-east', 'Middle East', 'Orta Doğu', 'الشرق الأوسط', 1, 20),
    ('asia', 'Asia', 'Asya', 'آسيا', 1, 30),
    ('global', 'Global', 'Küresel', 'عالمي', 0, 40),
  ];
  final regionIds = <String, String>{};
  for (final r in regions) {
    final id = uuid.v4();
    regionIds[r.$1] = id;
    await db.insert('regions', {
      'id': id,
      'slug': r.$1,
      'name_en': r.$2,
      'name_tr': r.$3,
      'name_ar': r.$4,
      'is_popular': r.$5,
      'sort_order': r.$6,
    });
  }

  const amounts = [1024, 3072, 10240];
  const days = [7, 15, 30];
  const usd = [4.90, 9.90, 19.90];

  for (final entry in countryIds.entries) {
    final iso = entry.key;
    final countryId = entry.value;
    final country = countries.firstWhere((e) => e.$1 == iso);
    for (var i = 0; i < 3; i++) {
      final planId = uuid.v4();
      final gb = amounts[i] / 1024;
      await db.insert('esim_plans', {
        'id': planId,
        'country_id': countryId,
        'name_en': '${country.$2} – ${gb.toStringAsFixed(0)} GB – ${days[i]} Days',
        'name_tr': '${country.$3} – ${gb.toStringAsFixed(0)} GB – ${days[i]} Gün',
        'name_ar': '${country.$4} – ${gb.toStringAsFixed(0)} غيغابايت – ${days[i]} يوم',
        'data_amount_mb': amounts[i],
        'validity_days': days[i],
        'is_featured': (i == 2 && country.$6 == 1) ? 1 : 0,
        'sort_order': (i + 1) * 10,
      });
      await _insertPrices(db, planId, usd[i]);
    }
  }

  for (final entry in regionIds.entries) {
    final region = regions.firstWhere((e) => e.$1 == entry.key);
    final planId = uuid.v4();
    await db.insert('esim_plans', {
      'id': planId,
      'region_id': entry.value,
      'name_en': '${region.$2} – 10 GB – 30 Days',
      'name_tr': '${region.$3} – 10 GB – 30 Gün',
      'name_ar': '${region.$4} – 10 غيغابايت – 30 يوم',
      'data_amount_mb': 10240,
      'validity_days': 30,
      'is_featured': 1,
      'sort_order': 5,
    });
    await _insertPrices(db, planId, 29.90);
  }

  await seedUsableDemoEsims(db);
}

Future<void> seedUsableDemoEsims(Database db) async {
  const uuid = Uuid();
  final now = DateTime.now().toUtc();

  Future<Map<String, Object?>> planByIso(String iso2, int mb) async {
    final rows = await db.rawQuery('''
      SELECT p.id, p.data_amount_mb, p.validity_days
      FROM esim_plans p
      JOIN countries c ON c.id = p.country_id
      WHERE c.iso2 = ? AND p.data_amount_mb = ?
      LIMIT 1
    ''', [iso2, mb]);
    return rows.first;
  }

  Future<void> addUsable({
    required String iso2,
    required int mb,
    required String status,
    required double remaining,
    DateTime? activatedAt,
  }) async {
    final plan = await planByIso(iso2, mb);
    final orderId = uuid.v4();
    final esimId = uuid.v4();
    final short = orderId.replaceAll('-', '').substring(0, 12).toUpperCase();
    final priceRows = await db.query('plan_prices', where: 'plan_id = ? AND currency = ?', whereArgs: [plan['id'], 'USD']);
    final amount = (priceRows.first['amount'] as num).toDouble();
    await db.insert('orders', {
      'id': orderId,
      'user_id': demoUserId,
      'status': 'completed',
      'currency': 'USD',
      'subtotal': amount,
      'tax': 0,
      'fees': 0,
      'total': amount,
      'idempotency_key': 'seed-usable-$iso2-$mb-$status',
      'created_at': now.toIso8601String(),
    });
    await db.insert('order_items', {
      'order_id': orderId,
      'plan_id': plan['id'],
      'unit_price': amount,
      'currency': 'USD',
    });
    await db.insert('payments', {
      'id': uuid.v4(),
      'order_id': orderId,
      'provider': 'mock',
      'status': 'captured',
      'amount': amount,
      'currency': 'USD',
    });
    await db.insert('user_esims', {
      'id': esimId,
      'user_id': demoUserId,
      'order_id': orderId,
      'plan_id': plan['id'],
      'iccid': 'MOCK-ICCID-$short',
      'smdp_address': 'mock-smdp.example.invalid',
      'activation_code': 'MOCK-ACT-$short',
      'confirmation_code': 'MOCK-CONF-${short.substring(0, 6)}',
      'original_balance': plan['data_amount_mb'],
      'remaining_balance': remaining,
      'balance_unit': 'MB',
      'status': status,
      'activated_at': activatedAt?.toIso8601String(),
      'expires_at': now.add(Duration(days: (plan['validity_days'] as num).toInt())).toIso8601String(),
      'is_mock': 1,
      'created_at': now.toIso8601String(),
    });
    if (status == 'active' && remaining < (plan['data_amount_mb'] as num).toDouble()) {
      await db.insert('esim_usage', {
        'id': uuid.v4(),
        'esim_id': esimId,
        'usage_amount': (plan['data_amount_mb'] as num).toDouble() - remaining,
        'balance_before': plan['data_amount_mb'],
        'balance_after': remaining,
        'source': 'seed_sync',
        'created_at': now.toIso8601String(),
      });
    }
  }

  // Ready: installable, not yet on a device.
  await addUsable(iso2: 'TR', mb: 10240, status: 'ready', remaining: 10240);
  // Active: already in use, independent remaining balance.
  await addUsable(iso2: 'AE', mb: 10240, status: 'active', remaining: 6144, activatedAt: now.subtract(const Duration(days: 3)));
  await addUsable(iso2: 'IQ', mb: 3072, status: 'ready', remaining: 3072);
}

Future<void> _insertPrices(Database db, String planId, double usdAmount) async {
  await db.insert('plan_prices', {'plan_id': planId, 'currency': 'USD', 'amount': usdAmount});
  await db.insert('plan_prices', {'plan_id': planId, 'currency': 'EUR', 'amount': double.parse((usdAmount * 0.92).toStringAsFixed(2))});
  await db.insert('plan_prices', {'plan_id': planId, 'currency': 'TRY', 'amount': double.parse((usdAmount * 34).toStringAsFixed(2))});
  await db.insert('plan_prices', {'plan_id': planId, 'currency': 'IQD', 'amount': (usdAmount * 1310).roundToDouble()});
}
