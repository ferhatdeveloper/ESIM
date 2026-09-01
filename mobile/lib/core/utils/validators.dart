class Validators {
  const Validators._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 8) return 'Minimum 8 characters';
    return null;
  }

  static String? required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }
}
