import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/custom_widgets.dart';
import '../../components/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';
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
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ★ シンプル：API呼び出しのみ ★
      final responseData = await ApiService.startGame(
        widget.roomId!,
        widget.gameId,
      );

      // APIエラーレスポンスのチェック
      if (responseData.containsKey('success') &&
          responseData['success'] == false) {
        ApiErrorHandler.handleApiError(context, responseData, (error) {
          setState(() {
            _errorMessage = error;
          });
        });
        return;
      }

      if (!mounted) return;
      
      // ★ 成功メッセージのみ表示（遷移はgame_state_providerが自動実行） ★
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ゲームを開始しています...')),
      );
    } catch (e) {
      ApiErrorHandler.handleException(context, e, (error) {
        setState(() {
          _errorMessage = error;
        });
      });
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
        title: Text(widget.game['title']),
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
              'ゲーム詳細',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              widget.game['description'] ?? '説明がありません',
              style: AppTextStyles.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.small),
            // 区切り線
            const Divider(height: AppSpacing.xxLarge),
            // 作成者情報と購入リンク
            _buildGameFooter(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル
            GameThumbnail(
              thumbnailUrl: widget.game['thumbnailUrl'],
              size: AppIconSizes.gameDetailThumbnail,
            ),
            const SizedBox(width: AppSpacing.medium),

            // ゲーム情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.game['title'],
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  // ジャンルチップ - GenreUtilsを使用
                  GenreUtils.buildGenreChips(widget.game),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    '所要時間: ${widget.game['time']} / ${widget.game['players']}',
                    style: AppTextStyles.gameCardTime,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    widget.game['overview'] ?? '',
                    style: AppTextStyles.body,
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

  Widget _buildGameFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('作成者：${widget.game['creatorName']}'),
        ElevatedButton(
            onPressed: () {
              // ECサイトへ移動する処理
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.game["title"]}の購入サイトへ移動します'),
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
    );
  }
}
