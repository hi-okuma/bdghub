import 'package:bodogehub/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_state.dart'; // ★UserStateはmodelsからインポート
import '../models/game_enums.dart';
import '../providers/room_provider.dart';
import '../providers/game_state_provider.dart';
import '../services/auth_service.dart';

class UserNotifier extends StateNotifier<UserState> {
  final Ref _ref;
  static const String _roomIdKey = 'current_room_id';
  static const String _userNicknameKey = 'user_nickname';
  static const String _userUidKey = 'user_uid';
  static const String _isHostKey = 'is_host';
  static const String _gamePhaseKey = 'game_phase';

  UserNotifier(this._ref) : super(const UserState());

  // localStorage操作メソッド
  Future<void> _saveToStorage({
    required String roomId,
    required String nickname,
    required String uid,
    required bool isHost,
    GamePhase? gamePhase, // 追加
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roomIdKey, roomId);
      await prefs.setString(_userNicknameKey, nickname);
      await prefs.setString(_userUidKey, uid);
      await prefs.setBool(_isHostKey, isHost);

      // gamePhaseの保存
      if (gamePhase != null) {
        await prefs.setString(_gamePhaseKey, gamePhase.name);
        Logger.log('💾 gamePhase保存: $gamePhase');
      }

      Logger.log('💾 ローカルストレージに保存: roomId=$roomId, nickname=$nickname');
    } catch (e) {
      Logger.log('⚠️ ローカルストレージ保存エラー: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomId = prefs.getString(_roomIdKey);
      final nickname = prefs.getString(_userNicknameKey);
      final uid = prefs.getString(_userUidKey);
      final isHost = prefs.getBool(_isHostKey) ?? false;

      // gamePhaseの読み込み
      final gamePhaseStr = prefs.getString(_gamePhaseKey);
      GamePhase? gamePhase;
      if (gamePhaseStr != null) {
        try {
          gamePhase = GamePhase.values.byName(gamePhaseStr);
          Logger.log('💾 gamePhase復元: $gamePhase');
        } catch (e) {
          Logger.log('⚠️ gamePhase復元エラー: $e');
          gamePhase = GamePhase.initial; // デフォルト値
        }
      }

      if (roomId != null && nickname != null && uid != null) {
        return {
          'roomId': roomId,
          'nickname': nickname,
          'uid': uid,
          'isHost': isHost,
          'gamePhase': gamePhase, // 追加
        };
      }
    } catch (e) {
      Logger.log('⚠️ ローカルストレージ読み込みエラー: $e');
    }
    return null;
  }

  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roomIdKey);
      await prefs.remove(_userNicknameKey);
      await prefs.remove(_userUidKey);
      await prefs.remove(_isHostKey);
      await prefs.remove(_gamePhaseKey); // 追加
      Logger.log('🗑️ ローカルストレージをクリア');
    } catch (e) {
      Logger.log('⚠️ ローカルストレージクリアエラー: $e');
    }
  }

  // gamePhase更新メソッドを追加
  void updateGamePhase(GamePhase gamePhase) async {
    state = state.copyWith(gamePhase: gamePhase);

    // 現在保存されている情報と一緒に更新
    if (state.roomId != null && state.nickname != null && state.uid != null) {
      await _saveToStorage(
        roomId: state.roomId!,
        nickname: state.nickname!,
        uid: state.uid!,
        isHost: state.isHost,
        gamePhase: gamePhase,
      );
    }

    Logger.log('🎮 GamePhase更新: $gamePhase');
  }

  // 既存メソッドを修正（gamePhaseも保存するように）
  void createRoom({
    required String nickname,
    required String roomId,
    required String uid,
  }) async {
    _cleanupBeforeJoin(roomId);

    state = UserState(
      nickname: nickname,
      roomId: roomId,
      uid: uid,
      isHost: true,
      isConnected: true,
      joinTime: DateTime.now(),
      gamePhase: GamePhase.initial, // 部屋作成時は初期状態
    );

    await _saveToStorage(
      roomId: roomId,
      nickname: nickname,
      uid: uid,
      isHost: true,
      gamePhase: GamePhase.initial, // 追加
    );

    Logger.log('🏠 部屋作成: $state');
  }

  void joinRoom({
    required String nickname,
    required String roomId,
    required String uid,
  }) async {
    _cleanupBeforeJoin(roomId);

    state = UserState(
      nickname: nickname,
      roomId: roomId,
      uid: uid,
      isHost: false,
      isConnected: true,
      joinTime: DateTime.now(),
      gamePhase: GamePhase.initial, // 部屋参加時は初期状態
    );

    await _saveToStorage(
      roomId: roomId,
      nickname: nickname,
      uid: uid,
      isHost: false,
      gamePhase: GamePhase.initial, // 追加
    );

    Logger.log('👥 部屋参加: $state');
  }

  Future<bool> tryRestoreFromStorage() async {
    try {
      final data = await _loadFromStorage();
      if (data == null) {
        Logger.log('🔍 復帰データなし');
        return false;
      }

      Logger.log(
          '🔍 復帰データ発見: ${data['roomId']} (gamePhase: ${data['gamePhase']})');

      final currentUid = await AuthService.ensureAuthenticated();
      if (currentUid != data['uid']) {
        Logger.log('⚠️ UIDが変更されているため復帰をスキップ');
        await _clearStorage();
        return false;
      }

      final roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(data['roomId'])
          .get();

      if (!roomSnapshot.exists) {
        Logger.log('⚠️ 部屋が存在しないため復帰失敗');
        await _clearStorage();
        return false;
      }

      final roomData = roomSnapshot.data() as Map<String, dynamic>?;
      final players = roomData?['players'] as Map<String, dynamic>? ?? {};

      if (!players.containsKey(currentUid)) {
        Logger.log('⚠️ プレイヤーが部屋から削除されているため復帰失敗');
        await _clearStorage();
        return false;
      }

      _cleanupBeforeJoin(data['roomId']);

      state = UserState(
        nickname: data['nickname'],
        roomId: data['roomId'],
        uid: data['uid'],
        isHost: data['isHost'],
        isConnected: true,
        joinTime: DateTime.now(),
        isRestoring: true,
        gamePhase: data['gamePhase'] ?? GamePhase.initial, // 追加
      );

      Logger.log(
          '✅ 復帰成功: ${data['roomId']} (復帰モード, gamePhase: ${state.gamePhase})');

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          state = state.copyWith(isRestoring: false);
          Logger.log('🔄 復帰モード終了');
        }
      });

      return true;
    } catch (e) {
      Logger.log('❌ 復帰処理エラー: $e');
      await _clearStorage();
      return false;
    }
  }

  // leaveRoom時にgamePhaseもクリア
  Future<void> leaveRoom() async {
    Logger.log('🚪 部屋退出前の状態: $state');
    final currentRoomId = state.roomId;

    await _clearStorage();

    if (currentRoomId != null) {
      try {
        final gameStateNotifier =
            _ref.read(roomGameStateProvider(currentRoomId).notifier);
        gameStateNotifier.stopMonitoring();
        Logger.log('🔄 ゲーム状態監視を停止: $currentRoomId');

        Future.delayed(Duration(milliseconds: 100), () {
          try {
            _ref.invalidate(roomStreamProvider(currentRoomId));
            _ref.invalidate(playersProvider(currentRoomId));
            _ref.invalidate(roomGameStateProvider(currentRoomId));
            Logger.log('🔄 関連プロバイダーをクリア: $currentRoomId');
          } catch (e) {
            Logger.log('⚠️ 遅延プロバイダークリーンアップエラー: $e');
          }
        });
      } catch (e) {
        Logger.log('⚠️ プロバイダークリーンアップエラー: $e');
      }
    }

    state = const UserState();
    Logger.log('🚪 部屋退出後の状態: $state');
  }

  void _cleanupBeforeJoin(String roomId) {
    try {
      _ref.invalidate(roomStreamProvider(roomId));
      _ref.invalidate(playersProvider(roomId));
      _ref.invalidate(roomGameStateProvider(roomId));
      Logger.log('🔄 参加前プロバイダークリーンアップ: $roomId');
    } catch (e) {
      Logger.log('⚠️ 参加前クリーンアップエラー: $e');
    }
  }

  void updateHostStatus(bool isHost) {
    if (state.isHost != isHost) {
      Logger.log('👑 ホスト権限変更: ${state.isHost} → $isHost (${state.nickname})');
      state = state.copyWith(isHost: isHost);
    }
  }

  void updateConnection(bool isConnected) {
    state = state.copyWith(isConnected: isConnected);
    Logger.log('🔗 接続状態更新: $isConnected');
  }

  void disconnect() {
    state = state.copyWith(isConnected: false);
    Logger.log('❌ 切断: $state');
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});

final isHostProvider = Provider<bool>((ref) {
  final userState = ref.watch(userProvider);

  if (userState.nickname == null ||
      userState.roomId == null ||
      userState.uid == null) {
    return false;
  }

  final roomSnapshot = ref.watch(roomStreamProvider(userState.roomId!));

  return roomSnapshot.when(
    data: (snapshot) {
      if (!snapshot.exists) return false;

      final data = snapshot.data() as Map<String, dynamic>?;
      final hostPlayer = data?['hostPlayer'] as String?;

      if (hostPlayer == null) {
        return userState.isHost;
      }

      return userState.uid == hostPlayer;
    },
    loading: () => userState.isHost,
    error: (_, __) => userState.isHost,
  );
});

final currentNicknameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider.select((user) => user.nickname));
});

final currentRoomIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider.select((user) => user.roomId));
});

final isInRoomProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider);
  return !user.isEmpty && user.isConnected;
});
