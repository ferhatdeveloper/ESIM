import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  const PasswordHasher._();

  static String hash(String password) {
    final salt = _hex(16);
    return '$salt:${_digest(salt, password)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _digest(parts[0], password) == parts[1];
  }

  static String _digest(String salt, String password) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  static String _hex(int bytes) {
    final rand = Random.secure();
    return List.generate(bytes, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
