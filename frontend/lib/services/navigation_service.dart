import 'package:bodogehub/Pages/0001_NgWord/ngword_playing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../Pages/0000_HubMain/game_title_page.dart';
import '../Pages/0000_HubMain/select_game_page.dart';
import '../Pages/0000_HubMain/game_result_page.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  final Ref _ref;

  NavigationService(this._ref);

  NavigatorState? get _navigator => navigatorKey.currentState;
  BuildContext? get context => _navigator?.context;

  void navigateToGameTitle() {
    if (_navigator == null) return;

    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const GameTitlePage(),
      ),
    );
  }

  void navigateToPlayingPage() {
    if (_navigator == null) return;

    final gameId = _ref.read(currentGameProvider).gameId ?? '0001';

    switch (gameId) {
      case '0001': // NGワード
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NgWordPlayingPage(),
          ),
        );
        break;
      default:
        navigateToGameTitle();
    }
  }

  void navigateToChildTurn(Map<String, dynamic> currentGame) {
    if (_navigator == null) return;

    final gameId = _ref.read(currentGameProvider).gameId ?? '0001';

    // ゲームIDに基づいて適切な画面に遷移
    switch (gameId) {
      case '0002': // カタカナ語禁止
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('カタカナ語禁止', '出題者'),
          ),
        );
        break;
      case '0003': // 水平思考
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('水平思考', '出題者'),
          ),
        );
        break;
      case '0004': // 偏見プロフィール
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('偏見プロフィール', '子'),
          ),
        );
        break;
      default:
        // デフォルトはGameTitlePageに遷移
        navigateToGameTitle();
    }
  }

  void navigateToParentTurn(Map<String, dynamic> currentGame) {
    if (_navigator == null) return;

    final gameId = _ref.read(currentGameProvider).gameId ?? '0001';

    switch (gameId) {
      case '0002': // カタカナ語禁止 - 回答者画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('カタカナ語禁止', '回答者'),
          ),
        );
        break;
      case '0003': // 水平思考 - 回答者画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('水平思考', '回答者'),
          ),
        );
        break;
      case '0004': // 偏見プロフィール - 親画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('偏見プロフィール', '親'),
          ),
        );
        break;
      default:
        navigateToGameTitle();
    }
  }

  void navigateToResult(Map<String, dynamic> currentGame) {
    if (_navigator == null) return;

    // 全ゲーム共通でGameResultPageに遷移
    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const GameResultPage(),
      ),
    );
  }

  /// ゲーム選択画面に遷移（ゲーム終了時）
  void navigateToSelectGame() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ Navigation context is null for navigateToSelectGame');
      return;
    }

    print('🎮 Navigating to SelectGamePage');

    // 現在のスタックをクリアしてゲーム選択画面に遷移
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const SelectGamePage(),
      ),
      (route) => false, // 全ての前のルートを削除
    );

    // 遷移完了後にダイアログ表示（少し遅延を入れる）
    Future.delayed(const Duration(milliseconds: 300), () {
      _showGameEndedDialogIfNeeded();
    });
  }

  /// 子プレイヤーにゲーム終了ダイアログを表示
  void _showGameEndedDialogIfNeeded() {
    final currentContext = navigatorKey.currentContext;
    if (currentContext == null) {
      print('❌ Context is null for dialog');
      return;
    }

    // ホスト判定
    final isHost = _ref.read(isHostProvider);

    // ホストの場合はダイアログを表示しない
    if (isHost) {
      print('🎮 Host player - no dialog needed');
      return;
    }

    // 子プレイヤーの場合はダイアログを表示
    print('🎮 Showing game ended dialog for child player');

    showDialog(
      context: currentContext,
      barrierDismissible: false, // 背景タップで閉じない
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ゲーム終了'),
          content: const Text('ホストによってゲームが終了されました'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ダイアログを閉じる
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // プレースホルダー画面（実際のゲーム画面が実装されるまで使用）
  Widget _buildPlaceholderGameScreen(String gameName, String role) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$gameName - $role'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.games,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              '$gameName\n$role画面',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '実装予定',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => navigateToSelectGame(),
              child: const Text('ゲーム選択に戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

final navigationServiceProvider = Provider<NavigationService>((ref) {
  return NavigationService(ref);
});
