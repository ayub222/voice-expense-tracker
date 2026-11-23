class ApiConfig {
  static const String defaultProductionUrl =
      'https://voice-expense-tracker-olive.vercel.app/api.php';

  static String customBaseUrl = '';

  static String get apiUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    return defaultProductionUrl;
  }
}
