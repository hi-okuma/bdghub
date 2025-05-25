import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';

// デバッグ用：現在のユーザー状態を表示するウィジェット
class DebugUserInfo extends ConsumerWidget {
  const DebugUserInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🐛 Debug Info',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Nickname: ${userState.nickname ?? "null"}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'RoomID: ${userState.roomId ?? "null"}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'IsHost: ${userState.isHost}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Connected: ${userState.isConnected}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'JoinTime: ${userState.joinTime?.toIso8601String() ?? "null"}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
