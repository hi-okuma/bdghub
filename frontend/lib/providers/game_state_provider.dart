import 'dart:async';
import 'package:bodogehub/utils/logger.dart';
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
    Logger.log('🔍 RoomGameStateNotifier.build called with roomId: $roomId');

    // ユーザー状態をチェック
    try {
      final userState = ref.read(userProvider);

      // uidが無効な場合は監視を開始しない
      if (userState.uid == null || userState.uid!.isEmpty) {
        Logger.log('🔍 Invalid user state - skipping monitoring');
        return GameStatus.waiting;
      }

      // roomIdが無効な場合も監視を開始しない
      if (roomId.isEmpty) {
        Logger.log('🔍 Invalid roomId - skipping monitoring');
        return GameStatus.waiting;
      }

      // 保存されたgamePhaseを取得して初期化
      _currentGamePhase = userState.gamePhase ?? GamePhase.initial;
      Logger.log('🔍 Initial GamePhase from storage: $_currentGamePhase');
    } catch (e) {
      Logger.log('🔍 Error reading user state - skipping monitoring: $e');
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
      Logger.log('🔍 Disposing RoomGameStateNotifier');
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
      Logger.log('🎮 GamePhase更新・保存: $newPhase');
    } catch (e) {
      Logger.log('⚠️ GamePhase保存エラー: $e');
    }
  }

  void _startMonitoring(String roomId) {
    Logger.log('🔍 Starting room monitoring for roomId: $roomId');

    if (_isDisposed) {
      Logger.log('🔍 Already disposed - skipping monitoring');
      return;
    }

    try {
      final userState = ref.read(userProvider);
      if (userState.uid == null || userState.uid!.isEmpty) {
        Logger.log('🔍 Invalid user state in _startMonitoring - aborting');
        return;
      }
    } catch (e) {
      Logger.log('🔍 Error reading user state in _startMonitoring: $e');
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
          Logger.log('🔍 Room document update received');

          if (_isDisposed) {
            Logger.log('🔍 Disposed during room update - stopping');
            return;
          }

          _handleRoomUpdate(roomId, doc);
        } catch (e, stackTrace) {
          Logger.log('❌ Exception in room listen callback: $e');
          Logger.log('❌ StackTrace: $stackTrace');
        }
      },
      onError: (error) {
        Logger.log('❌ Room monitoring error: $error');
        if (error.toString().contains('permission-denied')) {
          Logger.log('🔍 Permission denied - stopping monitoring gracefully');
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
        Logger.log('🔍 Notifier is disposed, skipping room update');
        return;
      }

      if (!doc.exists) {
        Logger.log('❌ Room document does not exist');
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
      Logger.log(
          '🔍 Room status: $roomStatus (previous: $_previousRoomStatus)');

      // ★修正: inProgressからacceptingへの変化でgamePhaseをリセット
      if (_previousRoomStatus == 'inProgress' && roomStatus == 'accepting') {
        Logger.log('🎮 ゲーム終了検知: inProgress → accepting');

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
            Logger.log('🎮 ゲーム選択画面への遷移完了');
          });

          state = const AsyncValue.data(GameStatus.waiting);
        }
        return;
      }

      // 部屋のステータスチェック
      if (roomStatus != 'inProgress') {
        Logger.log('🔍 Room not in progress, stopping all monitoring');
        _stopAllMonitoring();
        _resetNavigationFlags();
        if (!_isDisposed) {
          state = const AsyncValue.data(GameStatus.waiting);
        }
        return;
      }

      // roomStatusがinProgressになった時点でcurrentGameサブコレクションの監視を開始
      if (roomStatus == 'inProgress' && !_hasNavigatedToGameTitle) {
        Logger.log(
            '🎮 Room status is inProgress - Starting currentGame monitoring...');
        _startCurrentGameCollectionMonitoring(roomId);
      }

      if (_isDisposed) {
        Logger.log('🔍 Notifier was disposed during processing, aborting');
        return;
      }
    } catch (e, stackTrace) {
      Logger.log('❌ Exception in _handleRoomUpdate: $e');
      Logger.log('❌ StackTrace: $stackTrace');
      if (!_isDisposed) {
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  // 遷移処理の完全一元化
  void _executeNavigation(String screenKey, VoidCallback navigationCallback) {
    // 既に同じ画面への遷移中または完了している場合はスキップ
    if (_navigationInProgress || _lastNavigatedScreen == screenKey) {
      Logger.log(
          '🔍 Navigation skipped: $screenKey (inProgress: $_navigationInProgress, last: $_lastNavigatedScreen)');
      return;
    }

    _navigationInProgress = true;
    _lastNavigatedScreen = screenKey;

    try {
      navigationCallback();
      Logger.log('🎮 Navigation completed: $screenKey');
    } catch (e) {
      Logger.log('❌ Navigation error: $e');
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
    Logger.log('🔍 Monitoring currentGame collection: $collectionPath');

    _currentGameCollectionSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('currentGame')
        .snapshots()
        .listen(
      (querySnapshot) {
        try {
          Logger.log('🔍 currentGame collection update received');
          _handleCurrentGameCollectionUpdate(roomId, querySnapshot);
        } catch (e, stackTrace) {
          Logger.log('❌ Exception in currentGame collection callback: $e');
          Logger.log('❌ StackTrace: $stackTrace');
        }
      },
      onError: (error) {
        Logger.log('❌ currentGame collection monitoring error: $error');
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
      Logger.log('🔄 New game detected - clearing previous game data');
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
      Logger.log('🔍 復帰中のためタイトルへの自動遷移をスキップ');
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

      Logger.log('🎮 Game data loaded successfully - Navigating to GameTitle!');

      _executeNavigation('gameTitle', () {
        final navigationService = ref.read(navigationServiceProvider);
        navigationService.navigateToGameTitle();
      });

      _hasNavigatedToGameTitle = true;

      final gameStatus = _parseGameStatus(gameData['gameStatus']);
      Logger.log('🔍 Initial game status after load: $gameStatus');

      if (!_isDisposed) {
        state = AsyncValue.data(gameStatus);

        // 復帰時の処理を簡略化
        final userState = ref.read(userProvider);
        if (userState.isRestoring) {
          Logger.log('🔍 復帰時 - 現在の状態: $gameStatus');
          // 復帰時は特別な処理は不要（既にlocalStorageから正確なgamePhaseを取得済み）
        }
      }
    } catch (e) {
      Logger.log('❌ Failed to load game data: $e');
      if (!_isDisposed) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  // 特定のgameIdドキュメントの詳細監視（リアルタイム状態変化用）
  void _startGameDetailMonitoring(String roomId, String gameId) {
    _gameSubscription?.cancel();

    final docPath = 'rooms/$roomId/currentGame/$gameId';
    Logger.log('🔍 Starting detailed monitoring for: $docPath');

    _gameSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('currentGame')
        .doc(gameId)
        .snapshots()
        .listen(
      (doc) {
        Logger.log('🔍 Game detail document update received');
        Logger.log('🔍 Document exists: ${doc.exists}');
        if (doc.exists) {
          Logger.log('🔍 Document data: ${doc.data()}');
        }
        _handleGameDetailUpdate(doc);
      },
      onError: (error) {
        Logger.log('❌ Game detail monitoring error: $error');
        if (!_isDisposed) {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  void _handleGameDetailUpdate(DocumentSnapshot doc) {
    if (_isDisposed) {
      Logger.log('🔍 Notifier is disposed, skipping game detail update');
      return;
    }

    if (!doc.exists) {
      Logger.log('❌ Game detail document does not exist');
      // ドキュメントが存在しない場合は前回の状態をリセット
      _resetNavigationFlags();
      if (!_isDisposed) {
        state = const AsyncValue.data(GameStatus.waiting);
      }
      return;
    }

    final gameData = doc.data() as Map<String, dynamic>;
    Logger.log('🔍 Game detail data: $gameData');
    Logger.log('🔍 Raw gameStatus: ${gameData['gameStatus']}');

    // ★修正: 常にcurrentGameProviderを更新（画面遷移の有無に関わらず）
    // これにより、同じ画面にいる間にFirestoreのデータが更新された場合も
    // UIに反映されるようになる（例: hints提出後のボタン非活性化）
    ref.read(currentGameProvider.notifier).updateGameData(gameData);
    Logger.log('📊 currentGameProvider updated with latest gameData');

    // ゲーム状態の解析
    final gameStatus = _parseGameStatus(gameData['gameStatus']);
    Logger.log('🔍 Parsed gameStatus: $gameStatus');

    if (!_isDisposed) {
      state = AsyncValue.data(gameStatus);

      // 復帰処理か通常処理かで分岐
      final userState = ref.read(userProvider);
      if (userState.isRestoring) {
        Logger.log('🔍 復帰中のため自動遷移なし');
        // ★修正: 復帰時に保存済みgamePhaseを_currentGamePhaseへ復元する。
        // _resetNavigationFlagsで_currentGamePhaseはinitialに戻るため、
        // これを復元しないとリロード後にラウンドが終了(waiting)しても
        // 結果画面遷移条件(_currentGamePhase == GamePhase.started)を満たさず、
        // 結果発表画面に遷移せず次のお題が表示される不具合が発生する。
        // 永続化済みの値を読むだけなので_updateAndSaveGamePhaseは使わない。
        final savedPhase = userState.gamePhase;
        if (savedPhase != null) {
          _currentGamePhase = savedPhase;
          Logger.log('🔍 復帰時にgamePhaseを復元: $savedPhase');
        }
        // ★修正: 復帰時も現在の画面に対応するナビゲーションフラグを設定
        // これにより、復帰後にFirestoreが更新されても重複遷移を防ぐ
        _setNavigationFlagsForCurrentStatus(gameStatus);
        Logger.log('🔍 復帰時のナビゲーションフラグ設定完了: $gameStatus');

        // ★追加: 復帰処理が完了したことをUserProviderに通知
        // これにより、固定時間ではなくイベント駆動で復帰モードを解除できる
        _completeRestoration();
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
            Logger.log('🔍 すでにplayingページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.childTurn:
          if (_hasNavigatedToChildTurn) {
            Logger.log('🔍 すでにchildTurnページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.parentTurn:
          if (_hasNavigatedToParentTurn) {
            Logger.log('🔍 すでにparentTurnページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.result:
          if (_hasNavigatedToResult) {
            Logger.log('🔍 すでにresultページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.waiting:
          if (_currentGamePhase != GamePhase.started) {
            Logger.log('🔍 ゲーム開始前のwaitingのためスキップ');
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

  // ★追加: 復帰時に現在の画面状態に応じてナビゲーションフラグを設定
  // 画面遷移は行わず、フラグのみ設定することで、復帰後のFirestore更新時の重複遷移を防ぐ
  void _setNavigationFlagsForCurrentStatus(GameStatus status) {
    switch (status) {
      case GameStatus.playing:
        _hasNavigatedToPlaying = true;
        _previousGameStatus = GameStatus.playing;
        break;
      case GameStatus.childTurn:
        _hasNavigatedToChildTurn = true;
        _previousGameStatus = GameStatus.childTurn;
        break;
      case GameStatus.parentTurn:
        _hasNavigatedToParentTurn = true;
        _previousGameStatus = GameStatus.parentTurn;
        break;
      case GameStatus.result:
        _hasNavigatedToResult = true;
        _previousGameStatus = GameStatus.result;
        break;
      case GameStatus.waiting:
        // waitingの場合は特にフラグ設定不要
        break;
    }
  }

  // ★追加: 復帰処理完了をUserProviderに通知
  void _completeRestoration() {
    try {
      final userNotifier = ref.read(userProvider.notifier);
      // 少し遅延を入れて、Firestoreリスナーの初期化が確実に完了するようにする
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isDisposed) {
          userNotifier.completeRestoration();
          Logger.log('✅ 復帰処理完了通知をUserProviderに送信');
        }
      });
    } catch (e) {
      Logger.log('⚠️ 復帰処理完了通知エラー: $e');
    }
  }

  // ★修正: 遷移ロジックの一元化（gamePhase更新処理を追加）
  void _handleGameStateChange(
      GameStatus status, Map<String, dynamic> currentGame) {
    if (_isDisposed) {
      Logger.log('🔍 Notifier is disposed, skipping navigation');
      return;
    }

    final navigationService = ref.read(navigationServiceProvider);

    switch (status) {
      case GameStatus.playing:
        Logger.log(
            '🎮 Navigating to PlayingPage with currentGame: $currentGame');
        _executeNavigation('playing', () {
          navigationService.navigateToPlayingPage();
          _hasNavigatedToPlaying = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.childTurn:
        Logger.log('🎮 Navigating to ChildTurn');
        _executeNavigation('childTurn', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToChildTurn(currentGame);
          _hasNavigatedToChildTurn = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.parentTurn:
        Logger.log('🎮 Navigating to ParentTurn');
        _executeNavigation('parentTurn', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToParentTurn(currentGame);
          _hasNavigatedToParentTurn = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.result:
        Logger.log('🎮 Navigating to Result(currentGame)');
        _executeNavigation('checkAnswer', () {
          // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
          ref.read(currentGameProvider.notifier).updateGameData(currentGame);
          navigationService.navigateToCheckAnswer(currentGame);
          _hasNavigatedToResult = true;
          _updateAndSaveGamePhase(GamePhase.started); // ★追加: gamePhase更新
        });
        break;

      case GameStatus.waiting:
        Logger.log(
            '🎮 Waiting status detected - current phase: $_currentGamePhase');

        // ★追加: GameIDを取得
        final activeGameId = ref.read(currentGameProvider).gameId;

        // ★追加: GameID '0005' の場合の特例処理
        // '0005' はクライアント側で独自にPhase管理（結果画面への遷移など）を行っているため、
        // サーバー側のwaiting検知による「汎用結果画面への自動遷移」と「endedへの更新」をスキップする。
        if (activeGameId == '0005') {
          Logger.log('🎮 Game 0005: waiting検知による自動ended遷移をスキップします');
          // ここで break することで、下部の処理（endedへの更新など）を実行せずに抜ける
          break;
        }

        // ★追加: GameID '0006' の場合の特例処理
        // '0006' はプレイ画面内のダイアログで結果発表・リプレイを行うため、
        // 汎用の GameResultPage への自動遷移をスキップする。
        // フラグはリセットしない: リプレイ時に PlayingPage を再 push させず、
        // 既存ページ内の ref.listen でゲーム再開を処理する。
        if (activeGameId == '0006') {
          Logger.log('🎮 Game 0006: waiting検知による自動result遷移をスキップします');
          break;
        }

        if (_currentGamePhase == GamePhase.started) {
          Logger.log('🎮 Game ended - navigating to result page');
          _executeNavigation('result', () {
            // 結果画面へ遷移する直前に、最新のゲーム結果でProviderを更新する
            ref.read(currentGameProvider.notifier).updateGameData(currentGame);
            navigationService.navigateToResult(currentGame);
            _hasNavigatedToResult = true;
            _updateAndSaveGamePhase(GamePhase.ended); // ★追加: gamePhase更新
          });
        } else {
          Logger.log('🎮 Initial waiting - staying in GameTitle');
        }
        break;
    }
  }

  void stopMonitoring() {
    Logger.log('🔄 Stopping all monitoring...');

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
      Logger.log('⚠️ Error setting final state: $e');
    }

    Logger.log('🔄 All monitoring stopped');
  }
}

final roomGameStateProvider =
    AsyncNotifierProvider.family<RoomGameStateNotifier, GameStatus, String>(
  RoomGameStateNotifier.new,
);
