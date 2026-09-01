import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/cards.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    final currency = currentCurrency(ref);
    final countries = ref.watch(countriesProvider);
    final plans = ref.watch(featuredPlansProvider);
    final esims = ref.watch(myEsimsProvider);
    final query = _search.text.trim();
    final search = query.isEmpty ? null : ref.watch(searchPlansProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(countriesProvider);
        ref.invalidate(featuredPlansProvider);
        ref.invalidate(myEsimsProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(l10n.appName),
            actions: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchDestination,
                ),
              ),
            ),
          ),
          if (search != null)
            SliverFillRemaining(
              child: AsyncBody(
                value: search,
                onRetry: () => ref.invalidate(searchPlansProvider(query)),
                empty: Center(child: Text(l10n.noResults)),
                builder: (items) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PlanCard(
                    plan: items[i],
                    locale: locale,
                    currency: currency,
                    onTap: () => context.push('/plans/${items[i].id}'),
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.popularCountries, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 130,
                child: AsyncBody(
                  value: countries,
                  onRetry: () => ref.invalidate(countriesProvider),
                  builder: (items) {
                    final popular = items.where((e) => e.isPopular).toList();
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      itemCount: popular.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => CountryCard(
                        flag: popular[i].flagEmoji,
                        name: popular[i].localizedName(locale),
                        onTap: () => context.push(
                          '/countries/${popular[i].id}?title=${Uri.encodeComponent(popular[i].localizedName(locale))}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.yourEsims, style: Theme.of(context).textTheme.titleLarge)),
                    TextButton(onPressed: () => context.go('/esims'), child: Text(l10n.seeAll)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: esims.when(
                data: (items) {
                  final live = items.where((e) => e.status == 'active' || e.status == 'ready').take(3).toList();
                  if (live.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(l10n.emptyEsims),
                    );
                  }
                  return Column(
                    children: live
                        .map((e) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: EsimBalanceCard(esim: e, locale: locale, onTap: () => context.push('/esims/${e.id}')),
                            ))
                        .toList(),
                  );
                },
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text(e.toString())),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.featuredPlans, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: plans.when(
                data: (items) => SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PlanCard(
                    plan: items[i],
                    locale: locale,
                    currency: currency,
                    onTap: () => context.push('/plans/${items[i].id}'),
                  ),
                ),
                loading: () => const SliverToBoxAdapter(child: SkeletonList()),
                error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.sand.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.oneTimeRule),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
