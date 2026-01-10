import 'package:bodogehub/config/environment_config.dart';
import 'package:bodogehub/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  bool get _isAnalyticsEnabled {
    return true;
    // development環境では無効化
    // return EnvironmentConfig.currentEnvironment != Environment.development;
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

      await _analytics.logEvent(
        name: 'page_view',
        parameters: params,
      );
    } catch (e, s) {
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

      await _analytics.logEvent(
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
      await _analytics.setUserProperty(name: property, value: value);
    } catch (e, s) {
      Logger.log('Failed to set user property: $e\n$s');
    }
  }
}
