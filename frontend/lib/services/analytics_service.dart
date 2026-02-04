import 'package:bodogehub/config/environment_config.dart';
import 'package:bodogehub/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

class AnalyticsService {
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  bool get _isAnalyticsEnabled {
    // development環境では無効化
    return EnvironmentConfig.currentEnvironment != Environment.development;
  }

  Future<void> logPageView({
    required String pageTitle,
    String? pageLocation,
    Map<String, Object>? additionalParams,
  }) async {
    if (!_isAnalyticsEnabled || !kIsWeb) {
      return;
    }

    try {
      final params = <String, Object>{
        'page_title': pageTitle,
        if (pageLocation != null) 'page_location': pageLocation,
      };

      if (additionalParams != null) {
        params.addAll(additionalParams);
      }

      // ★変更: ここで .instance を呼ぶことで、実行時のタイミングまで評価を遅らせる
      await FirebaseAnalytics.instance.logEvent(
        name: 'page_view',
        parameters: params,
      );
    } catch (e, s) {
      // Firebase初期化前に呼ばれた場合はここでキャッチされ、アプリは落ちない
      Logger.log('Failed to log page_view: $e\n$s');
    }
  }

  Future<void> logClick({
    required String button,
    Map<String, Object>? additionalParams,
  }) async {
    if (!_isAnalyticsEnabled || !kIsWeb) {
      return;
    }

    try {
      final params = <String, Object>{
        'button': button,
      };

      if (additionalParams != null) {
        params.addAll(additionalParams);
      }

      // ★変更
      await FirebaseAnalytics.instance.logEvent(
        name: 'click_event',
        parameters: params,
      );
    } catch (e, s) {
      Logger.log('Failed to log click_event: $e\n$s');
    }
  }

  Future<void> logUserProperty({
    required String property,
    required String value,
  }) async {
    if (!_isAnalyticsEnabled || !kIsWeb) {
      return;
    }

    try {
      // ★変更
      await FirebaseAnalytics.instance
          .setUserProperty(name: property, value: value);
    } catch (e, s) {
      Logger.log('Failed to set user property: $e\n$s');
    }
  }
}
