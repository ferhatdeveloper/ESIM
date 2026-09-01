import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/cards.dart';

class CountryPlansPage extends ConsumerWidget {
  const CountryPlansPage({
    super.key,
    this.countryId,
    this.regionId,
    required this.title,
  });

  final String? countryId;
  final String? regionId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = currentLocaleCode(ref);
    final currency = currentCurrency(ref);
    final plans = countryId != null
        ? ref.watch(plansByCountryProvider(countryId!))
        : ref.watch(plansByRegionProvider(regionId!));

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? l10n.packages : title)),
      body: AsyncBody(
        value: plans,
        onRetry: () {
          if (countryId != null) {
            ref.invalidate(plansByCountryProvider(countryId!));
          } else {
            ref.invalidate(plansByRegionProvider(regionId!));
          }
        },
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
    );
  }
}
