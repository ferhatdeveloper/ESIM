import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class PlanDetailPage extends ConsumerWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final currency = currentCurrency(ref);
    final plan = ref.watch(planProvider(planId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.packages)),
      body: AsyncBody(
        value: plan,
        onRetry: () => ref.invalidate(planProvider(planId)),
        builder: (item) {
          final price = item.priceFor(currency);
          final formatted = price == null ? '—' : NumberFormat.simpleCurrency(name: currency).format(price);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${item.flagEmoji ?? ''} ${item.destination(locale)}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(item.localizedName(locale), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ListTile(title: Text(l10n.data), trailing: Text(item.dataLabel)),
              ListTile(title: Text(l10n.validity), trailing: Text('${item.validityDays} ${l10n.days}')),
              ListTile(title: Text(l10n.price), trailing: Text(formatted)),
              const SizedBox(height: 12),
              Text(l10n.oneTimeRule),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/checkout/${item.id}'),
                child: Text(l10n.buy),
              ),
            ],
          );
        },
      ),
    );
  }
}
