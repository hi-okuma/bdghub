import 'package:bodogehub/Pages/0001_NgWord/ngword_playing_page.dart';
import 'package:bodogehub/Pages/0002_NoForeignWord/no_foregin_word_playing_page.dart';
import 'package:bodogehub/Pages/0004_BiasProfile/bias_profile_child_turn_page.dart';
import 'package:bodogehub/Pages/0004_BiasProfile/bias_profile_parent_turn_page.dart';
import 'package:bodogehub/Pages/0004_BiasProfile/bias_profile_check_answer_page.dart';
import 'package:bodogehub/pages/0005_SoloBiasProfile/solo_bias_profile_check_answer_page.dart';
import 'package:bodogehub/pages/0005_SoloBiasProfile/solo_bias_profile_result_page.dart';
import 'package:bodogehub/pages/0005_SoloBiasProfile/solo_bias_profile_select_picture_page.dart';
import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/models/game_enums.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../providers/game_state_provider.dart';
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

  // ★修正：復帰時の画面遷移でGamePhaseを考慮
  void navigateToGameScreenByStatus(
      GameStatus gameStatus, Map<String, dynamic> gameData,
      {bool isRestore = false, bool isGameEnded = false}) {
    if (_navigator == null) return;

    Logger.log(
        '🎮 復帰時の画面遷移: $gameStatus (restore: $isRestore, gameEnded: $isGameEnded)');

    switch (gameStatus) {
      case GameStatus.waiting:
        // ★修正：ゲーム終了後のwaitingかどうかで判定
        if (isGameEnded) {
          Logger.log('🎮 Game ended waiting - navigating to result page');
          navigateToResult(gameData);
        } else {
          Logger.log('🎮 Initial waiting - navigating to game title');
          _navigator!.pushReplacement(
            MaterialPageRoute(builder: (context) => const GameTitlePage()),
          );
        }
        break;

      case GameStatus.playing:
        navigateToPlayingPage();
        break;

      case GameStatus.childTurn:
        navigateToChildTurn(gameData);
        break;

      case GameStatus.parentTurn:
        navigateToParentTurn(gameData);
        break;
      case GameStatus.result:
        navigateToCheckAnswer(gameData);
    }
  }

  // ★新規追加：GamePhaseを考慮した復帰メソッド
  void navigateToGameScreenWithPhase(GameStatus gameStatus,
      Map<String, dynamic> gameData, GamePhase gamePhase) {
    if (_navigator == null) return;

    Logger.log('🎮 フェーズ考慮の画面遷移: $gameStatus, phase: $gamePhase');

    switch (gameStatus) {
      case GameStatus.waiting:
        if (gamePhase == GamePhase.ended) {
          // ゲーム進行中または終了後のwaiting = 結果画面
          Logger.log('🎮 Game phase waiting - navigating to result page');
          navigateToResult(gameData);
        } else {
          // 初期状態のwaiting = ゲームタイトル
          Logger.log('🎮 Initial waiting - navigating to game title');
          navigateToGameTitle();
        }
        break;

      case GameStatus.playing:
        navigateToPlayingPage();
        break;

      case GameStatus.childTurn:
        navigateToChildTurn(gameData);
        break;

      case GameStatus.parentTurn:
        navigateToParentTurn(gameData);
        break;

      case GameStatus.result:
        navigateToCheckAnswer(gameData);
    }
  }

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
      case '0002': // カタカナ語禁止
        _navigator!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NoForeignWordPlayingPage(),
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
            builder: (context) => const BiasProfileChildTurnPage(),
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
            builder: (context) => const BiasProfileParentTurnPage(),
          ),
        );
        break;
      default:
        navigateToGameTitle();
    }
  }

  void navigateToCheckAnswer(Map<String, dynamic> currentGame) {
    if (_navigator == null) return;

    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const BiasProfileCheckAnswerPage(),
      ),
    );
  }

  void navigateToSoloBiasProfileSelectPicturePage() {
    if (_navigator == null) return;

    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SoloBiasProfileSelectPicturePage(),
      ),
    );
  }

  void navigateToSoloBiasProfileCheckAnswerPage(int selectedImageIndex) {
    if (_navigator == null) return;

    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => SoloBiasProfileCheckAnswerPage(
            selectedImageIndex: selectedImageIndex),
      ),
    );
  }

  void navigateToSoloBiasProfileResultPage() {
    if (_navigator == null) return;

    _navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SoloBiasProfileResultPage(),
      ),
    );
  }

  // ★追加: SoloBiasProfile用復帰メソッド
  void navigateToSoloBiasProfileRestore(Map<String, dynamic>? localData) {
    if (_navigator == null) return;

    // ローカルデータから選択インデックスを取得
    final selectedIndex = localData?['selectedIndex'];

    if (selectedIndex != null) {
      Logger.log('🎮 復帰: 画像選択済み -> 正誤確認画面へ (index: $selectedIndex)');
      _navigator!.pushReplacement(
        MaterialPageRoute(
          // インデックスを渡して遷移
          builder: (context) =>
              SoloBiasProfileCheckAnswerPage(selectedImageIndex: selectedIndex),
        ),
      );
    } else {
      Logger.log('🎮 復帰: 画像未選択 -> 写真選択画面へ');
      _navigator!.pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SoloBiasProfileSelectPicturePage(),
        ),
      );
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
      Logger.log('❌ Navigation context is null for navigateToSelectGame');
      return;
    }

    Logger.log('🎮 Navigating to SelectGamePage');

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
      Logger.log('❌ Context is null for dialog');
      return;
    }

    // ホスト判定
    final isHost = _ref.read(isHostProvider);

    // ホストの場合はダイアログを表示しない
    if (isHost) {
      Logger.log('🎮 Host player - no dialog needed');
      return;
    }

    // 子プレイヤーの場合はダイアログを表示
    Logger.log('🎮 Showing game ended dialog for child player');

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
