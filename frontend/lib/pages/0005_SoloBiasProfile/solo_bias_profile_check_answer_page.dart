import 'package:bodogehub/services/navigation_service.dart';
import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:bodogehub/models/game_enums.dart';

class SoloBiasProfileCheckAnswerPage extends ConsumerStatefulWidget {
  final int selectedImageIndex;

  const SoloBiasProfileCheckAnswerPage(
      {super.key, required this.selectedImageIndex});

  @override
  ConsumerState<SoloBiasProfileCheckAnswerPage> createState() =>
      _BiasProfileCheckAnswerPageState();
}

class _BiasProfileCheckAnswerPageState
    extends ConsumerState<SoloBiasProfileCheckAnswerPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  int? parentSelectedIndex;
  bool isLoading = false;
  int _answerImageReloadTrigger = 0;
  int _selectedImageReloadTrigger = 0;

  late final ScrollController _scrollController;

  final pageTitle = '/0005/solo_bias_profile_check_answer_page';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      // エラーはErrorHandlerでグローバルに処理されるため、
      // ここでは主にデバッグログの出力や、必要に応じたUI状態の更新を行う
      Logger.log('SoloBiasProfileCheckAnswerPageでエラー発生: $message');
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

    // 画像情報を取得
    final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];
    final answerImageIndex = gameData?['answerImageIndex'] as int? ?? 0;
    final isCorrect = answerImageIndex == widget.selectedImageIndex;

    // 表示する画像のURLを動的に決定する
    // _imageReloadTrigger が 0 のときは元のURL、1以上のときはパラメータを付与
    final answerImageUrlToShow = _answerImageReloadTrigger > 0
        ? '${currentImages[answerImageIndex]}&reload=$_answerImageReloadTrigger'
        : currentImages[answerImageIndex];

    final selectedImageUrlToShow = _selectedImageReloadTrigger > 0
        ? '${currentImages[widget.selectedImageIndex]}&reload=$_selectedImageReloadTrigger'
        : currentImages[widget.selectedImageIndex];

    final currentQuestionNumber =
        gameData?['currentQuestionNumber'] as int? ?? 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
          gameTitle: gameTitle,
          isHost: isHost,
          onExitPressed: () {
            ref.read(analyticsServiceProvider).logClick(
              button: 'game_quit',
              additionalParams: {'page_title': pageTitle},
            );
            showExitGameDialog();
          },
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.medium),
                    child: Text(
                      '$currentQuestionNumber / 5 問目',
                      style: AppTextStyles.subtitle2
                          .copyWith(color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 上部のコンテンツ
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large),
                    child: isCorrect
                        ? const Text(
                            '正解！',
                            style: AppTextStyles.h5,
                          )
                        : const Text(
                            '不正解...',
                            style: AppTextStyles.h5,
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'お題',
                        style: AppTextStyles.body
                            .copyWith(color: AppTheme.secondaryTextColor),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
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
                            child: Image.network(
                              answerImageUrlToShow,
                              key: ValueKey(answerImageUrlToShow),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _answerImageReloadTrigger++;
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
                                                    color:
                                                        AppTheme.primaryColor),
                                              ),
                                            ],
                                          )),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '親が選んだ人物',
                        style: AppTextStyles.body
                            .copyWith(color: AppTheme.secondaryTextColor),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
                        child: AspectRatio(
                          aspectRatio: 7 / 10,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppBorderRadius.small),
                            ),
                            clipBehavior: Clip.antiAlias,
                            color: AppTheme.selectedBackgroundColor,
                            child: Image.network(
                              selectedImageUrlToShow, // URLに再読み込みトリガーを追加
                              key: ValueKey(selectedImageUrlToShow),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedImageReloadTrigger++;
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
                                                    color:
                                                        AppTheme.primaryColor),
                                              ),
                                            ],
                                          )),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedLoadingButton(
                      text: '次に進む',
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() {
                                isLoading = true;
                              });

                              ref
                                  .read(analyticsServiceProvider)
                                  .logClick(button: '0005_proceed_next');

                              // API呼び出しのエラーハンドリング追加
                              try {
                                await ApiService.proceedToNext0005(
                                    context, roomId, isCorrect);
                                Logger.log('プレイヤー${currentUser.uid} 準備完了');

                                await ref
                                    .read(userProvider.notifier)
                                    .clearLocalGameData(); //　ローカルゲームデータを削除

                                if (currentQuestionNumber == 5) {
                                  // ★ GamePhaseを ended に更新（これでリロードしても結果画面に戻るようになる）
                                  // ローカルストレージにも自動保存されます
                                  ref
                                      .read(userProvider.notifier)
                                      .updateGamePhase(GamePhase.ended);

                                  if (!mounted) return;

                                  ref
                                      .read(navigationServiceProvider)
                                      .navigateToSoloBiasProfileResultPage();
                                } else {
                                  ref
                                      .read(navigationServiceProvider)
                                      .navigateToSoloBiasProfileSelectPicturePage();
                                }
                              } catch (e) {
                                Logger.log('❌ 準備完了に失敗: $e');
                                // エラーダイアログはErrorHandlerで表示される
                              } finally {
                                setState(() {
                                  isLoading = false;
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
    );
  }
}
