import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/custom_widgets.dart';
import '../../components/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/genre_utils.dart';
import 'game_title_page.dart';
import '/models/user_state.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';
import '/providers/game_provider.dart'; // 追加

class GameDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> game;
  final bool isFromRoom;
  final String? roomId;
  final String gameId;

  const GameDetailPage({
    Key? key,
    required this.game,
    this.isFromRoom = false,
    this.roomId,
    required this.gameId,
  }) : super(key: key);

  @override
  ConsumerState<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends ConsumerState<GameDetailPage> {
  bool _isLoading = false;

  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ★ シンプル：API呼び出しのみ ★
      final responseData = await ApiService.startGame(
        context,
        widget.roomId!,
        widget.gameId,
      );

      if (!mounted) return;

      // ★ 成功メッセージのみ表示（遷移はgame_state_providerが自動実行） ★
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ゲームを開始しています...')),
      );
    } catch (e) {
      // エラーはErrorHandlerで処理されるが、ローディング解除のためにcatchは残す
      Logger.log('ゲーム開始APIエラー: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = ref.watch(isHostProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 105,
        leading: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.small, vertical: 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_back,
                color: AppTheme.primaryColor,
                size: AppIconSizes.small,
              ),
              SizedBox(
                width: AppSpacing.small,
              ),
              Text('戻る'),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ゲームカード
            _buildGameCard(),

            // 「このゲームで遊ぶ」ボタン（部屋から来た場合かつホストユーザーのみ表示）
            if (widget.isFromRoom && isHost) ...[
              const SizedBox(height: AppSpacing.xxLarge),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  text: 'このゲームで遊ぶ',
                  isLoading: _isLoading,
                  onPressed: _startGame,
                ),
              ),
            ],

            // ゲーム詳細説明
            const SizedBox(height: AppSpacing.xxLarge),
            Text(
              'ルール',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              widget.game['description'] ?? '説明がありません',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // サムネイル
            GameThumbnail(
              thumbnailUrl: widget.game['thumbnailUrl'],
              size: AppIconSizes.gameDetailThumbnail,
              iconSize: AppLayout.iconSize,
            ),
            const SizedBox(width: AppSpacing.medium),

            // ゲーム情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.game['title'],
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  // ジャンルチップ - GenreUtilsを使用
                  GenreUtils.buildGenreChips(widget.game),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    '所要時間: ${widget.game['time']} \n参加人数: ${widget.game['players']}',
                    textAlign: TextAlign.left,
                    style: AppTextStyles.gameCard,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    widget.game['overview'] ?? '',
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
    );
  }
}
