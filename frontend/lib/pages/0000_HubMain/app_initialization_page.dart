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
      _clearUrlParameters();
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // 認証とストレージ読み込みを同時に開始
      final results = await Future.wait([
        AuthService.ensureAuthenticated(),
        ref
            .read(userProvider.notifier)
            .loadRawDataFromStorage(), // 認証を待たずにlocalStorageからデータを取得しておく
      ]);

      final String currentUid = results[0] as String;
      final Map<String, dynamic>? rawData = results[1] as Map<String, dynamic>?;

      // 認証完了後に、取得済みのデータを使って復帰ロジックを走らせる
      final restoreSuccess = await ref
          .read(userProvider.notifier)
          .tryRestoreWithData(currentUid, rawData);

      if (restoreSuccess) {
        final restoredRoomId = ref.read(userProvider).roomId;
        // 事前にステータスを取得しておく
        final restoredRoomStatus = await _fetchRoomStatus(restoredRoomId!);

        if (widget.urlRoomId == null ||
            widget.urlRoomId!.isEmpty ||
            restoredRoomId == widget.urlRoomId) {
          // IDが一致、またはURLにIDがない（通常起動）場合は、メソッド内での判定に任せる
          await _handleDetailedGameStateRestore(
              initialRoomStatus: restoredRoomStatus);
        } else {
          Logger.log(
              '🔍 部屋の不一致を検出: localStorage=$restoredRoomId, URL=${widget.urlRoomId}');

          // localStorageの部屋が有効な場合のみダイアログを表示
          if (_isRoomActive(restoredRoomStatus)) {
            final shouldReturnToSavedRoom = await _showRoomReturnDialog();

            if (shouldReturnToSavedRoom == true) {
              // ここで確認済みのため skipConfirmation: true を渡す
              await _handleDetailedGameStateRestore(
                initialRoomStatus: restoredRoomStatus,
                skipConfirmation: true,
              );
              return;
            } else {
              await _cleanupAndNavigateToJoinRoom(widget.urlRoomId!);
            }
          } else {
            // 有効でない（closed等）場合はURLを優先
            await _cleanupAndNavigateToJoinRoom(widget.urlRoomId!);
          }
        }
      } else {
        if (widget.urlRoomId != null && widget.urlRoomId!.isNotEmpty) {
          _navigateToJoinRoom(widget.urlRoomId!, true);
        } else {
          _navigateToTop();
        }
      }
    } catch (e) {
      Logger.log('❌ アプリ初期化エラー: $e');
      _showErrorAndNavigateToTop('アプリの初期化に失敗しました');
    }
  }

  /// 詳細なゲーム状態復帰処理
  /// [initialRoomStatus] が渡された場合は Firestore への再問い合わせをスキップする
  /// [skipConfirmation] が true の場合、復帰確認ダイアログの表示をスキップする
  Future<void> _handleDetailedGameStateRestore({
    String? initialRoomStatus,
    bool skipConfirmation = false,
  }) async {
    try {
      final userState = ref.read(userProvider);
      final roomId = userState.roomId;

      if (roomId == null) {
        _navigateToTop();
        return;
      }

      // ステータスが未取得なら取得
      final roomStatus = initialRoomStatus ?? await _fetchRoomStatus(roomId);

      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        _showErrorAndNavigateToTop('部屋が見つかりませんでした');
        return;
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final players = roomData['players'] as Map<String, dynamic>? ?? {};
      final currentUid = userState.uid;
      final isPlayerInRoom =
          currentUid != null && players.containsKey(currentUid);

      // ダイアログ表示の判定
      // skipConfirmation が false の場合のみ表示（通常起動時など）
      if (!skipConfirmation && _isRoomActive(roomStatus) && isPlayerInRoom) {
        Logger.log('🔍 復帰確認が必要な状態を検出 (通常起動フロー)');
        final shouldReturn = await _showRoomReturnDialog();

        if (shouldReturn == null || !shouldReturn) {
          await _cleanupAndLeaveToTop();
          return;
        }
      }

      // 以降、部屋のステータスに応じた遷移ロジック
      switch (roomStatus) {
        case 'closed':
          await _cleanupAndLeaveToTop();
          return;
        case 'full':
        case 'inProgress':
          if (!isPlayerInRoom) {
            _showErrorAndNavigateToTop('部屋に参加する権限がないか、満員です');
            return;
          }
          break;
        case 'accepting':
          if (!isPlayerInRoom) {
            _showErrorAndNavigateToTop('この部屋に参加する権限がありません');
            return;
          }
          // ゲーム選択画面への復帰ではcurrentGameの監視が発火しないため、
          // ここで明示的に復帰モードを終了する
          ref.read(userProvider.notifier).completeRestoration();
          _navigateToSelectGame();
          return;
        default:
          ref.read(userProvider.notifier).completeRestoration();
          _navigateToSelectGame();
          return;
      }

      // currentGame 以下の詳細復帰ロジック（ gameId == '0005' の処理など）
      await _restoreCurrentGameLogic(roomId, userState, roomData);
    } catch (e) {
      Logger.log('❌ 詳細ゲーム状態復帰エラー: $e');
      _showErrorAndNavigateToTop('ゲーム状態の復帰に失敗しました');
    }
  }

  /// currentGame 以下の復帰ロジック（可読性のため分離）
  Future<void> _restoreCurrentGameLogic(
      String roomId, UserState userState, Map<String, dynamic> roomData) async {
    final currentGameQuery = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('currentGame')
        .get();

    if (currentGameQuery.docs.isEmpty) {
      // currentGameが空のためcurrentGameの監視が発火しない。
      // ここで明示的に復帰モードを終了する
      ref.read(userProvider.notifier).completeRestoration();
      _navigateToSelectGame();
      return;
    }

    final gameDoc = currentGameQuery.docs.first;
    final gameId = gameDoc.id;
    final gameData = gameDoc.data();
    final gameStatus = _parseGameStatus(gameData['gameStatus']);
    final savedGamePhase = userState.gamePhase ?? GamePhase.initial;

    await ref
        .read(currentGameProvider.notifier)
        .loadFromCurrentGame(roomId, gameId);
    if (!mounted) return;

    if (gameId == '0005') {
      _handleSoloBiasProfileRestore(roomId, userState);
      return;
    }

    final navigationService = ref.read(navigationServiceProvider);

    // 0006 はプレイ画面内ダイアログで結果・年代選択を表示するため、
    // gameStatus に関わらず常に PlayingPage に遷移させ、
    // ダイアログ復帰はページ側の initState で行う
    if (gameId == '0006') {
      navigationService.navigateToPlayingPage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(roomGameStateProvider(roomId));
      });
      return;
    }

    if (gameStatus == GameStatus.waiting) {
      if (savedGamePhase == GamePhase.ended) {
        navigationService.navigateToResult(gameData);
      } else {
        navigationService.navigateToGameTitle();
      }
    } else {
      navigationService.navigateToGameScreenByStatus(gameStatus, gameData,
          isRestore: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomGameStateProvider(roomId));
    });
  }

  void _handleSoloBiasProfileRestore(String roomId, UserState userState) {
    if (userState.gamePhase == GamePhase.ended) {
      ref.read(navigationServiceProvider).navigateToSoloBiasProfileResultPage();
    } else if (userState.gamePhase == GamePhase.started) {
      ref
          .read(navigationServiceProvider)
          .navigateToSoloBiasProfileRestore(userState.localGameData);
    } else {
      ref.read(navigationServiceProvider).navigateToGameTitle();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomGameStateProvider(roomId));
    });
  }

  bool _isRoomActive(String? status) {
    return status == 'accepting' || status == 'full' || status == 'inProgress';
  }

  Future<void> _cleanupAndLeaveToTop() async {
    ref
        .read(analyticsServiceProvider)
        .logUserProperty(property: 'roomID', value: '');
    await ref.read(userProvider.notifier).leaveRoom();
    _navigateToTop();
  }

  Future<void> _cleanupAndNavigateToJoinRoom(String roomId) async {
    ref
        .read(analyticsServiceProvider)
        .logUserProperty(property: 'roomID', value: '');
    await ref.read(userProvider.notifier).leaveRoom();
    _navigateToJoinRoom(roomId, true);
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

      // data() の結果を Map<String, dynamic> として扱うようキャストする
      final data = roomDoc.data();
      return data?['status'] as String?;
    } catch (e) {
      Logger.log('❌ 部屋ステータス取得エラー: $e');
      return null;
    }
  }

  Future<bool?> _showRoomReturnDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('部屋への復帰'),
        content: const Text(
          '参加中の部屋が見つかりました。\n'
          '戻らない場合は途中退出となり、参加していた部屋の進行に影響があります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('退出してTOPへ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('部屋に戻る'),
          ),
        ],
      ),
    );
  }

  void _clearUrlParameters() {
    if (kIsWeb) {
      try {
        final String currentUrl = html.window.location.href;
        if (currentUrl.contains('?')) {
          final String newUrl = currentUrl.split('?')[0];
          html.window.history.replaceState(null, '', newUrl);
          Logger.log('🔍 URLをクリーンにしました: $newUrl');
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
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
