import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_state.dart';
import '../providers/room_provider.dart';
import '../providers/game_state_provider.dart';

class UserNotifier extends StateNotifier<UserState> {
  final Ref _ref;

  UserNotifier(this._ref) : super(const UserState());

  void createRoom({
    required String nickname,
    required String roomId,
    required String uid,
  }) {
    // 既存の監視をクリーンアップ（再作成の場合）
    _cleanupBeforeJoin(roomId);

    state = UserState(
      nickname: nickname,
      roomId: roomId,
      uid: uid,
      isHost: true,
      isConnected: true,
      joinTime: DateTime.now(),
    );
    print('🏠 部屋作成: $state');
  }

  void joinRoom({
    required String nickname,
    required String roomId,
    required String uid,
  }) {
    // 既存の監視をクリーンアップ（再参加の場合）
    _cleanupBeforeJoin(roomId);

    state = UserState(
      nickname: nickname,
      roomId: roomId,
      uid: uid,
      isHost: false,
      isConnected: true,
      joinTime: DateTime.now(),
    );
    print('👥 部屋参加: $state');
  }

  // 参加前のクリーンアップ（再参加対応）
  void _cleanupBeforeJoin(String roomId) {
    try {
      // 同じroomIdの古いプロバイダーをクリーンアップ
      _ref.invalidate(roomStreamProvider(roomId));
      _ref.invalidate(playersProvider(roomId));
      _ref.invalidate(roomGameStateProvider(roomId));
      print('🔄 参加前プロバイダークリーンアップ: $roomId');
    } catch (e) {
      print('⚠️ 参加前クリーンアップエラー: $e');
    }
  }

  void updateHostStatus(bool isHost) {
    if (state.isHost != isHost) {
      print('👑 ホスト権限変更: ${state.isHost} → $isHost (${state.nickname})');
      state = state.copyWith(isHost: isHost);
    }
  }

  void updateConnection(bool isConnected) {
    state = state.copyWith(isConnected: isConnected);
    print('🔗 接続状態更新: $isConnected');
  }

  void leaveRoom() {
    print('🚪 部屋退出前の状態: $state');
    final currentRoomId = state.roomId;

    // 関連プロバイダーのクリーンアップ（状態クリア前に実行）
    if (currentRoomId != null) {
      try {
        // ★ 修正1: RoomGameStateNotifierの監視を完全停止 ★
        final gameStateNotifier =
            _ref.read(roomGameStateProvider(currentRoomId).notifier);
        gameStateNotifier.stopMonitoring();
        print('🔄 ゲーム状態監視を停止: $currentRoomId');

        // ★ 修正2: 少し待機してから invalidate を実行 ★
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            // Providerをinvalidateして新しいインスタンスを強制作成
            _ref.invalidate(roomStreamProvider(currentRoomId));
            _ref.invalidate(playersProvider(currentRoomId));
            _ref.invalidate(roomGameStateProvider(currentRoomId));
            print('🔄 関連プロバイダーをクリア: $currentRoomId');
          } catch (e) {
            print('⚠️ 遅延プロバイダークリーンアップエラー: $e');
          }
        });
      } catch (e) {
        print('⚠️ プロバイダークリーンアップエラー: $e');
      }
    }

    // ★ 修正3: 状態をクリア（invalidate後に実行） ★
    state = const UserState();
    print('🚪 部屋退出後の状態: $state');
  }

  void disconnect() {
    state = state.copyWith(isConnected: false);
    print('❌ 切断: $state');
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});

// ★ 修正：room_provider.dartと同じ方法でhostPlayerを判定 ★
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
      // ★ room_provider.dartと同じ方法でhostPlayerを判定 ★
      final hostPlayer = data?['hostPlayer'] as String?;

      if (hostPlayer == null) {
        return userState.isHost; // フォールバック
      }

      // 現在のユーザーのUIDがhostPlayerと一致するかチェック
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
