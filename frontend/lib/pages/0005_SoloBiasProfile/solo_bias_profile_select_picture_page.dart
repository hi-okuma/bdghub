import 'package:bodogehub/utils/logger.dart';
import 'package:bodogehub/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:bodogehub/services/navigation_service.dart';

class SoloBiasProfileSelectPicturePage extends ConsumerStatefulWidget {
  const SoloBiasProfileSelectPicturePage({super.key});

  @override
  ConsumerState<SoloBiasProfileSelectPicturePage> createState() =>
      _SoloBiasProfileSelectPicturePageState();
}

class _SoloBiasProfileSelectPicturePageState
    extends ConsumerState<SoloBiasProfileSelectPicturePage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  String? _errorMessage;
  int _selectedImageIndex = 0;
  int _imageReloadTrigger = 0;
  late final ScrollController _scrollController;
  Future<void>? _precacheFuture;

  @override
  final pageTitle = '/0005/solo_bias_profile_select_picture_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;

    // 画像データを取得（この時点ではcontextが使えないのでreadを使用）
    final currentGame = ref.read(currentGameProvider);
    final gameData = currentGame.gameData;
    final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];

    // フレーム描画後にプリキャッシュを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ウィジェットがまだマウントされているか確認
      if (!mounted) return;

      setState(() {
        // プリキャッシュ処理を開始し、Futureを保持
        _precacheFuture =
            precacheImages(context, currentImages).catchError((error) {
          // プリキャッシュ全体が失敗した場合のフォールバック
          Logger.log('⚠️ プリキャッシュ処理でエラー: $error');
          // 画像はImage.networkのloadingBuilderで個別にハンドリングされるため
          // ここでは特別な処理は不要
        });
      });
    });

    _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    final currentGame = ref.read(currentGameProvider);
    final gameData = currentGame.gameData;
    final currentQuestionNumber =
        gameData?['currentQuestionNumber'] as int? ?? 0;
    ref
        .read(analyticsServiceProvider)
        .logPageView(pageTitle: '$pageTitle/$currentQuestionNumber');
  }

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      // エラーはErrorHandlerでグローバルに処理されるため、
      // ここでは主にデバッグログの出力や、必要に応じたUI状態の更新を行う
      Logger.log('SoloBiasProfileSelectPicturePageでエラー発生: $message');
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

    // 現在の問題のお題と回答を取得
    final topicsAndHints =
        gameData?['topicsAndHints'] as Map<String, dynamic>? ?? {};
    // お題と回答をリストに変換
    final List<String> topics = topicsAndHints.keys.toList();
    final List<String> hints = topicsAndHints.values.cast<String>().toList();

    // 画像情報を取得
    final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];

    final currentQuestionNumber =
        gameData?['currentQuestionNumber'] as int? ?? 0;

    void _showTopicDialog(String topic, String hint) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(topic),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$hint',
                  style: AppTextStyles.body,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    }

    void _onPictureSelected(int index) async {
      // 1. ローカルデータに選択状態を保存
      await ref.read(userProvider.notifier).updateLocalGameData({
        'selectedIndex': index,
      });

      // 2. 次の画面へ遷移
      if (!mounted) return;
      ref
          .read(navigationServiceProvider)
          .navigateToSoloBiasProfileCheckAnswerPage(_selectedImageIndex);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
            gameTitle: gameTitle,
            isHost: isHost,
            onExitPressed: () {
              ref.read(analyticsServiceProvider).logClick(button: 'game_quit');
              showExitGameDialog();
            }),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
                    child: Text(
                      '$currentQuestionNumber / 5 問目',
                      style: AppTextStyles.subtitle2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
                    child: Text(
                      '偏見ヒントをもとに\n'
                      '5枚の画像の中から正解の人物を当てよう',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium, horizontal: AppSpacing.large),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 画像表示エリア
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: AspectRatio(
                      aspectRatio: 7 / 10,
                      child: Card(
                        elevation: AppElevation.medium,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.small),
                        ),
                        clipBehavior: Clip.antiAlias,
                        color: AppTheme.selectedBackgroundColor,
                        child: currentImages.isNotEmpty
                            ? Image.network(
                                '${currentImages[_selectedImageIndex]}&reload=$_imageReloadTrigger', // URLに再読み込みトリガーを追加,
                                key: ValueKey(
                                    'parent_turn_$_imageReloadTrigger'), // Keyを再追加
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _imageReloadTrigger++;
                                              });
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.refresh,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                Text(
                                                  '再読み込み',
                                                  style: TextStyle(
                                                      color: AppTheme
                                                          .primaryColor),
                                                ),
                                              ],
                                            )),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Text('画像がありません'),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.medium),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(currentImages.length, (index) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.large),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedImageIndex = index;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedImageIndex == index
                                  ? AppTheme.primaryColor
                                  : AppTheme.selectedBackgroundColor,
                              foregroundColor: _selectedImageIndex == index
                                  ? Colors.white
                                  : AppTheme.secondaryTextColor,
                              elevation: AppElevation.none,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              '${index + 1}枚目',
                              style: AppTextStyles.body.copyWith(
                                  color: _selectedImageIndex == index
                                      ? Colors.white
                                      : AppTheme.secondaryTextColor),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.large),
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _scrollController,
                        child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            controller: _scrollController,
                            itemCount: topics.length,
                            itemBuilder: (context, index) {
                              return Card(
                                  margin: const EdgeInsets.only(
                                      bottom: AppSpacing.large),
                                  child: InkWell(
                                    onTap: () {
                                      final topic = topics[index];
                                      final hint = hints[index];
                                      ref
                                          .read(analyticsServiceProvider)
                                          .logPageView(
                                              pageTitle:
                                                  '/0005/solo_bias_profile_topic_dialog');
                                      _showTopicDialog(topic, hint);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                          AppSpacing.large),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            topics[index],
                                            style: AppTextStyles.subtitle2,
                                          ),
                                          const Icon(Icons.chevron_right),
                                        ],
                                      ),
                                    ),
                                  ));
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedLoadingButton(
                      text: 'この人物に決定する',
                      onPressed: () async {
                        ref
                            .read(analyticsServiceProvider)
                            .logClick(button: '0005_determine_answer');
                        _onPictureSelected(_selectedImageIndex);
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
