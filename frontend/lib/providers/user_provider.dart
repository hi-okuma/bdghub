import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_state.dart';
import '../providers/room_provider.dart';

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(const UserState());

  void createRoom({
    required String nickname,
    required String roomId,
  }) {
    state = UserState(
      nickname: nickname,
      roomId: roomId,
      isHost: true,
      isConnected: true,
      joinTime: DateTime.now(),
    );
    print('🏠 部屋作成: $state');
  }

  void joinRoom({
    required String nickname,
    required String roomId,
  }) {
    state = UserState(
      nickname: nickname,
      roomId: roomId,
      isHost: false,
      isConnected: true,
      joinTime: DateTime.now(),
    );
    print('👥 部屋参加: $state');
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
    state = const UserState();
    print('🚪 部屋退出後の状態: $state');
  }

  void disconnect() {
    state = state.copyWith(isConnected: false);
    print('❌ 切断: $state');
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});

final isHostProvider = Provider<bool>((ref) {
  final userState = ref.watch(userProvider);

  if (userState.nickname == null || userState.roomId == null) {
    return false;
  }

  final roomSnapshot = ref.watch(roomStreamProvider(userState.roomId!));

  return roomSnapshot.when(
    data: (snapshot) {
      if (!snapshot.exists) return false;
      
      final data = snapshot.data() as Map<String, dynamic>?;
      final playersData = data?['players'] as List<dynamic>? ?? [];
      
      return playersData.isNotEmpty && 
             playersData[0].toString() == userState.nickname;
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
