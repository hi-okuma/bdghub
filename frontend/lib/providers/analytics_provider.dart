import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../main.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return analyticsService;
});
