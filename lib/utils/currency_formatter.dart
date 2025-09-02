import 'dart:math' as math;

class CurrencyFormatter {
  /// Türk Lirası formatında para birimi formatlar
  /// Binlik ayırıcı: nokta (.)
  /// Ondalık ayraç: virgül (,)
  /// Örnek: 1.234.567,89
  static String format(double value, {int decimalPlaces = 2}) {
    if (value.isNaN || value.isInfinite) {
      return '0,00';
    }

    // Negatif değerleri pozitif yap, sonra işaret ekle
    bool isNegative = value < 0;
    double absoluteValue = value.abs();

    // Ondalık basamakları ayarla
    double roundedValue = _roundToDecimalPlaces(absoluteValue, decimalPlaces);

    // Tam ve ondalık kısımları ayır
    int integerPart = roundedValue.floor();
    double decimalPart = roundedValue - integerPart;

    // Tam kısmı nokta ile ayır (binlik ayırıcı)
    String integerString = _addThousandsSeparator(integerPart);

    // Ondalık kısmı formatla
    String decimalString = '';
    if (decimalPlaces > 0) {
      int decimalInt = (decimalPart * math.pow(10, decimalPlaces)).round();
      decimalString = ',${decimalInt.toString().padLeft(decimalPlaces, '0')}';
    }

    // Sonucu birleştir
    String result = integerString + decimalString;

    // Negatif işaret ekle
    if (isNegative) {
      result = '-$result';
    }

    return result;
  }

  /// Türk Lirası formatında para birimi formatlar (₺ sembolü ile)
  static String formatWithSymbol(double value, {int decimalPlaces = 2}) {
    return '₺${format(value, decimalPlaces: decimalPlaces)}';
  }

  /// Binlik ayırıcı ekler
  static String _addThousandsSeparator(int value) {
    String valueString = value.toString();
    String result = '';

    for (int i = 0; i < valueString.length; i++) {
      if (i > 0 && (valueString.length - i) % 3 == 0) {
        result += '.';
      }
      result += valueString[i];
    }

    return result;
  }

  /// Ondalık basamakları yuvarlar
  static double _roundToDecimalPlaces(double value, int decimalPlaces) {
    double factor = math.pow(10, decimalPlaces).toDouble();
    return (value * factor).round() / factor;
  }

  /// String formatından double'a çevirir
  /// Örnek: "1.234.567,89" -> 1234567.89
  static double parseFromTurkishFormat(String value) {
    if (value.isEmpty) return 0.0;

    // ₺ sembolünü kaldır
    String cleanValue = value.replaceAll('₺', '').trim();

    // Son virgül pozisyonunu bul (ondalık ayraç)
    int lastCommaIndex = cleanValue.lastIndexOf(',');

    String integerPart;
    String decimalPart = '0';

    if (lastCommaIndex != -1) {
      integerPart = cleanValue.substring(0, lastCommaIndex);
      decimalPart = cleanValue.substring(lastCommaIndex + 1);
    } else {
      integerPart = cleanValue;
    }

    // Binlik ayırıcı noktaları kaldır
    integerPart = integerPart.replaceAll('.', '');

    // Standart formata çevir
    String standardFormat = '$integerPart.$decimalPart';

    return double.tryParse(standardFormat) ?? 0.0;
  }
}




