// models/user_state.dart
import 'package:flutter/foundation.dart';
import 'game_enums.dart'; // 追加

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

// ★修正：UserStateクラス
@immutable
class UserState {
  final String? nickname;
  final String? roomId;
  final String? uid;
  final bool isHost;
  final bool isConnected;
  final DateTime? joinTime;
  final bool isRestoring;
  final GamePhase? gamePhase;
  final Map<String, dynamic>? localGameData; // ★追加: ゲーム固有の一時データ

  const UserState({
    this.nickname,
    this.roomId,
    this.uid,
    this.isHost = false,
    this.isConnected = false,
    this.joinTime,
    this.isRestoring = false,
    this.gamePhase,
    this.localGameData, // ★追加
  });

  UserState copyWith({
    String? nickname,
    String? roomId,
    String? uid,
    bool? isHost,
    bool? isConnected,
    DateTime? joinTime,
    bool? isRestoring,
    GamePhase? gamePhase,
    Map<String, dynamic>? localGameData, // ★追加
  }) {
    return UserState(
      nickname: nickname ?? this.nickname,
      roomId: roomId ?? this.roomId,
      uid: uid ?? this.uid,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      joinTime: joinTime ?? this.joinTime,
      isRestoring: isRestoring ?? this.isRestoring,
      gamePhase: gamePhase ?? this.gamePhase,
      localGameData: localGameData ?? this.localGameData, // ★追加
    );
  }

  // デバッグ用
  @override
  String toString() {
    return 'UserState(nickname: $nickname, roomId: $roomId, uid: $uid, isHost: $isHost, isConnected: $isConnected, isRestoring: $isRestoring, gamePhase: $gamePhase, localGameData: $localGameData)'; // ★修正
  }

  // 空の状態かチェック
  bool get isEmpty => nickname == null || roomId == null;
}
