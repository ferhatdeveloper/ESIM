import 'package:esim_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic is RTL and Turkish demo label is correct', () {
    final ar = AppLocalizations(const Locale('ar'));
    expect(ar.isRtl, isTrue);
    expect(ar.home, 'الرئيسية');
    expect(ar.loginWithDemo, 'دخول تجريبي');

    final tr = AppLocalizations(const Locale('tr'));
    expect(tr.isRtl, isFalse);
    expect(tr.oneTimeRule, contains('Bakiyeler'));
    expect(tr.loginWithDemo, 'Demo ile giriş');
  });
}
