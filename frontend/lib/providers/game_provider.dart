import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 現在のゲーム情報を保持するプロバイダー
class CurrentGameState {
  final String? gameId;
  final String? title;
  final String? description;
  final String? overview;
  final String? thumbnailUrl;
  final List<String>? gameImages;
  final String? creatorName;
  final int? duration;
  final int? minPlayers;
  final int? maxPlayers;
  final Map<String, dynamic>? gameData;

  const CurrentGameState({
    this.gameId,
    this.title,
    this.description,
    this.overview,
    this.thumbnailUrl,
    this.gameImages,
    this.creatorName,
    this.duration,
    this.minPlayers,
    this.maxPlayers,
    this.gameData,
  });

  CurrentGameState copyWith({
    String? gameId,
    String? title,
    String? description,
    String? overview,
    String? thumbnailUrl,
    List<String>? gameImages,
    String? creatorName,
    int? duration,
    int? minPlayers,
    int? maxPlayers,
    Map<String, dynamic>? gameData,
  }) {
    return CurrentGameState(
      gameId: gameId ?? this.gameId,
      title: title ?? this.title,
      description: description ?? this.description,
      overview: overview ?? this.overview,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      gameImages: gameImages ?? this.gameImages,
      creatorName: creatorName ?? this.creatorName,
      duration: duration ?? this.duration,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      gameData: gameData ?? this.gameData,
    );
  }
}

class CurrentGameNotifier extends StateNotifier<CurrentGameState> {
  CurrentGameNotifier() : super(const CurrentGameState());

  // DB設計に基づいてFirestoreから直接ゲーム情報を取得
  Future<void> loadGameFromFirestore(String gameId) async {
    try {
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .get();

      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;

        // ★ パラメータで渡されたgameIdを使ってassetsサブコレクションから追加データを取得 ★
        Map<String, dynamic>? assetsData;
        try {
          // 全てのゲームでassetsサブコレクションの取得を試行
          final assetsQuery = await FirebaseFirestore.instance
              .collection('games')
              .doc(gameId)
              .collection('assets')
              .get();

          if (assetsQuery.docs.isNotEmpty) {
            assetsData = {};
            for (var doc in assetsQuery.docs) {
              assetsData[doc.id] = doc.data();
            }
          }
        } catch (e) {
          print('assetsサブコレクションの取得エラー: $e');
          // assetsが存在しない場合は無視して続行
        }

        state = CurrentGameState(
          gameId: gameId,
          title: gameData['title'],
          description: gameData['description'],
          overview: gameData['overview'],
          thumbnailUrl: gameData['thumbnailUrl'],
          creatorName: gameData['creatorName'],
          duration: gameData['duration'],
          minPlayers: gameData['minPlayers'],
          maxPlayers: gameData['maxPlayers'],
          gameImages: _extractGameImages(gameData),
          gameData: {
            ...gameData,
            if (assetsData != null) 'assets': assetsData,
          },
        );
      }
    } catch (e) {
      print('ゲーム情報の取得エラー: $e');
      // エラー時はデフォルト値を設定
      _setDefaultGameData(gameId);
    }
  }

  // 既存のgame_service.dartで取得したデータから設定（互換性維持）
  void setGameFromExistingData(Map<String, dynamic> gameData) {
    state = CurrentGameState(
      gameId: gameData['gameId'],
      title: gameData['title'],
      description: gameData['description'],
      overview: gameData['overview'],
      thumbnailUrl: gameData['thumbnailUrl'],
      creatorName: gameData['creatorName'],
      duration: _parseDuration(gameData['time']),
      minPlayers: _parseMinPlayers(gameData['players']),
      maxPlayers: _parseMaxPlayers(gameData['players']),
      gameImages: _extractGameImages(gameData),
      gameData: gameData,
    );
  }

  void clearGame() {
    state = const CurrentGameState();
  }

  // デフォルトのゲーム情報を設定（Firestore取得失敗時）
  void _setDefaultGameData(String gameId) {
    Map<String, dynamic> defaultData = {};

    switch (gameId) {
      case '0001':
        defaultData = {
          'title': 'NGワードゲーム',
          'overview': '友達と一緒に遊ぶNGワードゲーム！あなたにだけ伝えられるNGワードを言わないようにしましょう。',
          'description':
              'プレイヤーそれぞれに秘密のNGワードが配られます。会話を楽しみながら、自分のNGワードを言わないように注意しましょう！',
          'creatorName': 'ボドゲハブ',
        };
        break;
      default:
        defaultData = {
          'title': 'ゲーム',
          'overview': 'みんなで楽しく遊べるゲームです',
          'description': 'ゲームの詳細情報を取得できませんでした',
          'creatorName': '不明',
        };
    }

    state = CurrentGameState(
      gameId: gameId,
      title: defaultData['title'],
      description: defaultData['description'],
      overview: defaultData['overview'],
      creatorName: defaultData['creatorName'],
      gameImages: _getDefaultImages(gameId),
      gameData: defaultData,
    );
  }

  List<String> _extractGameImages(Map<String, dynamic> gameData) {
    // DB設計では画像URLの配列は定義されていないが、将来的な拡張に備える
    if (gameData['gameImages'] != null && gameData['gameImages'] is List) {
      return List<String>.from(gameData['gameImages']);
    }

    // サムネイルを使用
    if (gameData['thumbnailUrl'] != null &&
        gameData['thumbnailUrl'].isNotEmpty) {
      return [gameData['thumbnailUrl']];
    }

    // ゲームIDに基づくデフォルト画像
    return _getDefaultImages(gameData['gameId'] ?? '');
  }

  List<String> _getDefaultImages(String gameId) {
    switch (gameId) {
      case '0001':
        return [
          'https://picsum.photos/400/400', // NGワード専用画像
          'https://picsum.photos/400/400',
          'https://picsum.photos/400/400',
        ];
      default:
        return [
          'https://picsum.photos/id/0/400/400',
          'https://picsum.photos/id/3/400/400',
          'https://picsum.photos/id/6/400/400',
        ];
    }
  }

  // game_service.dartの形式から時間を抽出
  int? _parseDuration(String? timeString) {
    if (timeString == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(timeString);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // game_service.dartの形式から最小人数を抽出
  int? _parseMinPlayers(String? playersString) {
    if (playersString == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(playersString);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // game_service.dartの形式から最大人数を抽出
  int? _parseMaxPlayers(String? playersString) {
    if (playersString == null) return null;
    final matches = RegExp(r'(\d+)').allMatches(playersString);
    if (matches.length >= 2) {
      return int.tryParse(matches.elementAt(1).group(1)!);
    }
    return null;
  }
}

final currentGameProvider =
    StateNotifierProvider<CurrentGameNotifier, CurrentGameState>(
  (ref) => CurrentGameNotifier(),
);
