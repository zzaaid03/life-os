/// Application-wide configuration constants.
///
/// All magic values, keys, and configuration parameters
/// should be defined here to maintain a single source of truth.
abstract final class AppConfig {
  AppConfig._();

  /// The application name displayed to users.
  static const String appName = 'Life OS';

  /// The package name used for platform-specific identifiers.
  static const String packageName = 'com.lifeos.app';

  /// The current application version.
  static const String version = '1.0.0';

  /// The build number.
  static const int buildNumber = 1;

  /// Minimum supported Android SDK version.
  static const int androidMinSdkVersion = 24;

  /// Target Android SDK version.
  static const int androidTargetSdkVersion = 34;

  /// Minimum supported iOS version.
  static const String iosMinVersion = '15.0';

  /// Default locale for the application.
  static const String defaultLocale = 'en';

  /// Supported locales.
  static const List<String> supportedLocales = ['en'];

  /// Timeout duration for network requests.
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Maximum number of retry attempts for failed network requests.
  static const int maxRetryAttempts = 3;

  /// Base delay between retry attempts (exponential backoff applied).
  static const Duration retryBaseDelay = Duration(seconds: 1);
}
