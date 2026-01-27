import 'package:bodogehub/models/user_state.dart';
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

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
      // URLパラメータをクリア（Web環境のみ）
      _clearUrlParameters();
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
          // 復元された部屋とURLの部屋が違う場合
          // localStorageの部屋のステータスを確認
          final restoredRoomStatus = await _fetchRoomStatus(restoredRoomId!);

          Logger.log(
              '🔍 部屋の不一致を検出: localStorage=$restoredRoomId, URL=${widget.urlRoomId}');
          Logger.log('🔍 localStorageの部屋ステータス: $restoredRoomStatus');

          // localStorageの部屋がaccepting/full/inProgressの場合、選択ダイアログを表示
          if (restoredRoomStatus != null &&
              (restoredRoomStatus == 'accepting' ||
                  restoredRoomStatus == 'full' ||
                  restoredRoomStatus == 'inProgress')) {
            // ダイアログで確認
            final shouldReturnToSavedRoom = await _showRoomReturnDialog();

            if (shouldReturnToSavedRoom == true) {
              // 元の部屋に戻る選択 → 既存の復帰ロジックを実行
              Logger.log('🔍 ユーザーが元の部屋への復帰を選択');
              await _handleDetailedGameStateRestore();
              return;
            } else {
              // TOP画面に戻る選択
              Logger.log('🔍 ユーザーがキャンセルを選択');
              ref
                  .read(analyticsServiceProvider)
                  .logUserProperty(property: 'roomID', value: '');
              await ref.read(userProvider.notifier).leaveRoom();
              _navigateToJoinRoom(widget.urlRoomId!, true);
            }
          } else {
            // localStorageの部屋がclosedまたは存在しない場合、通常通りURLを優先
            Logger.log('🔍 localStorageの部屋がclosedまたは存在しない → URLの部屋を優先');
            ref
                .read(analyticsServiceProvider)
                .logUserProperty(property: 'roomID', value: '');
            await ref.read(userProvider.notifier).leaveRoom();
            _navigateToJoinRoom(widget.urlRoomId!, true);
          }
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

      // ★ 新規追加: players Map の取得
      final players = roomData['players'] as Map<String, dynamic>? ?? {};
      final currentUid = userState.uid;
      final isPlayerInRoom =
          currentUid != null && players.containsKey(currentUid);

      // ★ 新規追加: 復帰ダイアログを表示する条件判定
      // 条件: roomStatus が accepting/full/inProgress かつ 自分が players に含まれる
      if (roomStatus != null &&
          (roomStatus == 'accepting' ||
              roomStatus == 'full' ||
              roomStatus == 'inProgress') &&
          isPlayerInRoom) {
        Logger.log(
            '🔍 復帰可能な部屋を検出: status=$roomStatus, isPlayerInRoom=$isPlayerInRoom');

        // ダイアログで確認
        final shouldReturn = await _showRoomReturnDialog();

        if (shouldReturn == null || !shouldReturn) {
          // 新しく部屋を作る選択
          Logger.log('🔍 ユーザーが新しい部屋作成を選択');
          ref
              .read(analyticsServiceProvider)
              .logUserProperty(property: 'roomID', value: '');
          await ref.read(userProvider.notifier).leaveRoom();
          _navigateToTop();
          return;
        }

        // 元の部屋に戻る選択 → 既存の復帰ロジックを継続
        Logger.log('🔍 ユーザーが部屋復帰を選択 → 復帰処理を継続');
      }

      switch (roomStatus) {
        case 'closed':
          ref
              .read(analyticsServiceProvider)
              .logUserProperty(property: 'roomID', value: '');
          await ref.read(userProvider.notifier).leaveRoom();
          _navigateToTop();
          return;
        case 'full':
          // ★ 注: ここに到達するケース
          // - ダイアログで「元の部屋に戻る」を選択した場合
          // - または isPlayerInRoom が false の場合（念のための安全策）
          if (!isPlayerInRoom) {
            _showErrorAndNavigateToTop('部屋の参加人数上限に達しています');
            return;
          }
          // 自分が含まれている場合は復帰処理を継続（break して次へ）
          break;
        case 'inProgress':
          break;
        case 'accepting':
          // ★ 注: ここに到達するケース
          // - ダイアログで「元の部屋に戻る」を選択した場合
          // - または isPlayerInRoom が false の場合（念のための安全策）
          if (!isPlayerInRoom) {
            _showErrorAndNavigateToTop('この部屋に参加する権限がありません');
            return;
          }
          // 自分が含まれている場合は SelectGamePage へ遷移
          _navigateToSelectGame();
          return;
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

        // 1. gamePhase が ended (結果画面) かどうかを確認
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

        // 2. gamePhase が started (ゲーム開始済み) かどうかを確認
        if (userState.gamePhase == GamePhase.started) {
          Logger.log('🎮 復帰: GamePhase.started -> ゲーム中の画面へ');
          // started であれば、localGameData (選択状態) を確認
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

        Logger.log('🎮 復帰: ゲームタイトル画面へ');

        ref.read(navigationServiceProvider).navigateToGameTitle();

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
          additionalParams: {'trigger_source': 'direct_room_url'});
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

  Future<String?> _fetchRoomStatus(String roomId) async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        return null;
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      return roomData['status'] as String?;
    } catch (e) {
      Logger.log('❌ 部屋ステータス取得エラー: $e');
      return null;
    }
  }

  /// 部屋復帰確認ダイアログ
  /// [hasUrlRoomId] がtrueの場合、URLに別の部屋IDが存在することを示す
  Future<bool?> _showRoomReturnDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('部屋への復帰'),
        content: const Text(
          '前回参加していた部屋が見つかりました。\n'
          '参加していた部屋に戻りますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('元の部屋に戻る'),
          ),
        ],
      ),
    );
  }

  void _clearUrlParameters() {
    if (kIsWeb) {
      try {
        final String currentUrl = html.window.location.href;

        // URLに ? が含まれている場合のみ処理
        if (currentUrl.contains('?')) {
          // ? より前の部分（Base URL + Path + Fragment）だけを取り出す
          final String newUrl = currentUrl.split('?')[0];

          // ブラウザの履歴を書き換え（リロードせずにURLをクリーンにする）
          html.window.history.replaceState(null, '', newUrl);
          Logger.log('🔍 URLを完全にクリーンにしました: $newUrl');
        }
      } catch (e) {
        Logger.log('❌ URLパラメータクリアエラー: $e');
      }
    }
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
