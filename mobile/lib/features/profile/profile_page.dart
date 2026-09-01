import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: AsyncBody(
        value: profile,
        onRetry: () => ref.invalidate(profileProvider),
        builder: (me) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(me.fullName, style: Theme.of(context).textTheme.headlineSmall),
            Text(me.email),
            const SizedBox(height: 24),
            ListTile(
              title: Text(l10n.language),
              trailing: DropdownButton<String>(
                value: me.locale,
                items: AppConstants.supportedLocales.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(apiRepositoryProvider).updateProfile(locale: v);
                  ref.read(localeOverrideProvider.notifier).state = Locale(v);
                  ref.invalidate(profileProvider);
                },
              ),
            ),
            ListTile(
              title: Text(l10n.currency),
              trailing: DropdownButton<String>(
                value: me.preferredCurrency,
                items: AppConstants.supportedCurrencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(apiRepositoryProvider).updateProfile(currency: v);
                  ref.read(currencyOverrideProvider.notifier).state = v;
                  ref.invalidate(profileProvider);
                },
              ),
            ),
            ListTile(
              title: Text(l10n.theme),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                items: [
                  DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.systemTheme)),
                  DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.lightTheme)),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.darkTheme)),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(themeModeProvider.notifier).state = v;
                },
              ),
            ),
            ListTile(
              title: Text(l10n.notifications),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notifications'),
            ),
            const SizedBox(height: 16),
            Text(l10n.oneTimeRule),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              child: Text(l10n.logout),
            ),
          ],
        ),
      ),
    );
  }
}
