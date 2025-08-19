import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/app_theme.dart';
import '/components/custom_widgets.dart';
import '/models/user_state.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';
import '/providers/game_provider.dart';
import '/providers/game_state_provider.dart';
import '/services/api_service.dart';

class GameTitlePage extends ConsumerStatefulWidget {
  const GameTitlePage({Key? key}) : super(key: key);

  @override
  ConsumerState<GameTitlePage> createState() => _GameTitlePageState();
}

class _GameTitlePageState extends ConsumerState<GameTitlePage>
    with GameExitHandler {
  String? _errorMessage;
  int _currentImageIndex = 0;
  bool _isPreparationCompleted = false; // 準備完了状態
  bool _isUpdatingReady = false; // ★API呼び出し中かどうか
  bool _isLoading = true;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  @override
  void setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
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
      return PopScope(
        canPop: false,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // ★ Riverpodからユーザー情報とゲーム情報を取得 ★
    final userState = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);

    final isHost = userState.isHost;
    final nickname = userState.nickname ?? '';
    final roomId = userState.roomId ?? '';

    // ★ ゲーム状態監視の継続 ★
    if (roomId.isNotEmpty) {
      final gameStateAsync = ref.watch(roomGameStateProvider(roomId));

      ref.listen(roomGameStateProvider(roomId), (previous, next) {
        next.whenOrNull(
          data: (status) {
            // waiting状態になったらゲーム選択画面に戻る
            if (status == GameStatus.waiting) {
              print('🎮 ゲーム終了検知：ゲーム選択画面に戻ります');
            }
          },
          error: (error, stackTrace) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('接続エラー: $error')),
            );
          },
        );
      });
    }

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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text('$gameTitle - 部屋: $roomId'),
          actions: [
            if (isHost)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.small),
                child: ElevatedButton(
                  onPressed: showExitGameDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.medium,
                      horizontal: AppSpacing.small,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // 追加
                    children: [
                      Icon(Icons.close, color: AppTheme.errorColor),
                      const SizedBox(width: AppSpacing.small), // アイコンとテキストの間隔
                      Text(
                        '終了',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          automaticallyImplyLeading: false,
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
                        isLoading: _isUpdatingReady, // ★API呼び出し中はスピナー表示
                        onPressed: _isPreparationCompleted || _isUpdatingReady
                            ? null // ★準備完了済みまたは通信中は押せない
                            : () async {
                                setState(() {
                                  _isUpdatingReady = true; // ★通信開始
                                });

                                try {
                                  await _updateReadyStatus(); // ★API呼び出し
                                  setState(() {
                                    _isPreparationCompleted =
                                        true; // ★成功時のみtrue
                                  });
                                } catch (e) {
                                  // エラー時は_isPreparationCompletedはfalseのまま
                                } finally {
                                  setState(() {
                                    _isUpdatingReady = false; // ★通信終了
                                  });
                                }
                              },
                      ),
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

  Future<void> _updateReadyStatus() async {
    final userState = ref.read(userProvider);
    final currentGame = ref.read(currentGameProvider);

    final roomId = userState.roomId;
    final nickname = userState.nickname;
    final uid = userState.uid; // ★ uidを追加で取得
    final gameId = currentGame.gameId; // ★ gameIdを取得

    if (roomId == null || nickname == null || uid == null || gameId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('準備完了の更新に失敗しました（必要な情報が不足しています）')),
      );
      return;
    }

    try {
      print('準備完了状態を更新: $nickname in room $roomId');

      // ★ API呼び出し実装
      final response = await ApiService.setReady(roomId, uid, gameId);

      print('準備完了状態の更新成功: $response');

      // 成功時のフィードバック（オプション）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('準備完了しました！')),
      );

      // 全員の準備が完了すると、Cloud Functionsにより
      // gameStatus が 'waiting' → 'playing' に自動更新され、
      // RoomGameStateNotifierが検知して自動ナビゲーション実行
    } catch (e) {
      print('準備完了状態の更新エラー: $e');

      // ★ エラー時の状態復旧
      setState(() {
        _isPreparationCompleted = false;
      });

      // エラーメッセージ表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('準備完了の更新に失敗しました: $e')),
      );
    }
  }
}
