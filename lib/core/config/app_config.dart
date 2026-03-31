class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'SMT_BACKEND_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String backendApiKey = String.fromEnvironment(
    'SMT_BACKEND_API_KEY',
    defaultValue: '',
  );

  // Admin-panel demo credentials (override at build time for staging/prod):
  // --dart-define=SMT_ADMIN_USERNAME=...
  // --dart-define=SMT_ADMIN_PASSWORD=...
  static const String adminUsername = String.fromEnvironment(
    'SMT_ADMIN_USERNAME',
    defaultValue: 'admin',
  );

  static const String adminPassword = String.fromEnvironment(
    'SMT_ADMIN_PASSWORD',
    defaultValue: 'admin',
  );

  const AppConfig._();
}
