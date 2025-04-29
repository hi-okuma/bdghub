import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bodogehub/Pages/TopPage.dart';
// Flutter WebでのみUriを取得するためにプラットフォーム固有のインポート
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // URLから部屋IDを取得
  final String? roomId = _getRoomIdFromUrl();

  runApp(MyApp(roomId: roomId));
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'NotoSansJP',
      ),
      home: TopPage(roomId: roomId),
    );
  }
}
