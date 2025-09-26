import 'dart:math';

/// Firebase benzeri ID generator
/// Firebase Firestore'un kullandığı formata benzer ID'ler üretir
class IdGenerator {
  static const String _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final Random _random = Random();

  /// Firebase benzeri 20 karakterlik ID üretir
  /// Örnek: "K2xLpQrSt1vWxYz3A4bC"
  static String generateFirebaseId() {
    return List.generate(20, (index) => _chars[_random.nextInt(_chars.length)])
        .join();
  }

  /// Kısa ID üretir (özel kullanımlar için)
  static String generateShortId([int length = 12]) {
    return List.generate(
        length, (index) => _chars[_random.nextInt(_chars.length)]).join();
  }

  /// Timestamp içeren ID üretir (sıralama için)
  static String generateTimestampId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = generateShortId(8);
    return '${timestamp}_$randomPart';
  }
}
