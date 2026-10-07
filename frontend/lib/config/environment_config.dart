abstract final class EnvironmentConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static final String apiBaseUrl = _resolveApiBaseUrl();

  static void validate() {
    _resolveApiBaseUrl();
  }

  static String _resolveApiBaseUrl() {
    final value = _configuredApiBaseUrl.trim();
    if (value.isEmpty) {
      throw StateError(
        'API_BASE_URL is required. Supply --dart-define=API_BASE_URL=<url>.',
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException(
        'API_BASE_URL must be an absolute HTTP or HTTPS URL without '
        'credentials, a query, or a fragment.',
      );
    }

    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
