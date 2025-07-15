import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_state.dart';

final roomStreamProvider =
    StreamProvider.family.autoDispose<DocumentSnapshot, String>((ref, roomId) {
  return FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots();
});

// プレイヤーリストを派生状態として管理
final playersProvider = Provider.family<List<Player>, String>((ref, roomId) {
  final roomAsyncValue = ref.watch(roomStreamProvider(roomId));

  return roomAsyncValue.when(
    data: (snapshot) {
      if (snapshot != null && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // 前提：roomドキュメントにホストのUIDを示す 'hostUid' フィールドが存在する
        final hostPlayer = data['hostPlayer'] as String?;
        // playersフィールドをMapとして取得
        final playersMap = data['players'] as Map<String, dynamic>?;

        // 必要なデータが揃っていない場合は空のリストを返す
        if (playersMap == null || hostPlayer == null) {
          return [];
        }

        // Mapのエントリーを List<Player> に変換
        final playersList = playersMap.entries.map((entry) {
          final uid = entry.key;
          final playerData = entry.value as Map<String, dynamic>;
          final nickname = playerData['nickname'] as String? ??
              '名無し'; // nicknameがない場合のフォールバック

          return Player(
            nickname: nickname,
            // プレイヤーのUIDがドキュメントのhostUidと一致するかでホストを判定
            isHost: uid == hostPlayer,
          );
        }).toList();

        // ホストをリストの先頭に並び替える（任意）
        playersList.sort((a, b) => a.isHost ? -1 : 1);

        return playersList;
      }
      // データがない場合は空のリストを返す
      return [];
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
