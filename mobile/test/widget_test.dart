import 'package:esim_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic localization is RTL and Turkish strings load', (tester) async {
    late AppLocalizations loaded;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Builder(
          builder: (context) {
            loaded = AppLocalizations.of(context);
            return Text(loaded.home);
          },
        ),
      ),
    );
    expect(loaded.isRtl, isTrue);
    expect(loaded.home, 'الرئيسية');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Builder(
          builder: (context) {
            loaded = AppLocalizations.of(context);
            return Text(loaded.oneTimeRule);
          },
        ),
      ),
    );
    expect(loaded.isRtl, isFalse);
    expect(loaded.oneTimeRule, contains('Bakiyeler'));
  });
}
