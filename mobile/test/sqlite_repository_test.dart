import 'package:esim_app/shared/services/sqlite/sqlite_database.dart';
import 'package:esim_app/shared/services/sqlite/sqlite_repository.dart';
import 'package:esim_app/shared/services/sqlite/sqlite_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SqliteRepository repo;

  setUp(() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await createEsimSchema(database);
        await seedEsimDatabase(database);
      },
    );
    repo = SqliteRepository.forDb(db);
  });

  test('demo login and marketplace seed', () async {
    final session = await repo.login('demo@esim.app', 'Demo12345!');
    expect(session.email, 'demo@esim.app');
    expect(await repo.fetchCountries(), isNotEmpty);
    expect(await repo.fetchPlans(), isNotEmpty);
  });

  test('demo account has usable eSIMs with install payloads and independent balances', () async {
    await repo.login('demo@esim.app', 'Demo12345!');
    final esims = await repo.fetchEsims();
    final usable = esims.where((e) => e.isUsable).toList();
    expect(usable.length, greaterThanOrEqualTo(3));
    expect(usable.every((e) => e.hasInstallPayload), isTrue);
    expect(usable.every((e) => e.iccid!.startsWith('MOCK-')), isTrue);
    final ready = usable.where((e) => e.status == 'ready');
    final active = usable.where((e) => e.status == 'active');
    expect(ready, isNotEmpty);
    expect(active, isNotEmpty);
    expect(active.first.remainingBalance, isNot(active.first.originalBalance));
  });

  test('checkout is idempotent and prices come from SQLite', () async {
    await repo.login('demo@esim.app', 'Demo12345!');
    final plan = (await repo.fetchPlans()).first;
    final first = await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'k1');
    final second = await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'k1');
    expect(first.orderId, second.orderId);
    expect(first.total, first.subtotal + first.tax + first.fees);
    expect(first.isMock, isTrue);
  });

  test('one payment creates one eSIM and failed payment creates none', () async {
    await repo.login('demo@esim.app', 'Demo12345!');
    final plan = (await repo.fetchPlans()).first;
    final ok = await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'ok');
    final paid = await repo.confirmMockPayment(orderId: ok.orderId);
    final paidAgain = await repo.confirmMockPayment(orderId: ok.orderId);
    expect(paid.esimId, isNotNull);
    expect(paid.esimId, paidAgain.esimId);

    final fail = await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'fail');
    final failed = await repo.confirmMockPayment(orderId: fail.orderId, succeed: false);
    expect(failed.esimId, isNull);
    final esims = await repo.fetchEsims();
    expect(esims.where((e) => e.orderId == fail.orderId), isEmpty);
  });

  test('usage reduces only that eSIM balance', () async {
    await repo.login('demo@esim.app', 'Demo12345!');
    final plan = (await repo.fetchPlans()).first;
    final a = await repo.confirmMockPayment(
      orderId: (await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'a')).orderId,
    );
    final b = await repo.confirmMockPayment(
      orderId: (await repo.createCheckout(planId: plan.id, currency: 'USD', idempotencyKey: 'b')).orderId,
    );
    await repo.applyEsimUsage(esimId: a.esimId!, usageAmount: 100, source: 'test');
    final first = await repo.fetchEsim(a.esimId!);
    final second = await repo.fetchEsim(b.esimId!);
    expect(first.remainingBalance, first.originalBalance - 100);
    expect(second.remainingBalance, second.originalBalance);
    expect(await repo.fetchUsage(a.esimId!), isNotEmpty);
  });
}
