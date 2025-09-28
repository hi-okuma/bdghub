import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bodogehub/models/game_enums.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/navigation_service.dart';

// rooms/{roomId}/currentGame サブコレクションを監視するNotifier
class RoomGameStateNotifier extends FamilyAsyncNotifier<GameStatus, String> {
  StreamSubscription? _roomSubscription;
  StreamSubscription? _currentGameCollectionSubscription;
  StreamSubscription? _gameSubscription;
  bool _isDisposed = false;
  String? _currentGameId; // 現在監視中のgameIdを保持
  bool _hasNavigatedToGameTitle = false; // GameTitlePageに遷移済みかどうかのフラグ

  // 重複遷移防止のためのフラグ
  GameStatus? _previousGameStatus;
  GamePhase _currentGamePhase = GamePhase.initial;
  bool _hasNavigatedToPlaying = false; // Playingページに遷移済みかどうか
  bool _hasNavigatedToChildTurn = false; // ChildTurnページに遷移済みかどうか
  bool _hasNavigatedToParentTurn = false; // ParentTurnページに遷移済みかどうか
  bool _hasNavigatedToResult = false; // Resultページに遷移済みかどうか

  // roomのstatusを保持
  String? _currentRoomStatus;
  String? _previousRoomStatus; // 前回のroom statusを保持

  // 遷移制御の完全な一元化
  bool _navigationInProgress = false; // 遷移処理中フラグ
  String? _lastNavigatedScreen; // 最後に遷移した画面を記録

  @override
  Future<GameStatus> build(String roomId) async {
    print('🔍 RoomGameStateNotifier.build called with roomId: $roomId');

    // ユーザー状態をチェック
    try {
      final userState = ref.read(userProvider);

      // uidが無効な場合は監視を開始しない
      if (userState.uid == null || userState.uid!.isEmpty) {
        print('🔍 Invalid user state - skipping monitoring');
        return GameStatus.waiting;
      }

      // roomIdが無効な場合も監視を開始しない
      if (roomId.isEmpty) {
        print('🔍 Invalid roomId - skipping monitoring');
        return GameStatus.waiting;
      }

      // 保存されたgamePhaseを取得して初期化
      _currentGamePhase = userState.gamePhase ?? GamePhase.initial;
      print('🔍 Initial GamePhase from storage: $_currentGamePhase');
    } catch (e) {
      print('🔍 Error reading user state - skipping monitoring: $e');
      return GameStatus.waiting;
    }

    _isDisposed = false;
    _hasNavigatedToGameTitle = false;
    _previousGameStatus = null;
    _hasNavigatedToPlaying = false;
    _hasNavigatedToChildTurn = false;
    _currentRoomStatus = null;
    _previousRoomStatus = null;
    _navigationInProgress = false;
    _lastNavigatedScreen = null;

    ref.onDispose(() {
      print('🔍 Disposing RoomGameStateNotifier');
      _isDisposed = true;
      _roomSubscription?.cancel();
      _currentGameCollectionSubscription?.cancel();
      _gameSubscription?.cancel();
    });

    // 監視開始
    _startMonitoring(roomId);
    return GameStatus.waiting;
  }

  // ★追加: gamePhase更新・保存メソッド
  void _updateAndSaveGamePhase(GamePhase newPhase) {
    _currentGamePhase = newPhase;

    try {
      // UserNotifierのgamePhaseも更新
      final userNotifier = ref.read(userProvider.notifier);
      userNotifier.updateGamePhase(newPhase);
      print('🎮 GamePhase更新・保存: $newPhase');
    } catch (e) {
      print('⚠️ GamePhase保存エラー: $e');
    }
  }

  void _startMonitoring(String roomId) {
    print('🔍 Starting room monitoring for roomId: $roomId');

    if (_isDisposed) {
      print('🔍 Already disposed - skipping monitoring');
      return;
    }

    try {
      final userState = ref.read(userProvider);
      if (userState.uid == null || userState.uid!.isEmpty) {
        print('🔍 Invalid user state in _startMonitoring - aborting');
        return;
      }
    } catch (e) {
      print('🔍 Error reading user state in _startMonitoring: $e');
      return;
    }

    _roomSubscription?.cancel();

    // まず部屋の基本状態を監視
    _roomSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen(
      (doc) {
        try {
          print('🔍 Room document update received');

          if (_isDisposed) {
            print('🔍 Disposed during room update - stopping');
            return;
          }

          _handleRoomUpdate(roomId, doc);
        } catch (e, stackTrace) {
          print('❌ Exception in room listen callback: $e');
          print('❌ StackTrace: $stackTrace');
        }
      },
      onError: (error) {
        print('❌ Room monitoring error: $error');
        if (error.toString().contains('permission-denied')) {
          print('🔍 Permission denied - stopping monitoring gracefully');
          _stopAllMonitoring();
        } else if (!_isDisposed) {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  void _handleRoomUpdate(String roomId, DocumentSnapshot doc) {
    try {
      if (_isDisposed) {
        print('🔍 Notifier is disposed, skipping room update');
        return;
      }

      if (!doc.exists) {
        print('❌ Room document does not exist');
        _stopAllMonitoring();
        _resetNavigationFlags();
        if (!_isDisposed) {
          state = const AsyncValue.data(GameStatus.waiting);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>?;
      final roomStatus = data?['status'] as String?;

      // room statusの変化を検知
      _previousRoomStatus = _currentRoomStatus;
      _currentRoomStatus = roomStatus;
      print('🔍 Room status: $roomStatus (previous: $_previousRoomStatus)');

      // ★修正: inProgressからacceptingへの変化でgamePhaseをリセット
      if (_previousRoomStatus == 'inProgress' && roomStatus == 'accepting') {
        print('🎮 ゲーム終了検知: inProgress → accepting');

        // ゲーム選択画面に戻る前に、現在のゲーム情報をクリアする
        ref.read(currentGameProvider.notifier).clearGame();

        // gamePhaseを初期状態にリセット
        _updateAndSaveGamePhase(GamePhase.initial);

        // 全ての監視を停止
        _stopAllMonitoring();
        _resetNavigationFlags();

        // ゲーム選択画面に遷移
        if (!_isDisposed) {
          _executeNavigation('selectGame', () {
            final navigationService = ref.read(navigationServiceProvider);
            navigationService.navigateToSelectGame();
            print('🎮 ゲーム選択画面への遷移完了');
          });

          state = const AsyncValue.data(GameStatus.waiting);
        }
        return;
      }

      // 部屋のステータスチェック
      if (roomStatus != 'inProgress') {
        print('🔍 Room not in progress, stopping all monitoring');
        _stopAllMonitoring();
        _resetNavigationFlags();
        if (!_isDisposed) {
          state = const AsyncValue.data(GameStatus.waiting);
        }
        return;
      }

      // roomStatusがinProgressになった時点でcurrentGameサブコレクションの監視を開始
      if (roomStatus == 'inProgress' && !_hasNavigatedToGameTitle) {
        print(
            '🎮 Room status is inProgress - Starting currentGame monitoring...');
        _startCurrentGameCollectionMonitoring(roomId);
      }

      if (_isDisposed) {
        print('🔍 Notifier was disposed during processing, aborting');
        return;
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _handleRoomUpdate: $e');
      print('❌ StackTrace: $stackTrace');
      if (!_isDisposed) {
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  // 遷移処理の完全一元化
  void _executeNavigation(String screenKey, VoidCallback navigationCallback) {
    // 既に同じ画面への遷移中または完了している場合はスキップ
    if (_navigationInProgress || _lastNavigatedScreen == screenKey) {
      print(
          '🔍 Navigation skipped: $screenKey (inProgress: $_navigationInProgress, last: $_lastNavigatedScreen)');
      return;
    }

    _navigationInProgress = true;
    _lastNavigatedScreen = screenKey;

    try {
      navigationCallback();
      print('🎮 Navigation completed: $screenKey');
    } catch (e) {
      print('❌ Navigation error: $e');
    } finally {
      // 少し遅延を入れて次の遷移を可能にする
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigationInProgress = false;
      });
    }
  }

  // currentGameサブコレクション全体を監視
  void _startCurrentGameCollectionMonitoring(String roomId) {
    _currentGameCollectionSubscription?.cancel();

    final collectionPath = 'rooms/$roomId/currentGame';
    print('🔍 Monitoring currentGame collection: $collectionPath');

    _currentGameCollectionSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('currentGame')
        .snapshots()
        .listen(
      (querySnapshot) {
        try {
          print('🔍 currentGame collection update received');
          _handleCurrentGameCollectionUpdate(roomId, querySnapshot);
        } catch (e, stackTrace) {
          print('❌ Exception in currentGame collection callback: $e');
          print('❌ StackTrace: $stackTrace');
        }
      },
      onError: (error) {
        print('❌ currentGame collection monitoring error: $error');
        if (!_isDisposed) {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  void _handleCurrentGameCollectionUpdate(
      String roomId, QuerySnapshot querySnapshot) {
    if (_isDisposed) return;

    if (querySnapshot.docs.isEmpty) {
      _stopGameMonitoring();
      state = const AsyncValue.data(GameStatus.waiting);
      return;
    }

    final gameDoc = querySnapshot.docs.first;
    final gameId = gameDoc.id;
    final gameData = gameDoc.data() as Map<String, dynamic>;

    // 新しいゲームを検知したら必ずクリア
    if (_currentGameId != gameId && _currentGameId != null) {
      print('🔄 New game detected - clearing previous game data');
      ref.read(currentGameProvider.notifier).clearGame();
      _resetNavigationFlags();
      _hasNavigatedToGameTitle = false;
    }

    // データ読み込みと遷移
    if (!_hasNavigatedToGameTitle || _currentGameId != gameId) {
      _loadGameDataAndNavigateToTitle(roomId, gameId, gameData);
    }

    _currentGameId = gameId;
    _startGameDetailMonitoring(roomId, gameId);
  }

  // 初回のゲームデータ読み込みとタイトル遷移のみ
  Future<void> _loadGameDataAndNavigateToTitle(
      String roomId, String gameId, Map<String, dynamic> gameData) async {
    // 復帰処理中の場合は、タイトル画面への自動遷移をスキップする
    final userState = ref.read(userProvider);
    if (userState.isRestoring) {
      print('🔍 復帰中のためタイトルへの自動遷移をスキップ');
      // ゲームデータの読み込みは行うが、画面遷移は行わない
      await ref
          .read(currentGameProvider.notifier)
          .loadFromCurrentGame(roomId, gameId);
      _hasNavigatedToGameTitle = true; // 遷移したことにして、重複処理を防ぐ
      return; // ここで処理を中断
    }

    try {
      await ref
          .read(currentGameProvider.notifier)
          .loadFromCurrentGame(roomId, gameId);

      print('🎮 Game data loaded successfully - Navigating to GameTitle!');

      _executeNavigation('gameTitle', () {
        final navigationService = ref.read(navigationServiceProvider);
        navigationService.navigateToGameTitle();
      });

      _hasNavigatedToGameTitle = true;

      final gameStatus = _parseGameStatus(gameData['gameStatus']);
      print('🔍 Initial game status after load: $gameStatus');

      if (!_isDisposed) {
        state = AsyncValue.data(gameStatus);

        // 復帰時の処理を簡略化
        final userState = ref.read(userProvider);
        if (userState.isRestoring) {
          print('🔍 復帰時 - 現在の状態: $gameStatus');
          // 復帰時は特別な処理は不要（既にlocalStorageから正確なgamePhaseを取得済み）
        }
      }
    } catch (e) {
      print('❌ Failed to load game data: $e');
      if (!_isDisposed) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  // 特定のgameIdドキュメントの詳細監視（リアルタイム状態変化用）
  void _startGameDetailMonitoring(String roomId, String gameId) {
    _gameSubscription?.cancel();

    final docPath = 'rooms/$roomId/currentGame/$gameId';
    print('🔍 Starting detailed monitoring for: $docPath');

    _gameSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('currentGame')
        .doc(gameId)
        .snapshots()
        .listen(
      (doc) {
        print('🔍 Game detail document update received');
        print('🔍 Document exists: ${doc.exists}');
        if (doc.exists) {
          print('🔍 Document data: ${doc.data()}');
        }
        _handleGameDetailUpdate(doc);
      },
      onError: (error) {
        print('❌ Game detail monitoring error: $error');
        if (!_isDisposed) {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  void _handleGameDetailUpdate(DocumentSnapshot doc) {
    if (_isDisposed) {
      print('🔍 Notifier is disposed, skipping game detail update');
      return;
    }

    if (!doc.exists) {
      print('❌ Game detail document does not exist');
      // ドキュメントが存在しない場合は前回の状態をリセット
      _resetNavigationFlags();
      if (!_isDisposed) {
        state = const AsyncValue.data(GameStatus.waiting);
      }
      return;
    }

    final gameData = doc.data() as Map<String, dynamic>;
    print('🔍 Game detail data: $gameData');
    print('🔍 Raw gameStatus: ${gameData['gameStatus']}');

    // ゲーム状態の解析
    final gameStatus = _parseGameStatus(gameData['gameStatus']);
    print('🔍 Parsed gameStatus: $gameStatus');

    if (!_isDisposed) {
      state = AsyncValue.data(gameStatus);

      // 復帰処理か通常処理かで分岐
      final userState = ref.read(userProvider);
      if (userState.isRestoring) {
        print('🔍 復帰中のため自動遷移なし');
      } else {
        _handleGameStateChangeWithDuplicationCheck(gameStatus, gameData);
      }
    }
  }

  // 重複チェック付きの状態変化処理
  void _handleGameStateChangeWithDuplicationCheck(
      GameStatus currentStatus, Map<String, dynamic> currentGame) {
    // 既存の重複チェック処理
    if (_previousGameStatus == currentStatus) {
      switch (currentStatus) {
        case GameStatus.playing:
          if (_hasNavigatedToPlaying) {
            print('🔍 すでにplayingページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.childTurn:
          if (_hasNavigatedToChildTurn) {
            print('🔍 すでにchildTurnページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.parentTurn:
          if (_hasNavigatedToParentTurn) {
            print('🔍 すでにparentTurnページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.result:
          if (_hasNavigatedToResult) {
            print('🔍 すでにresultページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.waiting:
          if (_currentGamePhase != GamePhase.started) {
            print('🔍 ゲーム開始前のwaitingのためスキップ');
            return;
          }
          break;
      }
    }

    _previousGameStatus = currentStatus;
    _handleGameStateChange(currentStatus, currentGame);
  }

  void _stopAllMonitoring() {
    _currentGameCollectionSubscription?.cancel();
    _stopGameMonitoring();
  }

  void _stopGameMonitoring() {
    _gameSubscription?.cancel();
    _currentGameId = null;
  }

  // リセット処理
  void _resetNavigationFlags() {
    _hasNavigatedToGameTitle = false;
    _previousGameStatus = null;
    _currentGamePhase = GamePhase.initial;
    _hasNavigatedToPlaying = false;
    _hasNavigatedToChildTurn = false;
    _hasNavigatedToParentTurn = false;
    _hasNavigatedToResult = false;
    _currentGameId = null;
    _navigationInProgress = false;
    _lastNavigatedScreen = null;
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

  // ★修正: 遷移ロジックの一元化（gamePhase更新処理を追加）
  void _handleGameStateChange(
      GameStatus status, Map<String, dynamic> currentGame) {
    if (_isDisposed) {
      print('🔍 Notifier is disposed, skipping navigation');
      return;
    }

    final navigationService = ref.read(navigationServiceProvider);

    switch (status) {
      case GameStatus.playing:
        print('🎮 Navigating to PlayingPage with currentGame: $currentGame');
        _executeNavigation('playing', () {
          navigationService.navigateToPlayingPage();
          _hasNavigatedToPlaying = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.childTurn:
        print('🎮 Navigating to ChildTurn');
        _executeNavigation('childTurn', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToChildTurn(currentGame);
          _hasNavigatedToChildTurn = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.parentTurn:
        print('🎮 Navigating to ParentTurn');
        _executeNavigation('parentTurn', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToParentTurn(currentGame);
          _hasNavigatedToParentTurn = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.result:
        print('🎮 NavinavigateToResult(currentGame)');
        _executeNavigation('checkAnswer', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToCheckAnswer(currentGame);
          _hasNavigatedToResult = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.waiting:
        print('🎮 Waiting status detected - current phase: $_currentGamePhase');

        if (_currentGamePhase == GamePhase.started) {
          print('🎮 Game ended - navigating to result page');
          _executeNavigation('result', () {
            // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
            ref.read(currentGameProvider.notifier).updateGameData(currentGame);
            navigationService.navigateToResult(currentGame);
            _hasNavigatedToResult = true;
            _updateAndSaveGamePhase(GamePhase.ended); // ★追加: gamePhase更新
          });
        } else {
          print('🎮 Initial waiting - staying in GameTitle');
        }
        break;
    }
  }

  void stopMonitoring() {
    print('🔄 Stopping all monitoring...');

    // disposed フラグを設定して新しい監視を防ぐ
    _isDisposed = true;

    // 全ての監視を停止
    _roomSubscription?.cancel();
    _roomSubscription = null;

    _currentGameCollectionSubscription?.cancel();
    _currentGameCollectionSubscription = null;

    _gameSubscription?.cancel();
    _gameSubscription = null;

    // 状態をリセット
    _currentGameId = null;
    _resetNavigationFlags();

    // 最終状態を設定（disposed状態でない場合のみ）
    try {
      if (!_isDisposed) {
        state = const AsyncValue.data(GameStatus.waiting);
      }
    } catch (e) {
      print('⚠️ Error setting final state: $e');
    }

    print('🔄 All monitoring stopped');
  }
}

final roomGameStateProvider =
    AsyncNotifierProvider.family<RoomGameStateNotifier, GameStatus, String>(
  RoomGameStateNotifier.new,
);
