import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/app_theme.dart';
import '/components/custom_widgets.dart';
import '/models/user_state.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';
import '/providers/game_provider.dart'; // 追加

class GameTitlePage extends ConsumerStatefulWidget {
  const GameTitlePage({Key? key}) : super(key: key);

  @override
  ConsumerState<GameTitlePage> createState() => _GameTitlePageState();
}

class _GameTitlePageState extends ConsumerState<GameTitlePage> {
  int _currentImageIndex = 0;
  bool _isPreparationCompleted = false;
  bool _isLoading = true;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  // ゲームデータを確実に読み込む
  Future<void> _loadGameData() async {
    final currentGame = ref.read(currentGameProvider);

    // 既にデータがある場合はそのまま使用
    if (currentGame.gameId != null && currentGame.title != null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // データがない場合はFirestoreから取得を試行
    try {
      // 現在保存されているgameIdを使用、なければデフォルト
      final gameId = currentGame.gameId ?? '0001';
      await ref
          .read(currentGameProvider.notifier)
          .loadGameFromFirestore(gameId);
    } catch (e) {
      print('ゲームデータ読み込みエラー: $e');
      // エラーでもデフォルトデータは設定済み
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ★ Riverpodからユーザー情報とゲーム情報を取得 ★
    final userState = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);

    final isHost = userState.isHost;
    final nickname = userState.nickname ?? '';
    final roomId = userState.roomId ?? '';

    // ★ DB設計に基づくゲーム情報を動的に取得 ★
    final gameTitle = currentGame.title ?? 'NGワードゲーム';
    final gameDescription = currentGame.overview ??
        '友達と一緒に遊ぶNGワードゲーム！あなたにだけ伝えられるNGワードを言わないようにしましょう。';
    final gameImages = currentGame.gameImages ??
        [
          'https://picsum.photos/id/100/400/400',
          'https://picsum.photos/id/101/400/400',
          'https://picsum.photos/id/102/400/400',
        ];

    // プレイヤー情報の表示用
    final playerInfo =
        currentGame.minPlayers != null && currentGame.maxPlayers != null
            ? '${currentGame.minPlayers}-${currentGame.maxPlayers}人'
            : '';
    final durationInfo =
        currentGame.duration != null ? '約${currentGame.duration}分' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('$gameTitle - 部屋: $roomId'),
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
                    gameTitle,
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  // ゲーム情報表示（人数・時間）
                  if (playerInfo.isNotEmpty || durationInfo.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (durationInfo.isNotEmpty) ...[
                          Icon(Icons.schedule,
                              size: 16, color: AppTheme.hintTextColor),
                          const SizedBox(width: 4),
                          Text(durationInfo, style: AppTextStyles.caption),
                        ],
                        if (playerInfo.isNotEmpty && durationInfo.isNotEmpty)
                          const Text(' / ', style: AppTextStyles.caption),
                        if (playerInfo.isNotEmpty) ...[
                          Icon(Icons.people,
                              size: 16, color: AppTheme.hintTextColor),
                          const SizedBox(width: 4),
                          Text(playerInfo, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    gameDescription,
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
                      itemCount: gameImages.length,
                      itemBuilder: (context, index) {
                        final imageUrl = gameImages[index];

                        return Center(
                          child: GameThumbnail(
                            thumbnailUrl: imageUrl,
                            size: 300, // 少し小さめに調整
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
                          gameImages.length,
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
                              // ここでDB設計に基づく準備完了処理を追加
                              // rooms/{roomId}/currentGame/players/{player}/isReady = true
                              _updateReadyStatus();
                            },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),

                  // ★ ゲーム終了ボタン（ホストのみ表示） ★
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

  // DB設計に基づく準備完了状態の更新
  Future<void> _updateReadyStatus() async {
    final userState = ref.read(userProvider);
    final roomId = userState.roomId;
    final nickname = userState.nickname;

    if (roomId == null || nickname == null) return;

    try {
      // DB設計: rooms/{roomId}/currentGame/players 配列内の該当プレイヤーのisReadyをtrueに更新
      // 実装はAPI経由で行う想定
      print('準備完了状態を更新: $nickname in room $roomId');

      // TODO: API呼び出しを追加
      // await ApiService.updatePlayerReady(roomId, nickname, true);
    } catch (e) {
      print('準備完了状態の更新エラー: $e');
    }
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
    ref.read(currentGameProvider.notifier).clearGame();
    ref.read(userProvider.notifier).leaveRoom();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ゲームを終了しました')),
    );
  }
}
