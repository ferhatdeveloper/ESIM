import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/cards.dart';

class MyEsimsPage extends ConsumerStatefulWidget {
  const MyEsimsPage({super.key});

  @override
  ConsumerState<MyEsimsPage> createState() => _MyEsimsPageState();
}

class _MyEsimsPageState extends ConsumerState<MyEsimsPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final esims = ref.watch(myEsimsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myEsims)),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(l10n.filterAll, 'all'),
                _chip(l10n.filterActive, 'active'),
                _chip(l10n.filterReady, 'ready'),
                _chip(l10n.filterDepleted, 'depleted'),
                _chip(l10n.filterExpired, 'expired'),
                _chip(l10n.filterCancelled, 'cancelled'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(myEsimsProvider),
              child: AsyncBody(
                value: esims,
                onRetry: () => ref.invalidate(myEsimsProvider),
                empty: Center(child: Text(l10n.emptyEsims)),
                builder: (items) {
                  final filtered = items.where((e) => _filter == 'all' || e.status == _filter).toList();
                  if (filtered.isEmpty) return Center(child: Text(l10n.empty));
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => EsimBalanceCard(
                      esim: filtered[i],
                      locale: locale,
                      onTap: () => context.push('/esims/${filtered[i].id}'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}
