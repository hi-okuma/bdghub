import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/app_theme.dart';
import '/components/custom_widgets.dart';
import '/models/user_state.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';

class NGWordGameTitlePage extends ConsumerStatefulWidget {
  const NGWordGameTitlePage({Key? key}) : super(key: key);

  @override
  ConsumerState<NGWordGameTitlePage> createState() =>
      _NGWordGameTitlePageState();
}

class _NGWordGameTitlePageState extends ConsumerState<NGWordGameTitlePage> {
  int _currentImageIndex = 0;
  bool _isPreparationCompleted = false;
  final PageController _pageController = PageController();

  final List<String> _gameImages = [
    'https://picsum.photos/id/0/250/250',
    'https://picsum.photos/id/3/250/250',
    'https://picsum.photos/id/6/250/250',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ★ Riverpodからユーザー情報を取得 ★
    final userState = ref.watch(userProvider);

    final isHost = userState.isHost;
    final nickname = userState.nickname ?? '';
    final roomId = userState.roomId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('NGワードゲーム - 部屋: $roomId'),
        actions: [
          // デバッグ用：現在のユーザー情報表示
          Chip(
            label: Text('$nickname${isHost ? '(ホスト)' : ''}'),
            backgroundColor: isHost ? AppTheme.hostBadgeColor : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // タイトルと説明部分
            Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                children: [
                  Text(
                    'NGワードゲーム',
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    '友達と一緒に遊ぶNGワードゲーム！あなたにだけ伝えられるNGワードを言わないようにしましょう。',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ゲーム紹介画像（カルーセル）
            Expanded(
              child: Container(
                color: AppTheme.tabBackgroundColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // カルーセル
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemCount: _gameImages.length,
                      itemBuilder: (context, index) {
                        final imageUrl = _gameImages[index];

                        return Center(
                          child: GameThumbnail(
                            thumbnailUrl: imageUrl,
                            size: 400,
                          ),
                        );
                      },
                    ),
                    // インジケーター
                    Positioned(
                      bottom: AppSpacing.large,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _gameImages.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xSmall),
                            width: AppSpacing.small,
                            height: AppSpacing.small,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? AppTheme.errorColor
                                  : AppTheme.hintTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ボタン部分
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large,
                vertical: AppSpacing.medium,
              ),
              child: Column(
                children: [
                  // 準備完了ボタン
                  SizedBox(
                    width: double.infinity,
                    child: LoadingButton(
                      text: _isPreparationCompleted ? '他プレイヤー待ち' : '準備完了',
                      isLoading: false,
                      onPressed: _isPreparationCompleted
                          ? null
                          : () {
                              setState(() {
                                _isPreparationCompleted = true;
                              });
                              // ここでゲーム画面への遷移ロジックを追加
                            },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),

                  // ★ ゲーム終了ボタン（ホストのみ表示） ★
                  // Riverpodから取得したホスト情報で判定
                  if (isHost)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showExitGameDialog(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.borderColor),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.medium),
                        ),
                        child: Text(
                          'ゲーム終了',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitGameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ゲームを終了しますか？'),
          content: const Text('ホストがゲームを終了すると、全参加者がタイトル画面に戻ります。'),
          actions: [
            LoadingButton(
              text: 'キャンセル',
              isLoading: false,
              isElevated: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
            LoadingButton(
              text: 'ゲーム終了',
              isLoading: false,
              onPressed: () {
                Navigator.of(context).pop();
                _exitGame();
              },
            ),
          ],
        );
      },
    );
  }

  void _exitGame() {
    // ★ ゲーム終了時にRiverpodの状態もクリア ★
    ref.read(userProvider.notifier).leaveRoom();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ゲームを終了しました')),
    );
  }
}
