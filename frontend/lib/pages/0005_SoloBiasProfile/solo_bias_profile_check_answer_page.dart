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

  // ★ 追加: このページで表示するデータを固定するための変数
  late final Map<String, dynamic> _fixedGameData;
  late final String _gameTitle;
  late final int _answerImageIndex;
  late final List<dynamic> _currentImages;
  late final int _currentQuestionNumber;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;

    // ★ 修正: initState内でデータを一度だけ読み込み（read）、固定します。
    // これにより、API呼び出し後にProviderが更新されても、このページは古い（正しい）結果を表示し続けます。
    final currentGame = ref.read(currentGameProvider);
    _fixedGameData = Map.from(currentGame.gameData ?? {});

    // 安全にデータを取り出しておく
    _gameTitle = _fixedGameData['title'] as String? ?? '';
    _currentImages = _fixedGameData['currentImages'] as List<dynamic>? ?? [];
    _answerImageIndex = _fixedGameData['answerImageIndex'] as int? ?? 0;
    _currentQuestionNumber =
        _fixedGameData['currentQuestionNumber'] as int? ?? 0;
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

  @override
  void didPopNext() {
    super.didPopNext();
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
      Logger.log('SoloBiasProfileCheckAnswerPageでエラー発生: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    // プロバイダーからデータを取得
    final currentUser = ref.watch(userProvider);
    final isHost = ref.watch(isHostProvider);

    // ゲームデータが空になった（＝ゲーム終了処理中）場合は、
    // 無理に描画せず、ローディングや空のコンテナを返してエラーを防ぐ
    // ★ データチェックも初期化時のデータを使用
    if (_fixedGameData.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final gameId = ref.read(currentGameProvider).gameId;
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

    // ★ 修正: ローカル変数を使用
    final isCorrect = _answerImageIndex == widget.selectedImageIndex;

    // 表示する画像のURLを動的に決定する
    final answerImageUrlToShow = _answerImageReloadTrigger > 0
        ? '${_currentImages[_answerImageIndex]}&reload=$_answerImageReloadTrigger'
        : _currentImages[_answerImageIndex];

    final selectedImageUrlToShow = _selectedImageReloadTrigger > 0
        ? '${_currentImages[widget.selectedImageIndex]}&reload=$_selectedImageReloadTrigger'
        : _currentImages[widget.selectedImageIndex];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
          gameTitle: _gameTitle,
          isHost: isHost,
          onExitPressed: () {
            ref.read(analyticsServiceProvider).logClick(
              button: 'game_quit',
              additionalParams: {'gameId': gameId!, 'page_title': pageTitle},
            );
            showExitGameDialog();
          },
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
              child: Text(
                '$_currentQuestionNumber / 5 問目',
                style: AppTextStyles.subtitle2,
                textAlign: TextAlign.center,
              ),
            ),
            // 上部のコンテンツ
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
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
                        'あなたが選んだ人物',
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

                                if (_currentQuestionNumber == 5) {
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
