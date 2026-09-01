import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/services/providers.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  CheckoutQuote? _quote;
  PurchaseResult? _result;
  String? _error;
  bool _loading = true;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadQuote);
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await ref.read(apiRepositoryProvider).createCheckout(
            planId: widget.planId,
            currency: currentCurrency(ref),
          );
      setState(() => _quote = quote);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay({required bool succeed}) async {
    final quote = _quote;
    if (quote == null) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiRepositoryProvider).confirmMockPayment(
            orderId: quote.orderId,
            succeed: succeed,
          );
      ref.invalidate(myEsimsProvider);
      ref.invalidate(ordersProvider);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_quote == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkout)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? l10n.empty),
              FilledButton(onPressed: _loadQuote, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final quote = _quote!;
    final money = NumberFormat.simpleCurrency(name: quote.currency);

    if (_result != null) {
      final result = _result!;
      final ok = result.esimId != null;
      return Scaffold(
        appBar: AppBar(title: Text(ok ? l10n.purchaseOk : l10n.paymentFailed)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: 8),
              Text(l10n.mockNotice),
              const Spacer(),
              if (ok)
                FilledButton(
                  onPressed: () => context.go('/esims/${result.esimId}'),
                  child: Text(l10n.viewEsim),
                )
              else
                FilledButton(onPressed: () => context.go('/orders'), child: Text(l10n.orders)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(quote.destination, style: Theme.of(context).textTheme.headlineSmall),
          Text(quote.planName),
          const SizedBox(height: 16),
          ListTile(title: Text(l10n.data), trailing: Text('${quote.dataAmountMb} MB')),
          ListTile(title: Text(l10n.validity), trailing: Text('${quote.validityDays} ${l10n.days}')),
          ListTile(title: Text(l10n.price), trailing: Text(money.format(quote.subtotal))),
          ListTile(title: Text(l10n.taxes), trailing: Text(money.format(quote.tax))),
          ListTile(title: Text(l10n.fees), trailing: Text(money.format(quote.fees))),
          ListTile(title: Text(l10n.total), trailing: Text(money.format(quote.total))),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.mockNotice),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _paying ? null : () => _pay(succeed: true),
            child: Text(l10n.payMock),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _paying ? null : () => _pay(succeed: false),
            child: Text(l10n.paymentFailed),
          ),
        ],
      ),
    );
  }
}
