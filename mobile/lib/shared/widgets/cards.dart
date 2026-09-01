import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../models/models.dart';

class CountryCard extends StatelessWidget {
  const CountryCard({super.key, required this.flag, required this.name, required this.onTap});

  final String flag;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.locale,
    required this.currency,
    required this.onTap,
  });

  final MarketplacePlan plan;
  final String locale;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = plan.priceFor(currency);
    final formatted = price == null
        ? '—'
        : NumberFormat.simpleCurrency(name: currency).format(price);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.sand.withValues(alpha: 0.5),
                child: Text(plan.flagEmoji ?? '✈️'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.destination(locale), style: Theme.of(context).textTheme.titleMedium),
                    Text('${plan.dataLabel} · ${plan.validityDays} ${l10n.days}'),
                  ],
                ),
              ),
              Text(formatted, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class EsimBalanceCard extends StatelessWidget {
  const EsimBalanceCard({
    super.key,
    required this.esim,
    required this.locale,
    required this.onTap,
  });

  final UserEsim esim;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ratio = esim.originalBalance == 0 ? 0.0 : esim.remainingBalance / esim.originalBalance;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(esim.flagEmoji ?? '✈️', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(esim.destination(locale), style: Theme.of(context).textTheme.titleMedium)),
                  _StatusChip(status: esim.status),
                ],
              ),
              const SizedBox(height: 12),
              Text('${l10n.remaining}: ${esim.remainingLabel()}', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: ratio.clamp(0, 1), minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text(
                esim.expiresAt == null ? '' : '${l10n.expires}: ${DateFormat.yMMMd(locale).format(esim.expiresAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
    );
  }
}
