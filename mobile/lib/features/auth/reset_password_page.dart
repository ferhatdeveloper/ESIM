import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  String? _info;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiRepositoryProvider).requestPasswordReset(_email.text.trim());
      final token = res['reset_token'];
      setState(() {
        _info = token is String
            ? 'Development token only: $token'
            : 'If the account exists, a reset was queued.';
        if (token is String) _token.text = token;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiRepositoryProvider).resetPassword(_token.text.trim(), _password.text);
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(controller: _email, decoration: InputDecoration(labelText: l10n.email), validator: Validators.email),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _busy ? null : _request, child: Text(l10n.sendReset)),
          const SizedBox(height: 24),
          TextFormField(controller: _token, decoration: InputDecoration(labelText: l10n.resetToken)),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: l10n.newPassword)),
          const SizedBox(height: 12),
          if (_info != null) Text(_info!),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(onPressed: _busy ? null : _reset, child: Text(l10n.resetPassword)),
        ],
      ),
    );
  }
}
