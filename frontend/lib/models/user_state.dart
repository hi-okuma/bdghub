import 'package:flutter/foundation.dart';

// Player: 「部屋内の全プレイヤー」のデータ表現用
@immutable
class Player {
  final String nickname;
  final bool isHost;
  final DateTime? joinTime;

  const Player({
    required this.nickname,
    this.isHost = false,
    this.joinTime,
  });

  Player copyWith({
    String? nickname,
    bool? isHost,
    DateTime? joinTime,
  }) {
    return Player(
      nickname: nickname ?? this.nickname,
      isHost: isHost ?? this.isHost,
      joinTime: joinTime ?? this.joinTime,
    );
  }

  @override
  String toString() {
    return 'Player(nickname: $nickname, isHost: $isHost)';
  }
}

// UserState: 「自分」の状態管理用
@immutable
class UserState {
  final String? nickname;
  final String? roomId;
  final String? uid;
  final bool isHost;
  final bool isConnected;
  final DateTime? joinTime;

  const UserState({
    this.nickname,
    this.roomId,
    this.uid,
    this.isHost = false,
    this.isConnected = false,
    this.joinTime,
  });

  UserState copyWith({
    String? nickname,
    String? roomId,
    String? uid,
    bool? isHost,
    bool? isConnected,
    DateTime? joinTime,
  }) {
    return UserState(
      nickname: nickname ?? this.nickname,
      roomId: roomId ?? this.roomId,
      uid: uid ?? this.uid,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      joinTime: joinTime ?? this.joinTime,
    );
  }

  // デバッグ用
  @override
  String toString() {
    return 'UserState(nickname: $nickname, roomId: $roomId, uid: $uid, isHost: $isHost, isConnected: $isConnected)';
  }

  // 空の状態かチェック
  bool get isEmpty => nickname == null || roomId == null;
}
