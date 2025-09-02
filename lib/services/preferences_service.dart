import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PreferencesService {
  static PreferencesService? _instance;
  static PreferencesService get instance =>
      _instance ??= PreferencesService._();
  PreferencesService._();

  // Keys for preferences
  static const String _hideAmounts = 'dashboard_hide_amounts';
  static const String _themeMode = 'theme_mode';
  static const String _stockAlertsEnabled = 'stock_alerts_enabled';
  static const String _notificationsEnabled = 'notifications_enabled';
  static const String _minStockLevel = 'min_stock_level';
  static const String _defaultTaxRate = 'default_tax_rate';
  static const String _storeName = 'store_name';
  static const String _storeAddress = 'store_address';
  static const String _storePhone = 'store_phone';
  static const String _storeTaxNumber = 'store_tax_number';
  static const String _receiptHeader = 'receipt_header';
  static const String _receiptFooter = 'receipt_footer';
  static const String _language = 'language';
  static const String _currency = 'currency';
  static const String _defaultPaymentMethod = 'default_payment_method';
  static const String _autoPrintReceipt = 'auto_print_receipt';
  static const String _soundOnScan = 'sound_on_scan';
  static const String _vibrationOnScan = 'vibration_on_scan';

  // Business Info Keys
  static const String _businessName = 'business_name';
  static const String _businessAddress = 'business_address';
  static const String _businessPhone = 'business_phone';
  static const String _businessEmail = 'business_email';
  static const String _businessTaxNumber = 'business_tax_number';

  // Receipt Settings Keys
  static const String _showReceiptNumber = 'show_receipt_number';
  static const String _showPriceWithTax = 'show_price_with_tax';
  static const String _detailedInvoice = 'detailed_invoice';
  static const String _receiptTemplate = 'receipt_template';

  // Tax Settings Keys
  static const String _kdvRate = 'kdv_rate';
  static const String _otvRate = 'otv_rate';
  static const String _taxCalculationEnabled = 'tax_calculation_enabled';
  static const String _showTaxDetails = 'show_tax_details';

  // Dashboard Preferences
  Future<bool> getHideAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideAmounts) ?? false;
  }

  Future<void> setHideAmounts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAmounts, value);
  }

  // Theme Preferences
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeMode) ?? 'light'; // Default light tema
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeMode, mode);
  }

  // Business Settings
  Future<bool> getStockAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_stockAlertsEnabled) ?? true;
  }

  Future<void> setStockAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stockAlertsEnabled, value);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabled, value);
  }

  Future<int> getMinStockLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minStockLevel) ?? 5;
  }

  Future<void> setMinStockLevel(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minStockLevel, value);
  }

  Future<double> getDefaultTaxRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_defaultTaxRate) ?? 18.0;
  }

  Future<void> setDefaultTaxRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultTaxRate, value);
  }

  // Store Information
  Future<String> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeName) ?? '';
  }

  Future<void> setStoreName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeName, value);
  }

  Future<String> getStoreAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeAddress) ?? '';
  }

  Future<void> setStoreAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeAddress, value);
  }

  Future<String> getStorePhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storePhone) ?? '';
  }

  Future<void> setStorePhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storePhone, value);
  }

  Future<String> getStoreTaxNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeTaxNumber) ?? '';
  }

  Future<void> setStoreTaxNumber(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeTaxNumber, value);
  }

  // Receipt Settings
  Future<String> getReceiptHeader() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptHeader) ?? 'Hoş Geldiniz';
  }

  Future<void> setReceiptHeader(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptHeader, value);
  }

  Future<String> getReceiptFooter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptFooter) ?? 'Teşekkürler!';
  }

  Future<void> setReceiptFooter(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptFooter, value);
  }

  // Localization
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_language) ?? 'tr';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_language, value);
  }

  Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currency) ?? 'TRY';
  }

  Future<void> setCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currency, value);
  }

  // Sales Preferences
  Future<String> getDefaultPaymentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultPaymentMethod) ?? 'cash';
  }

  Future<void> setDefaultPaymentMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultPaymentMethod, value);
  }

  Future<bool> getAutoPrintReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPrintReceipt) ?? false;
  }

  Future<void> setAutoPrintReceipt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintReceipt, value);
  }

  Future<bool> getSoundOnScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundOnScan) ?? true;
  }

  Future<void> setSoundOnScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundOnScan, value);
  }

  Future<bool> getVibrationOnScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationOnScan) ?? true;
  }

  Future<void> setVibrationOnScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationOnScan, value);
  }

  // Bulk operations
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'hideAmounts': await getHideAmounts(),
      'themeMode': await getThemeMode(),
      'stockAlertsEnabled': await getStockAlertsEnabled(),
      'notificationsEnabled': await getNotificationsEnabled(),
      'minStockLevel': await getMinStockLevel(),
      'defaultTaxRate': await getDefaultTaxRate(),
      'storeName': await getStoreName(),
      'storeAddress': await getStoreAddress(),
      'storePhone': await getStorePhone(),
      'storeTaxNumber': await getStoreTaxNumber(),
      'receiptHeader': await getReceiptHeader(),
      'receiptFooter': await getReceiptFooter(),
      'language': await getLanguage(),
      'currency': await getCurrency(),
      'defaultPaymentMethod': await getDefaultPaymentMethod(),
      'autoPrintReceipt': await getAutoPrintReceipt(),
      'soundOnScan': await getSoundOnScan(),
      'vibrationOnScan': await getVibrationOnScan(),
    };
  }

  Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Reset theme to default light mode
  Future<void> resetThemeToLight() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeMode, 'light');
  }

  // Helper method to convert ThemeMode to string
  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // Helper method to convert string to ThemeMode
  static ThemeMode stringToThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  // Business Info Methods
  Future<String?> getBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessName);
  }

  Future<void> setBusinessName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessName, value);
  }

  Future<String?> getBusinessAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessAddress);
  }

  Future<void> setBusinessAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessAddress, value);
  }

  Future<String?> getBusinessPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessPhone);
  }

  Future<void> setBusinessPhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessPhone, value);
  }

  Future<String?> getBusinessEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessEmail);
  }

  Future<void> setBusinessEmail(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessEmail, value);
  }

  Future<String?> getBusinessTaxNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessTaxNumber);
  }

  Future<void> setBusinessTaxNumber(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessTaxNumber, value);
  }

  // Receipt Settings Methods
  Future<bool> getShowReceiptNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showReceiptNumber) ?? true;
  }

  Future<void> setShowReceiptNumber(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showReceiptNumber, value);
  }

  Future<bool> getShowPriceWithTax() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showPriceWithTax) ?? true;
  }

  Future<void> setShowPriceWithTax(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPriceWithTax, value);
  }

  Future<bool> getDetailedInvoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_detailedInvoice) ?? false;
  }

  Future<void> setDetailedInvoice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_detailedInvoice, value);
  }

  Future<String> getReceiptTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptTemplate) ?? 'Standart Şablon';
  }

  Future<void> setReceiptTemplate(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptTemplate, value);
  }

  // Tax Settings Methods
  Future<double> getKdvRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kdvRate) ?? 18.0;
  }

  Future<void> setKdvRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kdvRate, value);
  }

  Future<double> getOtvRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_otvRate) ?? 0.0;
  }

  Future<void> setOtvRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_otvRate, value);
  }

  Future<bool> getTaxCalculationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_taxCalculationEnabled) ?? true;
  }

  Future<void> setTaxCalculationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_taxCalculationEnabled, value);
  }

  Future<bool> getShowTaxDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTaxDetails) ?? true;
  }

  Future<void> setShowTaxDetails(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTaxDetails, value);
  }
}




