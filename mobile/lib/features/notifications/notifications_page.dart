import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: AsyncBody(
          value: items,
          onRetry: () => ref.invalidate(notificationsProvider),
          builder: (rows) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final n = rows[i];
              return ListTile(
                title: Text(n.title(locale), style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700)),
                subtitle: Text(n.body(locale)),
                onTap: () async {
                  await ref.read(apiRepositoryProvider).markNotificationRead(n.id);
                  ref.invalidate(notificationsProvider);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
