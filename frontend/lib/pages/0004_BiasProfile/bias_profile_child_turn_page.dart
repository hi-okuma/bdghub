import 'package:bodogehub/services/analytics_service.dart';
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
import 'package:bodogehub/utils/validation_utils.dart';
import 'package:bodogehub/utils/image_utils.dart';

class BiasProfileChildTurnPage extends ConsumerStatefulWidget {
  const BiasProfileChildTurnPage({super.key});

  @override
  ConsumerState<BiasProfileChildTurnPage> createState() =>
      _BiasProfileChildTurnPageState();
}

class _BiasProfileChildTurnPageState
    extends ConsumerState<BiasProfileChildTurnPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  Future<void>? _precacheFuture;
  int _imageReloadTrigger = 0;
  final pageTitle = '/0004/bias_profile_child_turn_page';

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
    final isHost = ref.watch(isHostProvider);
    ref.read(analyticsServiceProvider).logPageView(
        pageTitle: pageTitle,
        additionalParams: isHost ? {'role': 'parent'} : {'role': 'child'});
  }

  @override
  void didPopNext() {
    super.didPopNext();
    final isHost = ref.watch(isHostProvider);
    ref.read(analyticsServiceProvider).logPageView(
        pageTitle: pageTitle,
        additionalParams: isHost ? {'role': 'parent'} : {'role': 'child'});
  }

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      // エラーはErrorHandlerでグローバルに処理されるため、
      // ここでは主にデバッグログの出力や、必要に応じたUI状態の更新を行う
      Logger.log('BiasProfileChildTurnPageでエラー発生: $message');
      setState(() {
        _errorMessage = message; // 必要に応じてローカルなエラーメッセージも設定
      });
    }
  }

  final TextEditingController _profileController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isValidInput = false;

  void _onProfileChanged(String value) {
    // エラーメッセージをクリア
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    // バリデーション実行
    final validation = ValidationUtils.validateProfile(value);

    // ★重要：バリデーション結果に関わらず毎回setStateで更新
    setState(() {
      _isValidInput = validation.isValid; // クラスフィールドを更新

      // エラーがある場合のみエラーメッセージを設定
      if (!validation.isValid && value.isNotEmpty) {
        _errorMessage = validation.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // プロバイダーからデータを取得
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);
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
    final currentParent = gameData?['currentParent'] as String?;
    final isCurrentParent = currentParent == currentUser.uid;
    final gameTitle = gameData?['title'] as String;

    // 現在のユーザーのお題を取得
    final topics = gameData?['topics'] as Map<String, dynamic>? ?? {};
    final currentUserTopic = topics[currentUser.uid] as String? ?? '';

    // 画像情報を取得
    final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];
    final answerImageIndex = gameData?['answerImageIndex'] as int? ?? 0;
    final answerImage =
        (currentImages.isNotEmpty && answerImageIndex < currentImages.length)
            ? currentImages[answerImageIndex] as String? ?? ''
            : '';

    // 既に提出済みかどうかの確認
    final hints = gameData?['hints'] as Map<String, dynamic>? ?? {};
    final hasSubmittedHint = hints.containsKey(currentUser.uid);

    // 表示する画像のURLを動的に決定する
    // _imageReloadTrigger が 0 のときは元のURL、1以上のときはパラメータを付与
    final imageUrlToShow = _imageReloadTrigger > 0
        ? '$answerImage&reload=$_imageReloadTrigger'
        : answerImage;

    bool isSoftwareKeyboardVisible =
        MediaQuery.of(context).viewInsets.bottom > 0;

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
        body: FutureBuilder(
          future: _precacheFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return isCurrentParent
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'あなたは親プレイヤーです',
                            style: AppTextStyles.h5,
                          ),
                          Text(
                            '子プレイヤーが偏見を入力するまでお待ちください',
                            style: AppTextStyles.body,
                          )
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          isSoftwareKeyboardVisible
                              ? const SizedBox.shrink()
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'あなたは子プレイヤーです',
                                      style: AppTextStyles.h5,
                                    ),
                                    SizedBox(
                                      height: AppSpacing.small,
                                    ),
                                    Text(
                                      '人物の見た目から勝手に想像して\n指定されたプロフィールを入力してください',
                                      style: AppTextStyles.body,
                                      textAlign: TextAlign.center,
                                    )
                                  ],
                                ),
                          Flexible(
                            flex: isSoftwareKeyboardVisible ? 2 : 4,
                            child: Center(
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: AspectRatio(
                                  aspectRatio: 7 / 10,
                                  child: answerImage.isEmpty
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : Card(
                                          elevation: AppElevation.medium,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                AppBorderRadius.small),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          color:
                                              AppTheme.selectedBackgroundColor,
                                          child: Image.network(
                                            imageUrlToShow,
                                            // URLに再読み込みトリガーを追加
                                            key: ValueKey(imageUrlToShow),
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
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
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons.refresh,
                                                              color: AppTheme
                                                                  .primaryColor,
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
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.large),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  maxLength: AppLayout.maxProfileLength,
                                  maxLines: AppLayout.maxProfileLines,
                                  controller: _profileController,
                                  decoration: InputDecoration(
                                    alignLabelWithHint: true,
                                    labelText: currentUserTopic.isEmpty
                                        ? 'お題を読み込み中...（${AppLayout.maxProfileLength}文字以内）'
                                        : '$currentUserTopic（${AppLayout.maxProfileLength}文字以内）',
                                    hintText: '偏見を入力してください',
                                  ),
                                  onChanged: _onProfileChanged,
                                ),
                                // エラー表示
                                _errorMessage != null
                                    ? Text(
                                        _errorMessage!,
                                        style: AppTextStyles.errorText,
                                      )
                                    : const SizedBox.shrink(),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.large),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedLoadingButton(
                                    text: hasSubmittedHint ? '他プレイヤー待ち' : '提出',
                                    isLoading: _isSubmitting,
                                    onPressed: (hasSubmittedHint ||
                                            _isSubmitting ||
                                            !_isValidInput) // 条件を修正
                                        ? null
                                        : () async {
                                            // asyncを追加
                                            // バリデーション
                                            final profileText =
                                                _profileController.text.trim();
                                            final validation =
                                                ValidationUtils.validateProfile(
                                                    profileText);
                                            if (!validation.isValid) {
                                              setState(() {
                                                _errorMessage =
                                                    validation.errorMessage;
                                              });
                                              return;
                                            }

                                            setState(() {
                                              _errorMessage = null;
                                              _isSubmitting = true; // 追加
                                            });

                                            ref
                                                .read(analyticsServiceProvider)
                                                .logClick(
                                                    button: '0004_hint_submit');

                                            // API呼び出しのエラーハンドリング追加
                                            try {
                                              await ApiService.submitHint0004(
                                                  context,
                                                  roomId,
                                                  currentUser.uid!,
                                                  profileText);

                                              Logger.log(
                                                  '💡 ヒント提出: $profileText');

                                              // 成功時のスナックバー表示
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text('提出を受け付けました'),
                                                    backgroundColor:
                                                        AppTheme.successColor,
                                                    duration:
                                                        Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              Logger.log('❌ ヒント提出に失敗: $e');
                                              // エラーダイアログはErrorHandlerで表示される
                                            } finally {
                                              setState(() {
                                                _isSubmitting = false; // ★通信終了
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
                    );
            } else {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
