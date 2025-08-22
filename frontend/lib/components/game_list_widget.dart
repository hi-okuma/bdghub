import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'app_theme.dart';
import '../utils/genre_utils.dart';

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
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // タイトル
                                  Text(
                                    game['title'],
                                    style: AppTextStyles.title,
                                  ),
                                  const SizedBox(height: AppSpacing.xSmall),

                                  // ジャンルチップ - GenreUtilsを使用
                                  GenreUtils.buildGenreChips(game),
                                  const SizedBox(height: AppSpacing.xSmall),
                                ]),
                          ),
                          // 矢印アイコン
                          Icon(
                            Icons.chevron_right,
                            size: AppIconSizes.small,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ]),

                    // 所要時間・プレイヤー数
                    Text(
                      '所要時間: ${game['time']} \n参加人数: ${game['players']}',
                      style: AppTextStyles.gameCard,
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),

                    // 概要
                    Text(
                      game['overview'],
                      style: AppTextStyles.gameCard,
                      maxLines: AppLayout.maxGameDescriptionLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
