import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bodogehub/pages/0000_HubMain/app_initialization_page.dart';
import 'package:bodogehub/pages/0000_HubMain/maintenance_page.dart';
import 'package:bodogehub/components/app_theme.dart';
// Flutter WebでのみUriを取得するためにプラットフォーム固有のインポート
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/services/navigation_service.dart';
import 'package:bodogehub/config/environment_config.dart';
import 'package:bodogehub/services/analytics_service.dart';
import 'package:bodogehub/services/maintenance_service.dart';
import 'utils/logger.dart';

/// アプリ初期化結果を保持するクラス
class AppInitResult {
  final FirebaseApp firebaseApp;
  final MaintenanceInfo maintenanceInfo;

  AppInitResult({required this.firebaseApp, required this.maintenanceInfo});
}

Future<void> main() async {
  // 1. 最小限の初期化
  WidgetsFlutterBinding.ensureInitialized(); // 最初に呼び出す

  // 2. 環境設定の読み込み
  try {
    // 環境を自動判定して初期化
    await EnvironmentConfig.initialize();
  } catch (e) {
    Logger.log('Error loading .env.dev file: $e');
    // .envファイルが読み込めない場合でも続行
  }

  // デバッグ情報表示（リリース時は削除可）
  EnvironmentConfig.printCurrentConfig();

  // 3. Firebase初期化とメンテナンス確認を並列化
  final initFuture = _initializeApp();

  // URLから部屋IDを取得
  final String? roomId = _getRoomIdFromUrl();

  runApp(
    ProviderScope(
      child: MyApp(roomId: roomId, initFuture: initFuture),
    ),
  );
}

/// Firebase初期化とメンテナンス確認を並列実行
Future<AppInitResult> _initializeApp() async {
  // Firebase初期化
  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check設定とメンテナンス確認を並列実行
  final results = await Future.wait([
    _activateAppCheck(),
    MaintenanceService.checkMaintenanceStatus(),
  ]);

  return AppInitResult(
    firebaseApp: firebaseApp,
    maintenanceInfo: results[1] as MaintenanceInfo,
  );
}

/// App Checkのアクティベート
Future<void> _activateAppCheck() async {
  final siteKey = dotenv.env['SITE_KEY'];
  if (siteKey != null) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(siteKey),
    );
  }
}

// URLパラメータから部屋IDを取得するヘルパー関数
String? _getRoomIdFromUrl() {
  // Webプラットフォームでのみ動作
  if (kIsWeb) {
    try {
      // URLパラメータからroomIdを取得
      final uri = Uri.parse(html.window.location.href);
      final params = uri.queryParameters;
      return params['roomId'];
    } catch (e) {
      Logger.log('Error getting roomId from URL: $e');
      return null;
    }
  }
  // Web以外のプラットフォームの場合はnullを返す
  return null;
}

final AnalyticsService analyticsService = AnalyticsService();

class MyApp extends StatelessWidget {
  final String? roomId;
  final Future<AppInitResult> initFuture;

  const MyApp({super.key, this.roomId, required this.initFuture});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ボドゲハブ | インストール不要の暇つぶしボドゲアプリ',
      theme: AppTheme.lightTheme,
      navigatorKey: NavigationService.navigatorKey,
      navigatorObservers: [
        analyticsService.routeObserver,
      ],
      home: FutureBuilder<AppInitResult>(
        future: initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            final result = snapshot.data!;
            // メンテナンス中 → メンテナンス画面を表示
            if (result.maintenanceInfo.isMaintenance) {
              return MaintenancePage(message: result.maintenanceInfo.message);
            }
            // メンテナンスなし → 通常の初期化フローへ
            return AppInitializationPage(urlRoomId: roomId);
          }
          // 初期化待ち（Firebase + メンテナンス確認を並列実行中）
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
