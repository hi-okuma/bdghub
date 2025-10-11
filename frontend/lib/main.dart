import 'package:bodogehub/Pages/0000_HubMain/game_title_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bodogehub/Pages/0000_HubMain/top_page.dart';
import 'package:bodogehub/pages/0000_HubMain/app_initialization_page.dart';
import 'package:bodogehub/components/app_theme.dart';
// Flutter WebでのみUriを取得するためにプラットフォーム固有のインポート
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/services/navigation_service.dart';
import 'package:bodogehub/services/auth_service.dart';
import 'test_UIscreen.dart';
import 'package:bodogehub/config/environment_config.dart';

import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 最初に呼び出す

  try {
    // 環境を自動判定して初期化
    await EnvironmentConfig.initialize();
  } catch (e) {
    Logger.log('Error loading .env.dev file: $e');
    // .envファイルが読み込めない場合でも続行
  }

  // デバッグ情報表示（リリース時は削除可）
  EnvironmentConfig.printCurrentConfig();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // SITE_KEYがnullでないことを確認してからactivateを呼ぶ
  final siteKey = dotenv.env['SITE_KEY'];
  if (siteKey != null) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(siteKey),
    );
  } else {
    Logger.log('Error: SITE_KEY is not defined in .env file');
    // ここでエラー処理を行うか、App Checkなしで続行するかを決定
  }

  // UIテスト用フラグ
  const bool testSpecificPage = false;

  // URLから部屋IDを取得
  final String? roomId = _getRoomIdFromUrl();

  runApp(
    ProviderScope(
      child: testSpecificPage
          ? testBiasProfileCheckAnswerPage()
          : MyApp(roomId: roomId),
    ),
  );
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

class MyApp extends StatelessWidget {
  final String? roomId;

  const MyApp({super.key, this.roomId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ボードゲームハブ',
      theme: AppTheme.lightTheme,
      navigatorKey: NavigationService.navigatorKey,
      // ★変更：初期化画面から開始
      home: AppInitializationPage(urlRoomId: roomId),
    );
  }
}
