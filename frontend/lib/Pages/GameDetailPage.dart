import 'package:flutter/material.dart';
import '../components/GameListWidget.dart';

class GameDetailPage extends StatelessWidget {
  final Map<String, dynamic> game;
  final bool isFromRoom; // 部屋から来たかどうかのフラグ

  const GameDetailPage({
    Key? key,
    required this.game,
    this.isFromRoom = false, // デフォルトはTOP画面からの遷移（ボタン非表示）
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(game['title']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ゲームカード（GameListWidgetからUIを流用）
            _buildGameCard(context),

            // 「このゲームで遊ぶ」ボタン（部屋から来た場合のみ表示）
            if (isFromRoom) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // ゲームを開始する処理
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${game["title"]}で遊びます'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'このゲームで遊ぶ',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],

            // ゲーム詳細説明
            const SizedBox(height: 24),
            const Text(
              'ゲーム詳細',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game['description'] ?? '説明がありません',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('作成者：${game['creatorName']}'),
                ElevatedButton(
                    onPressed: () {
                      // ECサイトへ移動する処理
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${game["title"]}の購入サイトへ移動します'),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 18.0,
                        ),
                        Text('購入サイトへ'),
                      ],
                    ))
              ],
            )
          ],
        ),
      ),
    );
  }

  // GameListWidgetのカードデザインを流用したゲームカードウィジェット
  Widget _buildGameCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル
            Container(
              width: 100,
              height: 100,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: (game['thumbnailUrl'] != null &&
                      game['thumbnailUrl'].isNotEmpty)
                  ? Image.network(
                      game['thumbnailUrl'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        );
                      },
                    )
                  : const Icon(
                      Icons.casino,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 12),

            // ゲーム情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ジャンル名をChipとして表示
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _buildGenreChips(game),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    '所要時間: ${game['time']} / ${game['players']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    game['overview'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // GameListWidgetからコピーしたジャンルチップ生成メソッド
  List<Widget> _buildGenreChips(Map<String, dynamic> game) {
    if (game['genreName'] is List) {
      List<String> genreNames = List<String>.from(game['genreName']);

      if (genreNames.isEmpty) {
        return [_buildSingleChip('すべて')];
      }

      return genreNames.map((name) => _buildSingleChip(name)).toList();
    }

    String genreName = (game['genreName'] ?? 'すべて').toString();
    return [_buildSingleChip(genreName)];
  }

  // GameListWidgetからコピーした単一チップ生成メソッド
  Widget _buildSingleChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[800],
        ),
      ),
    );
  }
}
