// lib/config/environment_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment { development, staging, production }

class EnvironmentConfig {
  static Environment _getCurrentEnvironment() {
    // --dart-defineで指定された環境名を取得
    const environmentName =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

    switch (environmentName.toLowerCase()) {
      case 'staging':
        return Environment.staging;
      case 'production':
        return Environment.production;
      case 'development':
      default:
        return Environment.development;
    }
  }

  static Future<void> initialize() async {
    final environment = _getCurrentEnvironment();

    String envFileName;
    switch (environment) {
      case Environment.development:
        envFileName = '.env.dev';
        break;
      case Environment.staging:
        envFileName = '.env.stg';
        break;
      case Environment.production:
        envFileName = '.env.prd';
        break;
    }

    await dotenv.load(fileName: 'assets/$envFileName');
  }

  static Environment get currentEnvironment => _getCurrentEnvironment();
  static String get environmentName => dotenv.env['ENVIRONMENT'] ?? '';
  static String get hostUrl => dotenv.env['FIREBASE_HOST_URL'] ?? '';

  // デバッグ用の情報表示
  static void printCurrentConfig() {
    print('🔧 Current Environment: ${currentEnvironment.name}');
    print('🌐 Project ID: ${dotenv.env['PROJECT_ID']}');
    print('🔗 Host URL: $hostUrl');
  }
}
