import 'package:bodogehub/config/environment_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  bool get _isAnalyticsEnabled {
    // development環境では無効化
    // return EnvironmentConfig.currentEnvironment != Environment.development;
    return true;
  }

  Future<void> logPageView({
    required String pageTitle,
    String? pageLocation,
    Map<String, Object>? additionalParams,
  }) async {
    if (!_isAnalyticsEnabled || !kIsWeb) {
      return;
    }

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
  }
}
