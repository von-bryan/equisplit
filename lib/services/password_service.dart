import 'package:crypto/crypto.dart';

class PasswordService {
  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    return sha256.convert(password.codeUnits).toString();
  }

  /// Verify a password against a hash
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
}
