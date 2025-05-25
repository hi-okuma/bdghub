import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_state.dart';

final roomStreamProvider =
    StreamProvider.family.autoDispose<DocumentSnapshot, String>((ref, roomId) {
  return FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots();
});

// プレイヤーリストを派生状態として管理
final playersProvider = Provider.family<List<Player>, String>((ref, roomId) {
  final roomSnapshot = ref.watch(roomStreamProvider(roomId));

  return roomSnapshot.when(
    data: (snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final playersData = data['players'] as List<dynamic>? ?? [];

        return playersData.asMap().entries.map((entry) {
          return Player(
            nickname: entry.value.toString(),
            isHost: entry.key == 0,
          );
        }).toList();
      }
      return [];
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
