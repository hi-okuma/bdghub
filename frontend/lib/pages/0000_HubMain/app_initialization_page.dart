import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bodogehub/models/game_enums.dart';
import '/components/app_theme.dart';
import '/providers/user_provider.dart';
import '/providers/game_provider.dart';
import '/providers/game_state_provider.dart';
import '/providers/analytics_provider.dart';
import '/services/auth_service.dart';
import '/services/navigation_service.dart';
import '/Pages/0000_HubMain/select_game_page.dart';
import '/Pages/0000_HubMain/top_page.dart';
import 'package:bodogehub/services/analytics_service.dart';

class AppInitializationPage extends ConsumerStatefulWidget {
  final String? urlRoomId;

  const AppInitializationPage({super.key, this.urlRoomId});

  @override
  ConsumerState<AppInitializationPage> createState() =>
      _AppInitializationPageState();
}

class _AppInitializationPageState extends ConsumerState<AppInitializationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // 最初に認証と復帰処理を試みる
      await AuthService.ensureAuthenticated();
      final restoreSuccess =
          await ref.read(userProvider.notifier).tryRestoreFromStorage();

      if (restoreSuccess) {
        // 復帰に成功した場合
        final restoredRoomId = ref.read(userProvider).roomId;

        // URLのroomIdと復元したroomIdが一致するか、
        // あるいはURLにroomIdがなくとも復帰情報があれば、詳細な復帰処理を行う
        if (widget.urlRoomId == null ||
            widget.urlRoomId!.isEmpty ||
            restoredRoomId == widget.urlRoomId) {
          await _handleDetailedGameStateRestore();
        } else {
          // 復元された部屋とURLの部屋が違う場合、URLを優先して参加フローへ
          // (あるいは、進行中のセッションがあると警告を出すなどの実装も可能)
          await ref.read(userProvider.notifier).leaveRoom(); // 古いセッション情報をクリア
          _navigateToJoinRoom(widget.urlRoomId!, false);
        }
      } else {
        // 復帰に失敗した場合
        if (widget.urlRoomId != null && widget.urlRoomId!.isNotEmpty) {
          // URLにroomIdがあれば、参加フローへ
          _navigateToJoinRoom(widget.urlRoomId!, true);
        } else {
          // 何も情報がなければTopPageへ
          _navigateToTop();
        }
      }
    } catch (e) {
      Logger.log('❌ アプリ初期化エラー: $e');
      _showErrorAndNavigateToTop('アプリの初期化に失敗しました');
    }
  }

  Future<void> _handleDetailedGameStateRestore() async {
    try {
      final userState = ref.read(userProvider);
      final roomId = userState.roomId;
      final savedGamePhase = userState.gamePhase ?? GamePhase.initial;

      if (roomId == null) {
        _navigateToTop();
        return;
      }

      Logger.log('🔍 詳細ゲーム状態復帰開始: $roomId (savedGamePhase: $savedGamePhase)');

      // 部屋の基本状態確認
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        _showErrorAndNavigateToTop('部屋が見つかりませんでした');
        return;
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final roomStatus = roomData['status'] as String?;

      switch (roomStatus) {
        case 'closed':
          _showErrorAndNavigateToTop('部屋はすでに終了しています');
          return;
        case 'full':
          _showErrorAndNavigateToTop('部屋の参加人数上限に達しています');
          return;
        case 'inProgress':
          break;
        default:
          _navigateToSelectGame();
          return;
      }

      // currentGameから詳細状態取得
      final currentGameQuery = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('currentGame')
          .get();

      if (currentGameQuery.docs.isEmpty) {
        _navigateToSelectGame();
        return;
      }

      final gameDoc = currentGameQuery.docs.first;
      final gameId = gameDoc.id;
      final gameData = gameDoc.data();
      final gameStatus = _parseGameStatus(gameData['gameStatus']);

      Logger.log(
          '🔍 Game ID: $gameId, Game Status: $gameStatus, Saved Phase: $savedGamePhase');

      // currentGameProviderにデータ読み込み
      await ref
          .read(currentGameProvider.notifier)
          .loadFromCurrentGame(roomId, gameId);

      if (!mounted) return;

      // ★追加: GameIDによる分岐
      if (gameId == '0005') {
        Logger.log('🔍 SoloBiasProfileの復帰処理を実行');

        final userState = ref.read(userProvider);

        // 1. まず gamePhase が ended (結果画面) かどうかを確認
        if (userState.gamePhase == GamePhase.ended) {
          Logger.log('🎮 復帰: GamePhase.ended -> 結果画面へ');
          // 結果画面への遷移（ResultPageへ）
          // ※結果画面に必要なデータがあれば引数で渡すか、ResultPage内で再取得する
          ref
              .read(navigationServiceProvider)
              .navigateToSoloBiasProfileResultPage();

          // 状態監視を開始して終了
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(roomGameStateProvider(roomId));
          });
          return;
        }

        // 2. endedでなければ、localGameData (選択状態) を確認
        // UserProviderからローカルデータを取得
        final localData = ref.read(userProvider).localGameData;

        // 専用の復帰メソッドを呼び出し
        ref
            .read(navigationServiceProvider)
            .navigateToSoloBiasProfileRestore(localData);

        // 状態監視を開始して終了
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(roomGameStateProvider(roomId));
        });
        return;
      }

      // 保存されたgamePhaseを使用して正確な画面に遷移
      final navigationService = ref.read(navigationServiceProvider);

      if (gameStatus == GameStatus.waiting) {
        if (savedGamePhase == GamePhase.ended) {
          Logger.log('🔍 ゲーム終了後のwaiting → 結果画面に遷移');
          navigationService.navigateToResult(gameData);
        } else {
          Logger.log('🔍 ゲーム開始前のwaiting → ゲームタイトルに遷移');
          navigationService.navigateToGameTitle();
        }
      } else {
        Logger.log('🔍 ゲーム進行中 → 適切な画面に遷移');
        navigationService.navigateToGameScreenByStatus(gameStatus, gameData,
            isRestore: true);
      }

      // 遷移後に状態監視を開始
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Logger.log('🔍 復帰後にゲーム状態監視を開始: $roomId');
        ref.read(roomGameStateProvider(roomId));
      });
    } catch (e) {
      Logger.log('❌ 詳細ゲーム状態復帰エラー: $e');
      _showErrorAndNavigateToTop('ゲーム状態の復帰に失敗しました');
    }
  }

  GameStatus _parseGameStatus(dynamic status) {
    switch (status?.toString()) {
      case 'playing':
        return GameStatus.playing;
      case 'childTurn':
        return GameStatus.childTurn;
      case 'parentTurn':
        return GameStatus.parentTurn;
      case 'result':
        return GameStatus.result;
      default:
        return GameStatus.waiting;
    }
  }

  void _navigateToJoinRoom(String roomId, bool isFromRoomURL) {
    if (!mounted) return;

    if (isFromRoomURL) {
      ref.read(analyticsServiceProvider).logPageView(
          pageTitle: '/register_profile_page',
          additionalParams: {'trigger_source': 'create_room_button'});
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => TopPage(roomId: roomId)),
    );
  }

  void _navigateToSelectGame() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SelectGamePage()),
    );
  }

  void _navigateToTop() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TopPage()),
    );
  }

  void _showErrorAndNavigateToTop(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('復帰エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToTop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
