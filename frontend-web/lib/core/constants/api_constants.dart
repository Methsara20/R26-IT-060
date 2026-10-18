abstract final class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smartomniretailr26-api.azurewebsites.net',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}

