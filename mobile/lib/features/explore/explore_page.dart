import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/cards.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final countries = ref.watch(countriesProvider);
    final regions = ref.watch(regionsProvider);
    final query = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.explore)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(countriesProvider);
          ref.invalidate(regionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchDestination),
            ),
            const SizedBox(height: 20),
            Text(l10n.regions, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AsyncBody(
              value: regions,
              onRetry: () => ref.invalidate(regionsProvider),
              builder: (items) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .where((r) => query.isEmpty || r.localizedName(locale).toLowerCase().contains(query))
                    .map((r) => ActionChip(
                          label: Text(r.localizedName(locale)),
                          onPressed: () => context.push('/regions/${r.id}?title=${Uri.encodeComponent(r.localizedName(locale))}'),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.popularCountries, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AsyncBody(
              value: countries,
              onRetry: () => ref.invalidate(countriesProvider),
              empty: Text(l10n.noResults),
              builder: (items) {
                final filtered = items.where((c) => query.isEmpty || c.localizedName(locale).toLowerCase().contains(query)).toList();
                if (filtered.isEmpty) return Text(l10n.noResults);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (_, i) => CountryCard(
                    flag: filtered[i].flagEmoji,
                    name: filtered[i].localizedName(locale),
                    onTap: () => context.push(
                      '/countries/${filtered[i].id}?title=${Uri.encodeComponent(filtered[i].localizedName(locale))}',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
