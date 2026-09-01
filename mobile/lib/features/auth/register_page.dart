import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _locale = 'en';
  String _currency = 'USD';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
            locale: _locale,
            currency: _currency,
          );
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
      appBar: AppBar(title: Text(l10n.register)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(controller: _name, decoration: InputDecoration(labelText: l10n.fullName), validator: Validators.required),
                const SizedBox(height: 12),
                TextFormField(controller: _email, decoration: InputDecoration(labelText: l10n.email), validator: Validators.email),
                const SizedBox(height: 12),
                TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: l10n.password), validator: Validators.password),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _locale,
                  decoration: InputDecoration(labelText: l10n.language),
                  items: AppConstants.supportedLocales.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _locale = v ?? 'en'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(labelText: l10n.currency),
                  items: AppConstants.supportedCurrencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.register)),
          TextButton(onPressed: () => context.go('/login'), child: Text('${l10n.alreadyHaveAccount} ${l10n.login}')),
        ],
      ),
    );
  }
}
