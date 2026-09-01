import 'package:esim_app/features/auth/login_page.dart';
import 'package:esim_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Demo ile giriş button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: LoginPage(),
        ),
      ),
    );

    expect(find.byKey(const Key('demo-login-button')), findsOneWidget);
    expect(find.text('Demo ile giriş'), findsOneWidget);
  });
}
