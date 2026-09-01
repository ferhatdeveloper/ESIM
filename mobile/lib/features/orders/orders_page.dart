import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orders)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersProvider),
        child: AsyncBody(
          value: orders,
          onRetry: () => ref.invalidate(ordersProvider),
          empty: Center(child: Text(l10n.emptyOrders)),
          builder: (items) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final o = items[i];
              final money = NumberFormat.simpleCurrency(name: o.currency);
              return Card(
                child: ListTile(
                  leading: Text(o.flagEmoji ?? '📦', style: const TextStyle(fontSize: 24)),
                  title: Text(o.destinationEn ?? o.planNameEn),
                  subtitle: Text('${o.status} · ${DateFormat.yMMMd().format(o.createdAt.toLocal())}'),
                  trailing: Text(money.format(o.total)),
                  onTap: o.esimId == null ? null : () => context.push('/esims/${o.esimId}'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
