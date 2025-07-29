import 'package:bodogehub/Pages/0001_NgWord/ngword_playing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../Pages/0000_HubMain/game_title_page.dart';
import '../Pages/0000_HubMain/select_game_page.dart';

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

    final gameId = _ref.read(currentGameProvider).gameId ?? '0001';

    switch (gameId) {
      case '0001': // NGワード - 結果発表画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('NGワード', '結果発表'),
          ),
        );
        break;
      case '0002': // カタカナ語禁止 - 結果発表画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                _buildPlaceholderGameScreen('カタカナ語禁止', '結果発表'),
          ),
        );
        break;
      case '0003': // 水平思考 - 結果発表画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildPlaceholderGameScreen('水平思考', '結果発表'),
          ),
        );
        break;
      case '0004': // 偏見プロフィール - 正誤確認画面
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                _buildPlaceholderGameScreen('偏見プロフィール', '正誤確認'),
          ),
        );
        break;
      default:
        navigateToGameTitle();
    }
  }

  void navigateToSelectGame() {
    if (_navigator == null) return;

    _navigator!.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const SelectGamePage(),
      ),
      (route) => false,
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
