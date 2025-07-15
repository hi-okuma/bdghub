// services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在のユーザーのUIDを取得
  static String? getCurrentUID() {
    return _auth.currentUser?.uid;
  }

  /// 認証済みかどうかを確認
  static bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// 匿名認証を実行（未認証の場合のみ）
  static Future<String> ensureAuthenticated() async {
    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      // 既に認証済みの場合はそのUIDを返す
      return currentUser.uid;
    }

    try {
      // 匿名認証を実行
      final userCredential = await _auth.signInAnonymously();
      final uid = userCredential.user!.uid;
      print('🔐 匿名認証完了: $uid');
      return uid;
    } catch (e) {
      print('❌ 匿名認証エラー: $e');
      throw Exception('認証に失敗しました: $e');
    }
  }

  /// 認証状態の変更を監視
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  /// サインアウト（テスト用）
  static Future<void> signOut() async {
    await _auth.signOut();
    print('🚪 サインアウト完了');
  }
}
