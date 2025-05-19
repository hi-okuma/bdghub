import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'app_theme.dart';

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
        child: Text(
          '該当するゲームがありません',
          style: AppTextStyles.body,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.large),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.large),
      child: InkWell(
        onTap: () => onGameSelected(game),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サムネイル - カスタムウィジェットを使用
              GameThumbnail(
                thumbnailUrl: game['thumbnailUrl'],
                size: AppIconSizes.gameCardThumbnail,
              ),
              const SizedBox(width: AppSpacing.medium),

              // ゲーム情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Text(
                      game['title'],
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),

                    // ジャンルチップ - カスタムウィジェットを使用
                    _buildGenreChips(game),
                    const SizedBox(height: AppSpacing.xSmall),

                    // 所要時間・プレイヤー数
                    Text(
                      '所要時間: ${game['time']} / ${game['players']}',
                      style: AppTextStyles.gameCardTime,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),

                    // 概要
                    Text(
                      game['overview'],
                      style: AppTextStyles.body,
                      maxLines: AppLayout.maxGameDescriptionLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 矢印アイコン
              Icon(
                Icons.arrow_forward_ios,
                size: AppIconSizes.xSmall,
                color: AppTheme.secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreChips(Map<String, dynamic> game) {
    List<String> genreNames = [];

    // ジャンル名の処理
    if (game['genreName'] is List) {
      genreNames = List<String>.from(game['genreName']);
    } else {
      String genreName = (game['genreName'] ?? 'すべて').toString();
      genreNames = [genreName];
    }

    // 空の場合は「すべて」を表示
    if (genreNames.isEmpty) {
      genreNames = ['すべて'];
    }

    return Wrap(
      spacing: AppSpacing.xSmall,
      runSpacing: AppSpacing.xSmall,
      children: genreNames.map((name) => GenreChip(label: name)).toList(),
    );
  }
}
