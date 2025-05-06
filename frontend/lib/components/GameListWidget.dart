import 'package:flutter/material.dart';

class GameListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> games;
  final Function(Map<String, dynamic>) onGameSelected;

  const GameListWidget({
    Key? key,
    required this.games,
    required this.onGameSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Center(
        child: Text('該当するゲームがありません'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: InkWell(
            onTap: () => onGameSelected(game),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // サムネイル表示部分を修正
                  Container(
                    width: 70,
                    height: 70,
                    // 角丸を適用するためにコンテナの範囲内でクリップする
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      // 画像が表示されない場合やロード中の背景色
                      color: Colors.grey[300],
                    ),
                    // サムネイル表示のロジック
                    child: (game['thumbnailUrl'] != null &&
                            game['thumbnailUrl'].isNotEmpty)
                        ? Image.network(
                            game['thumbnailUrl'],
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover, // コンテナに合わせて画像をトリミングして表示
                            // 画像のロード中に表示されるビルダー
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                // ロード完了したら画像をそのまま表示
                                return child;
                              }
                              // ロード中はローディングインジケータを表示
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            // 画像ロード中にエラーが発生した場合に表示されるビルダー
                            errorBuilder: (context, error, stackTrace) {
                              // エラー時は代替アイコン（例: 壊れた画像アイコン）を表示
                              return const Icon(Icons.broken_image,
                                  size: 40, color: Colors.grey);
                            },
                          )
                        : // URLが無い場合はデフォルトアイコンを表示
                        const Icon(Icons.casino, size: 40, color: Colors.grey),
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
                        // ジャンル名をChipとして複数表示
                        Wrap(
                          spacing: 4, // チップ間の水平スペース
                          runSpacing: 4, // 行間のスペース
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
                          game['overview'],
                          style: const TextStyle(fontSize: 14),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 矢印アイコン
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ジャンル名からチップを生成するメソッド
  List<Widget> _buildGenreChips(Map<String, dynamic> game) {
    // genreNameがリストの場合
    if (game['genreName'] is List) {
      List<String> genreNames = List<String>.from(game['genreName']);

      // リストが空の場合は「すべて」を表示
      if (genreNames.isEmpty) {
        return [_buildSingleChip('すべて')];
      }

      // 各ジャンル名に対応するチップを生成
      return genreNames.map((name) => _buildSingleChip(name)).toList();
    }

    // 互換性のため、文字列の場合も処理
    String genreName = (game['genreName'] ?? 'すべて').toString();
    return [_buildSingleChip(genreName)];
  }

  // 単一のチップを生成するヘルパーメソッド
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
