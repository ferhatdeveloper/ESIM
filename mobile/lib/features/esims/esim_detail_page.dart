import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class EsimDetailPage extends ConsumerWidget {
  const EsimDetailPage({super.key, required this.esimId});

  final String esimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final esim = ref.watch(esimDetailProvider(esimId));
    final usage = ref.watch(esimUsageProvider(esimId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myEsims)),
      body: AsyncBody(
        value: esim,
        onRetry: () => ref.invalidate(esimDetailProvider(esimId)),
        builder: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${item.flagEmoji ?? ''} ${item.destination(locale)}', style: Theme.of(context).textTheme.headlineSmall),
            Text(item.planName(locale)),
            const SizedBox(height: 12),
            ListTile(title: Text(l10n.status), trailing: Text(item.status)),
            ListTile(title: Text(l10n.original), trailing: Text('${item.originalBalance.toStringAsFixed(0)} ${item.balanceUnit}')),
            ListTile(title: Text(l10n.remaining), trailing: Text(item.remainingLabel())),
            ListTile(
              title: Text(l10n.expires),
              trailing: Text(item.expiresAt == null ? '—' : DateFormat.yMMMd(locale).format(item.expiresAt!.toLocal())),
            ),
            ListTile(
              title: Text(l10n.activated),
              trailing: Text(item.activatedAt == null ? '—' : DateFormat.yMMMd(locale).format(item.activatedAt!.toLocal())),
            ),
            if (item.iccid != null) ListTile(title: Text(l10n.iccid), trailing: Text(item.iccid!)),
            if (item.isMock) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.mockInstall)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: item.hasInstallPayload ? () => context.push('/esims/${item.id}/install') : null,
              child: Text(l10n.install),
            ),
            if (item.status == 'ready') ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(apiRepositoryProvider).activateEsim(item.id);
                  ref.invalidate(esimDetailProvider(esimId));
                  ref.invalidate(myEsimsProvider);
                },
                child: Text(l10n.activate),
              ),
            ],
            if (item.isUsable && item.remainingBalance > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(apiRepositoryProvider).applyEsimUsage(
                        esimId: item.id,
                        usageAmount: 100,
                        source: 'manual_use',
                      );
                  ref.invalidate(esimDetailProvider(esimId));
                  ref.invalidate(esimUsageProvider(esimId));
                  ref.invalidate(myEsimsProvider);
                },
                child: Text(l10n.useData),
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.usageHistory, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            usage.when(
              data: (rows) {
                if (rows.isEmpty) return Text(l10n.empty);
                return Column(
                  children: rows
                      .map((u) => ListTile(
                            title: Text('-${u.usageAmount} ${item.balanceUnit}'),
                            subtitle: Text(u.source),
                            trailing: Text('${u.balanceAfter}'),
                          ))
                      .toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
