import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // App settings keys
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  static const String _firstLaunchKey = 'first_launch';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _businessSetupCompletedKey = 'business_setup_completed';

  // Invoice related keys
  static const String _lastInvoiceNumberKey = 'last_invoice_number';
  static const String _invoiceCounterKey = 'invoice_counter';
  static const String _defaultTaxRateKey = 'default_tax_rate';
  static const String _defaultCurrencyKey = 'default_currency';

  // Business info keys
  static const String _businessNameKey = 'business_name';
  static const String _businessAddressKey = 'business_address';
  static const String _businessPhoneKey = 'business_phone';
  static const String _businessEmailKey = 'business_email';
  static const String _businessLogoKey = 'business_logo';

  // Get SharedPreferences instance
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // App Settings
  Future<void> setTheme(String theme) async {
    final prefs = await _prefs;
    await prefs.setString(_themeKey, theme);
  }

  Future<String?> getTheme() async {
    final prefs = await _prefs;
    return prefs.getString(_themeKey);
  }

  Future<void> setLanguage(String language) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, language);
  }

  Future<String?> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey);
  }

  Future<void> setFirstLaunch(bool isFirstLaunch) async {
    final prefs = await _prefs;
    await prefs.setBool(_firstLaunchKey, isFirstLaunch);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await _prefs;
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await _prefs;
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await _prefs;
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setBusinessSetupCompleted(bool completed) async {
    final prefs = await _prefs;
    await prefs.setBool(_businessSetupCompletedKey, completed);
  }

  Future<bool> isBusinessSetupCompleted() async {
    final prefs = await _prefs;
    return prefs.getBool(_businessSetupCompletedKey) ?? false;
  }

  // Invoice Settings
  Future<void> setLastInvoiceNumber(String invoiceNumber) async {
    final prefs = await _prefs;
    await prefs.setString(_lastInvoiceNumberKey, invoiceNumber);
  }

  Future<String?> getLastInvoiceNumber() async {
    final prefs = await _prefs;
    return prefs.getString(_lastInvoiceNumberKey);
  }

  Future<void> setInvoiceCounter(int counter) async {
    final prefs = await _prefs;
    await prefs.setInt(_invoiceCounterKey, counter);
  }

  Future<int> getInvoiceCounter() async {
    final prefs = await _prefs;
    return prefs.getInt(_invoiceCounterKey) ?? 0;
  }

  Future<void> setDefaultTaxRate(double taxRate) async {
    final prefs = await _prefs;
    await prefs.setDouble(_defaultTaxRateKey, taxRate);
  }

  Future<double> getDefaultTaxRate() async {
    final prefs = await _prefs;
    return prefs.getDouble(_defaultTaxRateKey) ?? 0.0;
  }

  Future<void> setDefaultCurrency(String currency) async {
    final prefs = await _prefs;
    await prefs.setString(_defaultCurrencyKey, currency);
  }

  Future<String> getDefaultCurrency() async {
    final prefs = await _prefs;
    return prefs.getString(_defaultCurrencyKey) ?? 'USD';
  }

  // Business Information
  Future<void> setBusinessName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_businessNameKey, name);
  }

  Future<String?> getBusinessName() async {
    final prefs = await _prefs;
    return prefs.getString(_businessNameKey);
  }

  Future<void> setBusinessAddress(String address) async {
    final prefs = await _prefs;
    await prefs.setString(_businessAddressKey, address);
  }

  Future<String?> getBusinessAddress() async {
    final prefs = await _prefs;
    return prefs.getString(_businessAddressKey);
  }

  Future<void> setBusinessPhone(String phone) async {
    final prefs = await _prefs;
    await prefs.setString(_businessPhoneKey, phone);
  }

  Future<String?> getBusinessPhone() async {
    final prefs = await _prefs;
    return prefs.getString(_businessPhoneKey);
  }

  Future<void> setBusinessEmail(String email) async {
    final prefs = await _prefs;
    await prefs.setString(_businessEmailKey, email);
  }

  Future<String?> getBusinessEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_businessEmailKey);
  }

  Future<void> setBusinessLogo(String logoPath) async {
    final prefs = await _prefs;
    await prefs.setString(_businessLogoKey, logoPath);
  }

  Future<String?> getBusinessLogo() async {
    final prefs = await _prefs;
    return prefs.getString(_businessLogoKey);
  }

  // Generic methods for any key-value storage
  Future<void> setString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _prefs;
    return prefs.getInt(key);
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await _prefs;
    await prefs.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await _prefs;
    return prefs.getDouble(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await _prefs;
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await _prefs;
    return prefs.getStringList(key);
  }

  // Remove specific key
  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  // Clear all data (except auth data)
  Future<void> clearAllData() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    final prefs = await _prefs;
    return prefs.containsKey(key);
  }

  // Get all keys
  Future<Set<String>> getKeys() async {
    final prefs = await _prefs;
    return prefs.getKeys();
  }
}
