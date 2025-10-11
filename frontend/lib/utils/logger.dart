import 'package:bodogehub/config/environment_config.dart';
import 'package:flutter/foundation.dart';

class Logger {
  // 開発環境の場合のみログを出力する
  static void log(dynamic message) {
    if (EnvironmentConfig.currentEnvironment == Environment.development) {
      debugPrint('[LOG] $message');
    }
  }
}
