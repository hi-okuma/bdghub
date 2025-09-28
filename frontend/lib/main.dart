import 'package:bodogehub/Pages/0000_HubMain/game_title_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bodogehub/Pages/0000_HubMain/top_page.dart';
import 'package:bodogehub/components/app_theme.dart';
// Flutter WebでのみUriを取得するためにプラットフォーム固有のインポート
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/services/navigation_service.dart';
import 'package:bodogehub/services/auth_service.dart';
import 'test_UIscreen.dart';
import 'package:bodogehub/config/environment_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 環境を自動判定して初期化
    await EnvironmentConfig.initialize();
  } catch (e) {
    print('Error loading .env.dev file: $e');
    // .envファイルが読み込めない場合でも続行
  }

  // デバッグ情報表示（リリース時は削除可）
  EnvironmentConfig.printCurrentConfig();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(dotenv.env['SITE_KEY']!),
  );

  // Firebase Auth の初期化確認（オプション）
  print('🔥 Firebase Auth 初期化完了');
  if (AuthService.isAuthenticated()) {
    print('🔐 既存の認証を確認: ${AuthService.getCurrentUID()}');
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
      print('Error getting roomId from URL: $e');
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
      // app_theme.dartで定義したテーマを使用
      theme: AppTheme.lightTheme,
      // NavigationServiceのキーを設定
      navigatorKey: NavigationService.navigatorKey,
      home: TopPage(roomId: roomId),
    );
  }
}
