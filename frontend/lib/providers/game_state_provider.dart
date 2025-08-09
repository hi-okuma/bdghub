import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/navigation_service.dart';

// DB設計に基づくゲーム状態の列挙型
enum GameStatus {
  waiting, // ゲーム開始前/終了後
  playing, // ゲーム中（基本状態）
  childTurn, // 子ターン（0004のみ）
  parentTurn, // 親ターン（0004のみ）
}

// ゲームの進行段階を管理する内部状態
enum GamePhase {
  initial, // 初期状態（ゲーム開始前）
  started, // ゲーム開始済み
  ended, // ゲーム終了済み
}

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
  bool _hasNavigatedToPlaying = false; // playingページに遷移済みかどうか

  // ★ 追加: roomのstatusを保持 ★
  String? _currentRoomStatus;
  String? _previousRoomStatus; // ★ 前回のroom statusを保持

  String? _previousCurrentParent; // 前回の親プレイヤーを記録
  DateTime? _lastTransitionTime; // 最後の遷移時刻を記録
  Map<String, dynamic>? _previousGameData; // 前回のゲームデータを記録

  @override
  Future<GameStatus> build(String roomId) async {
    print('🔍 RoomGameStateNotifier.build called with roomId: $roomId');

    // ★ 修正: ユーザー状態をチェック ★
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
    } catch (e) {
      print('🔍 Error reading user state - skipping monitoring: $e');
      return GameStatus.waiting;
    }

    _isDisposed = false;
    _hasNavigatedToGameTitle = false;
    _previousGameStatus = null;
    _currentGamePhase = GamePhase.initial;
    _hasNavigatedToPlaying = false;
    _currentRoomStatus = null;
    _previousRoomStatus = null;

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

  void _startMonitoring(String roomId) {
    print('🔍 Starting room monitoring for roomId: $roomId');

    // ★ 修正: disposed状態チェック ★
    if (_isDisposed) {
      print('🔍 Already disposed - skipping monitoring');
      return;
    }

    // ★ 修正: ユーザー状態の再チェック ★
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

          // ★ 修正: 処理中にdisposed状態チェック ★
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

      // ★ room statusの変化を検知 ★
      _previousRoomStatus = _currentRoomStatus;
      _currentRoomStatus = roomStatus;
      print('🔍 Room status: $roomStatus (previous: $_previousRoomStatus)');

      // ★ 重要: inProgressからwaitingへの変化を検知 ★
      if (_previousRoomStatus == 'inProgress' && roomStatus == 'accepting') {
        print('🎮 ゲーム終了検知: inProgress → accepting');

        // 全ての監視を停止
        _stopAllMonitoring();
        _resetNavigationFlags();

        // ゲーム選択画面に遷移
        if (!_isDisposed) {
          try {
            final navigationService = ref.read(navigationServiceProvider);
            navigationService.navigateToSelectGame();
            print('🎮 ゲーム選択画面への遷移完了');
          } catch (e) {
            print('❌ Navigation error: $e');
          }

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

  // GameTitlePageへの遷移処理を分離
  void _navigateToGameTitle() {
    if (_isDisposed) {
      print('🔍 Notifier is disposed, skipping navigation to GameTitle');
      return;
    }

    try {
      final navigationService = ref.read(navigationServiceProvider);
      navigationService.navigateToGameTitle();
    } catch (e) {
      print('❌ Navigation error (likely disposed): $e');
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
    if (_isDisposed) {
      print('🔍 Notifier is disposed, skipping currentGame collection update');
      return;
    }

    print('🔍 currentGame documents count: ${querySnapshot.docs.length}');

    if (querySnapshot.docs.isEmpty) {
      print('🔍 No currentGame documents found');
      _stopGameMonitoring();

      // ★ 削除: ここでのゲーム選択画面遷移は行わない ★
      // room.statusの変化で遷移するため、ここでの遷移は不要

      if (!_isDisposed) {
        state = const AsyncValue.data(GameStatus.waiting);
      }
      return;
    }

    final gameDoc = querySnapshot.docs.first;
    final gameId = gameDoc.id;
    final gameData = gameDoc.data() as Map<String, dynamic>;

    print('🔍 Found gameId: $gameId');

    // ゲームデータを読み込んでから遷移
    _loadGameDataAndNavigate(roomId, gameId, gameData);

    // 既に同じgameIdを監視中の場合はスキップ
    if (_currentGameId == gameId) {
      print('🔍 Already monitoring gameId: $gameId');
      return;
    }

    // 新しいgameIdの詳細監視を開始
    _currentGameId = gameId;
    _startGameDetailMonitoring(roomId, gameId);
  }

  Future<void> _loadGameDataAndNavigate(
      String roomId, String gameId, Map<String, dynamic> gameData) async {
    try {
      // currentGameサブドキュメントからゲームデータを読み込み
      await ref
          .read(currentGameProvider.notifier)
          .loadFromCurrentGame(roomId, gameId);

      // 読み込み成功後に遷移
      if (!_hasNavigatedToGameTitle) {
        print('🎮 Game data loaded successfully - Navigating to GameTitle!');
        _navigateToGameTitle();
        _hasNavigatedToGameTitle = true;
      }

      // ゲーム状態更新
      final gameStatus = _parseGameStatus(gameData['gameStatus']);
      if (!_isDisposed) {
        state = AsyncValue.data(gameStatus);
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
      // 重複チェック付きの状態変化処理
      _handleGameStateChangeWithDuplicationCheck(gameStatus, gameData);
    }
  }

  // 重複チェック付きの状態変化処理を改善
  void _handleGameStateChangeWithDuplicationCheck(
      GameStatus currentStatus, Map<String, dynamic> currentGame) {
    final now = DateTime.now();
    final currentParent = currentGame['currentParent'] as String?;

    // API操作直後の短時間重複遷移を防ぐ（500ms以内）
    if (_lastTransitionTime != null &&
        now.difference(_lastTransitionTime!).inMilliseconds < 500) {
      print('🔍 API操作直後の重複遷移をスキップ');
      return;
    }

    // 前回と同じ状態で、かつ特定の条件の場合はスキップ
    if (_previousGameStatus == currentStatus) {
      switch (currentStatus) {
        case GameStatus.playing:
          if (_hasNavigatedToPlaying) {
            print('🔍 すでにplayingページに遷移済みのためスキップ');
            return;
          }
          break;
        case GameStatus.childTurn:
        case GameStatus.parentTurn:
          // ★ 修正: 同じ親プレイヤーかつ同じゲーム状態の場合はスキップ
          if (_previousCurrentParent == currentParent &&
              _isSameGameData(_previousGameData, currentGame)) {
            print('🔍 同じ親プレイヤー・同じゲーム状態のためスキップ');
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

    // 前回の状態を更新
    _previousGameStatus = currentStatus;
    _previousCurrentParent = currentParent;
    _previousGameData = Map<String, dynamic>.from(currentGame);
    _lastTransitionTime = now;

    // 実際の遷移処理を実行
    _handleGameStateChange(currentStatus, currentGame);
  }

  // ゲームデータの重要な部分が同じかどうかを判定
  bool _isSameGameData(
      Map<String, dynamic>? previous, Map<String, dynamic> current) {
    if (previous == null) return false;

    // 重要な状態が変わっていないかチェック
    final prevParent = previous['currentParent'];
    final currParent = current['currentParent'];

    final prevHints = previous['hints'] as Map<String, dynamic>? ?? {};
    final currHints = current['hints'] as Map<String, dynamic>? ?? {};

    final prevAnswerIndex = previous['answerImageIndex'];
    final currAnswerIndex = current['answerImageIndex'];

    // 親プレイヤー、ヒント数、回答画像インデックスが同じ場合は同じ状態と判定
    return prevParent == currParent &&
        prevHints.length == currHints.length &&
        prevAnswerIndex == currAnswerIndex;
  }

  void _stopAllMonitoring() {
    _currentGameCollectionSubscription?.cancel();
    _stopGameMonitoring();
  }

  void _stopGameMonitoring() {
    _gameSubscription?.cancel();
    _currentGameId = null;
  }

  // リセット処理にも追加
  void _resetNavigationFlags() {
    _hasNavigatedToGameTitle = false;
    _previousGameStatus = null;
    _currentGamePhase = GamePhase.initial;
    _hasNavigatedToPlaying = false;
    _currentGameId = null;
    _previousCurrentParent = null; // ★ 追加
    _lastTransitionTime = null; // ★ 追加
    _previousGameData = null; // ★ 追加
  }

  GameStatus _parseGameStatus(dynamic status) {
    switch (status?.toString()) {
      case 'playing':
        return GameStatus.playing;
      case 'childTurn':
        return GameStatus.childTurn;
      case 'parentTurn':
        return GameStatus.parentTurn;
      default:
        return GameStatus.waiting;
    }
  }

  // ゲーム状態変化に基づく遷移処理
  void _handleGameStateChange(
      GameStatus status, Map<String, dynamic> currentGame) {
    if (_isDisposed) {
      print('🔍 Notifier is disposed, skipping navigation');
      return;
    }

    try {
      final navigationService = ref.read(navigationServiceProvider);

      switch (status) {
        case GameStatus.playing:
          print('🎮 Navigating to PlayingPage with currentGame: $currentGame');
          navigationService.navigateToPlayingPage();
          _hasNavigatedToPlaying = true;
          _currentGamePhase = GamePhase.started; // ゲーム開始段階に更新
          break;
        case GameStatus.childTurn:
          print('🎮 Navigating to ChildTurn');
          navigationService.navigateToChildTurn(currentGame);
          _currentGamePhase = GamePhase.started; // ゲーム開始段階に更新
          break;
        case GameStatus.parentTurn:
          print('🎮 Navigating to ParentTurn');
          navigationService.navigateToParentTurn(currentGame);
          _currentGamePhase = GamePhase.started; // ゲーム開始段階に更新
          break;
        case GameStatus.waiting:
          print(
              '🎮 Waiting status detected - current phase: $_currentGamePhase');
          if (_currentGamePhase == GamePhase.started) {
            // ゲーム中からwaitingになった場合は必ず結果画面に遷移
            print('🎮 Game ended - navigating to result');
            navigationService.navigateToResult(currentGame);
            _currentGamePhase = GamePhase.ended; // ゲーム終了段階に更新
          } else {
            // 初期状態やゲーム終了後のwaiting = ゲームタイトル画面への遷移（既に処理済みの場合はスキップ）
            print(
                '🎮 Initial waiting or post-game waiting - staying in current state');
          }
          break;
      }
    } catch (e) {
      print('❌ Navigation error (likely disposed): $e');
    }
  }

  void stopMonitoring() {
    print('🔄 Stopping all monitoring...');

    // ★ 修正: disposed フラグを設定して新しい監視を防ぐ ★
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
