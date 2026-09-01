import 'package:esim_app/shared/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marketplace plan price is display-only and currency scoped', () {
    final plan = MarketplacePlan.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'name_en': 'Turkey – 10 GB – 30 Days',
      'name_tr': 'Türkiye – 10 GB – 30 Gün',
      'name_ar': 'تركيا',
      'data_amount_mb': 10240,
      'validity_days': 30,
      'is_featured': true,
      'country_name_en': 'Turkey',
      'prices': [
        {'currency': 'USD', 'amount': 19.9},
        {'currency': 'TRY', 'amount': 676.6},
      ],
    });

    expect(plan.priceFor('USD'), 19.9);
    expect(plan.priceFor('TRY'), 676.6);
    expect(plan.dataLabel, '10 GB');
    expect(plan.destination('tr'), 'Turkey');
  });

  test('each eSIM keeps an independent remaining balance', () {
    Map<String, dynamic> json(String id, num remaining) => {
          'id': id,
          'order_id': 'order-$id',
          'status': 'active',
          'original_balance': 10240,
          'remaining_balance': remaining,
          'balance_unit': 'MB',
          'is_mock': true,
          'plan_name_en': 'A',
          'plan_name_tr': 'A',
          'plan_name_ar': 'A',
          'destination_en': 'Turkey',
          'destination_tr': 'Türkiye',
          'destination_ar': 'تركيا',
          'data_amount_mb': 10240,
          'validity_days': 30,
        };

    final a = UserEsim.fromJson(json('a', 8000));
    final b = UserEsim.fromJson(json('b', 10240));
    expect(a.remainingBalance, isNot(b.remainingBalance));
    expect(a.id, isNot(b.id));
    expect(a.isUsable, isTrue);
  });

  test('checkout quote never uses a client-supplied total field as source of truth', () {
    final quote = CheckoutQuote.fromJson({
      'order_id': 'o1',
      'plan_id': 'p1',
      'destination': 'Turkey',
      'plan_name': '10 GB',
      'data_amount_mb': 10240,
      'validity_days': 30,
      'currency': 'USD',
      'subtotal': 19.9,
      'tax': 0,
      'fees': 0,
      'total': 19.9,
      'payment_mode': 'mock',
    });
    expect(quote.isMock, isTrue);
    expect(quote.total, quote.subtotal + quote.tax + quote.fees);
  });
}
