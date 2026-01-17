import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/models/game_enums.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:bodogehub/services/navigation_service.dart';

class SoloBiasProfileResultPage extends ConsumerStatefulWidget {
  const SoloBiasProfileResultPage({super.key});

  @override
  ConsumerState<SoloBiasProfileResultPage> createState() =>
      _SoloBiasProfileResultPageState();
}

class _SoloBiasProfileResultPageState
    extends ConsumerState<SoloBiasProfileResultPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  String? _errorMessage;

  @override
  final pageTitle = '/game_result_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    final gameId = ref.read(currentGameProvider).gameId;
    ref
        .read(analyticsServiceProvider)
        .logPageView(pageTitle: '/${gameId}${pageTitle}');
  }

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      // エラーはErrorHandlerでグローバルに処理されるため、
      // ここでは主にデバッグログの出力や、必要に応じたUI状態の更新を行う
      Logger.log('SoloBiasProfileResultPageでエラー発生: $message');
      setState(() {
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // プロバイダーからデータを取得
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);

    // ゲームデータが空になった（＝ゲーム終了処理中）場合は、
    // 無理に描画せず、ローディングや空のコンテナを返してエラーを防ぐ
    if (currentGame.gameData == null || currentGame.gameData!.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(), // または SizedBox() でもOK
        ),
      );
    }

    final gameId = currentGame.gameId;
    final roomId = currentUser.roomId;

    // 部屋情報がない場合のエラーハンドリング
    if (roomId == null) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Text(
              '部屋情報が見つかりません',
              style: AppTextStyles.subtitle,
            ),
          ),
        ),
      );
    }

    // 必要な情報を直接取得
    final gameData = currentGame.gameData;
    final gameTitle = gameData?['title'] as String;

    final int point = gameData?['point'];

    // 「もう一度遊ぶ」ボタンの処理例
    void _onReplayGame() async {
      final userNotifier = ref.read(userProvider.notifier);

      // 1. ローカルの一時データをクリア（画像の選択状態などを消す）
      await userNotifier.clearLocalGameData();

      // 2. フェーズを started に戻す
      // これを忘れると、リロードした瞬間にまた結果画面に飛んでしまいます
      userNotifier.updateGamePhase(GamePhase.started);

      // 3. 写真選択画面へ遷移
      if (!mounted) return;
      ref
          .read(navigationServiceProvider)
          .navigateToSoloBiasProfileSelectPicturePage();
    }

    return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: GameAppBar(
              gameTitle: gameTitle,
              isHost: isHost,
              onExitPressed: () {
                ref
                    .read(analyticsServiceProvider)
                    .logClick(button: 'game_quit');
                showExitGameDialog();
              }),
          backgroundColor: AppTheme.backgroundColor,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.xxxLarge),
                      child: Text(
                        '結果発表',
                        style: AppTextStyles.h5,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxxLarge),
                      child: _buildResultContent(point),
                    ),
                    Container(
                      color: AppTheme.selectedBackgroundColor,
                      height: 100,
                      width: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$point / 5',
                              style: AppTextStyles.h5,
                              textAlign: TextAlign.center),
                          const Text(
                            '問正解',
                            style: AppTextStyles.body,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.large),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              ref
                                  .read(analyticsServiceProvider)
                                  .logClick(button: '${gameId}_game_replay');

                              _onReplayGame();
                            },
                            child: const Text('もう一度遊ぶ'),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ));
  }
}

// pointに応じたウィジェットを返すメソッド
Widget _buildResultContent(int point) {
  switch (point) {
    case 5:
      return const Column(
        children: [
          Text('😏', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('あなた、偏見の塊ですね', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('全問正解とは...思い込みが激しすぎます', style: AppTextStyles.body),
        ],
      );
    case 4:
      return const Column(
        children: [
          Text('🤔', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('なかなかの偏見持ちですね', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('もう少しで偏見マスターでした', style: AppTextStyles.body),
        ],
      );
    case 3:
      return const Column(
        children: [
          Text('😅', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('普通に偏見ありますね', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('世間並みの固定観念をお持ちのようです', style: AppTextStyles.body),
        ],
      );
    case 2:
      return const Column(
        children: [
          Text('🙄', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('偏見が足りないようですね', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('もっと決めつけてもいいんですよ？', style: AppTextStyles.body),
        ],
      );
    case 1:
      return const Column(
        children: [
          Text('😇', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('偏見なさすぎて心配です', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('もしかして聖人ですか？', style: AppTextStyles.body),
        ],
      );
    case 0:
      return const Column(
        children: [
          Text('😇', style: TextStyle(fontSize: 40)),
          SizedBox(height: AppSpacing.medium),
          Text('偏見なさすぎて心配です', style: AppTextStyles.h5),
          SizedBox(height: AppSpacing.medium),
          Text('もしかして聖人ですか？', style: AppTextStyles.body),
        ],
      );
    default:
      // 想定外の値（nullの場合など）のハンドリング
      return const Text('結果集計中...', style: AppTextStyles.body);
  }
}
