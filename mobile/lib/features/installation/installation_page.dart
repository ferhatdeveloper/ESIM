import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';
import '../../shared/widgets/async_body.dart';

class InstallationPage extends ConsumerWidget {
  const InstallationPage({super.key, required this.esimId});

  final String esimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final esim = ref.watch(esimDetailProvider(esimId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.install)),
      body: AsyncBody(
        value: esim,
        onRetry: () => ref.invalidate(esimDetailProvider(esimId)),
        builder: (item) {
          if (!item.hasInstallPayload) {
            return Center(child: Text(l10n.noInstallData));
          }
          final payload = [
            if (item.smdpAddress != null) 'LPA:1\$${item.smdpAddress}\$${item.activationCode ?? ''}',
          ].join();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (item.isMock) Text(l10n.mockInstall),
              const SizedBox(height: 16),
              Text(l10n.qrInstall, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: payload.isEmpty ? (item.activationCode ?? '') : payload,
                  size: 220,
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.manualInstall, style: Theme.of(context).textTheme.titleLarge),
              if (item.smdpAddress != null) ListTile(title: Text(l10n.smdp), subtitle: Text(item.smdpAddress!)),
              if (item.activationCode != null) ListTile(title: Text(l10n.activationCode), subtitle: Text(item.activationCode!)),
              if (item.iccid != null) ListTile(title: Text(l10n.iccid), subtitle: Text(item.iccid!)),
              const SizedBox(height: 16),
              Text(l10n.iosSteps),
              const SizedBox(height: 12),
              Text(l10n.androidSteps),
            ],
          );
        },
      ),
    );
  }
}
