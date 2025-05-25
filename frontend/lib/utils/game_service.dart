import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ゲームのジャンル列挙型
enum GameGenre { all, popular, card, cooperation }

// Firestoreからゲームデータを取得する共通メソッド
Future<List<Map<String, dynamic>>> fetchGamesFromFirestore() async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _gameList = [];

  try {
    // gamesコレクションの全ドキュメントを取得
    final snapshot = await _firestore
        .collection('games')
        .where('isPublished', isEqualTo: true) // 公開されているゲームのみ取得
        .get();

    if (snapshot.docs.isNotEmpty) {
      final List<Map<String, dynamic>> parsedGames = [];

      // 各ドキュメントからデータを抽出
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final gameId = doc.id;

        // tagsからジャンル情報を取得（複数登録可能）
        List<GameGenre> genres = [GameGenre.all];
        List<String> genreNames = ['すべて'];

        if (data['tags'] != null && data['tags'] is List) {
          final tags = List<dynamic>.from(data['tags']);
          genres = []; // 初期値をリセット
          genreNames = []; // 初期値をリセット

          // tagsからジャンルを判定する（複数登録可能）
          if (tags.contains('定番')) {
            genres.add(GameGenre.popular);
            genreNames.add('定番');
          }
          if (tags.contains('カード')) {
            genres.add(GameGenre.card);
            genreNames.add('カード');
          }
          if (tags.contains('協力')) {
            genres.add(GameGenre.cooperation);
            genreNames.add('協力');
          }

          // ジャンルが一つも登録されていない場合はデフォルト値を設定
          if (genres.isEmpty) {
            genres.add(GameGenre.all);
            genreNames.add('すべて');
          }
        }

        // ゲーム情報をリストに追加
        parsedGames.add({
          'gameId': gameId, // ソート用にIDを追加
          'title': data['title'] ?? '',
          'thumbnailUrl': data['thumbnailUrl'] ?? '',
          'genre': genres, // 複数ジャンルをリストとして保存
          'genreName': genreNames, // ジャンル名をリストとして保存
          'category': genreNames.isNotEmpty
              ? genreNames[0]
              : 'すべて', // SelectGamePage用の互換性維持
          'players': '${data['minPlayers'] ?? ''}-${data['maxPlayers'] ?? ''}人',
          'time': '${data['duration'] ?? ''}分',
          'overview': data['overview'] ?? '',
          'description': data['description'] ?? '',
          'playCnt': data['playCnt'] ?? 0, // ソート用に追加
          'creatorName': data['creatorName'] ?? '',
        });
      }

      // playCnt → gameIdの順にdescendingでソート
      parsedGames.sort((a, b) {
        final int playCntA = a['playCnt'] ?? 0;
        final int playCntB = b['playCnt'] ?? 0;

        // まずはplayCntで比較
        final int playCntComparison = playCntB.compareTo(playCntA); // 降順

        // playCntが同じならgameId(ドキュメントID)で比較
        if (playCntComparison == 0) {
          return (b['id'] ?? '').compareTo(a['id'] ?? ''); // 降順
        }

        return playCntComparison;
      });

      _gameList = parsedGames;
    } else {
      // ドキュメントが存在しない場合はダミーデータを使用
      _gameList = getDummyGames();
      print('Firestoreにデータが存在しないため、ダミーデータを使用します');
    }
  } catch (e) {
    print('Firestoreからのデータ取得エラー: $e');
    // エラー時はダミーデータを使用
    _gameList = getDummyGames();
  }

  return _gameList;
}

// ダミーデータを返す（Firestore取得失敗時のフォールバック用）
List<Map<String, dynamic>> getDummyGames() {
  return [
    {
      'title': 'タクティカルバトル',
      'genre': [GameGenre.popular],
      'genreName': ['定番'],
      'category': '定番',
      'players': '2-4人',
      'time': '30-60分',
      'description': '資源を集めて拠点を建築し、対戦相手を打ち負かす戦略ゲーム',
      'overview': '資源を集めて拠点を建築し、対戦相手を打ち負かす戦略ゲーム',
    },
    {
      'title': 'カードマスター',
      'genre': [GameGenre.card],
      'genreName': ['カード'],
      'category': 'カード',
      'players': '2-6人',
      'time': '20-40分',
      'description': '手札を駆使して相手よりも多くのポイントを獲得するカードゲーム',
      'overview': '手札を駆使して相手よりも多くのポイントを獲得するカードゲーム',
    },
    {
      'title': 'コープアドベンチャー',
      'genre': [GameGenre.cooperation],
      'genreName': ['協力'],
      'category': '協力',
      'players': '3-5人',
      'time': '45-90分',
      'description': 'プレイヤー全員で協力して、迫り来る危機から脱出を目指す',
      'overview': 'プレイヤー全員で協力して、迫り来る危機から脱出を目指す',
    },
    {
      'title': 'タクティカルカード',
      'genre': [GameGenre.popular, GameGenre.card],
      'genreName': ['定番', 'カード'],
      'category': '定番',
      'players': '2人',
      'time': '15-30分',
      'description': '2人で対戦する戦略的なカードゲーム。シンプルなルールで奥深い戦略性',
      'overview': '2人で対戦する戦略的なカードゲーム',
    },
    {
      'title': '協力型カードゲーム',
      'genre': [GameGenre.cooperation, GameGenre.card],
      'genreName': ['協力', 'カード'],
      'category': '協力',
      'players': '2-4人',
      'time': '30-45分',
      'description': 'チームで協力してミッションをクリアするカードゲーム',
      'overview': 'チームで協力してミッションをクリアするカードゲーム',
    },
  ];
}

// 特定のジャンルでゲームをフィルタリングする
List<Map<String, dynamic>> filterGamesByGenre(
    List<Map<String, dynamic>> games, Set<GameGenre> selectedGenre) {
  if (selectedGenre.contains(GameGenre.all)) {
    return games;
  } else {
    return games.where((game) {
      // 'genre'が配列として格納されているため、いずれかの要素が選択ジャンルに含まれているか確認
      if (game['genre'] is List) {
        List<GameGenre> genres = List<GameGenre>.from(game['genre']);
        // どれか1つでも選択ジャンルに含まれていればtrue
        return genres.any((genre) => selectedGenre.contains(genre));
      }
      // 互換性のため、従来の単一値のgenreにも対応
      return selectedGenre.contains(game['genre']);
    }).toList();
  }
}
