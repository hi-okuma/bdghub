import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';

class BiasProfileParentTurnPage extends ConsumerStatefulWidget {
  const BiasProfileParentTurnPage({super.key});

  @override
  ConsumerState<BiasProfileParentTurnPage> createState() =>
      _BiasProfileParentTurnPageState();
}

class _BiasProfileParentTurnPageState
    extends ConsumerState<BiasProfileParentTurnPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  String? _errorMessage;
  int _selectedImageIndex = 0;
  int _imageReloadTrigger = 0;

  late final ScrollController _scrollController;

  @override
  final pageTitle = '/0004/bias_profile_parent_turn_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
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
      Logger.log('BiasProfileParentTurnPageでエラー発生: $message');
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
    final currentParent = gameData?['currentParent'] as String?;
    final isCurrentParent = currentParent == currentUser.uid;
    final gameTitle = gameData?['title'] as String;

    // 現在の部屋のお題を取得
    final topics = gameData?['topics'] as Map<String, dynamic>? ?? {};

    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    Map<String, dynamic> players = {};
    List<MapEntry<String, String>> sortedTopics = [];

    roomSnapshot.when(
      data: (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          players = data?['players'] as Map<String, dynamic>? ?? {};

          final playerUids = players.keys.toList();
          sortedTopics = playerUids
              .where((uid) => topics.containsKey(uid))
              .map((uid) => MapEntry(uid, topics[uid] as String))
              .toList();
        }
      },
      loading: () {
        sortedTopics = topics.entries
            .map((e) => MapEntry(e.key, e.value as String))
            .toList();
      },
      error: (_, __) {
        sortedTopics = topics.entries
            .map((e) => MapEntry(e.key, e.value as String))
            .toList();
      },
    );

    // 現在の部屋の回答を取得
    final hints = gameData?['hints'] as Map<String, dynamic>? ?? {};

    // 画像情報を取得
    final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];

    String _getNicknameByUid(String uid) {
      // ユーザー情報はroomのplayersフィールドから取得

      final roomSnapshot = ref.read(roomStreamProvider(roomId));

      return roomSnapshot.when(
        data: (snapshot) {
          if (!snapshot.exists) return 'Unknown';

          final data = snapshot.data() as Map<String, dynamic>?;
          final players = data?['players'] as Map<String, dynamic>? ?? {};

          return players[uid]?['nickname'] ?? 'Unknown';
        },
        loading: () => 'Loading...',
        error: (_, __) => 'Unknown',
      );
    }

    void _showTopicDialog(String topic, String? hint, String uid) {
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
                const SizedBox(height: AppSpacing.large),
                Text(_getNicknameByUid(uid),
                    style: AppTextStyles.body
                        .copyWith(color: AppTheme.secondaryTextColor))
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
            isCurrentParent
                ? const Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'あなたは親プレイヤーです',
                          style: AppTextStyles.h5,
                        ),
                        SizedBox(
                          height: AppSpacing.medium,
                        ),
                        Text(
                          '子プレイヤーが入力した偏見をもとに\n5枚の画像の中から正解の人物を当てよう',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        )
                      ],
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'あなたは子プレイヤーです',
                          style: AppTextStyles.h5,
                        ),
                        SizedBox(
                          height: AppSpacing.medium,
                        ),
                        Text(
                          '親が回答している間、他のプレイヤーが入力した\n偏見を覗いてみましょう',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
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
                            itemCount: sortedTopics.length,
                            itemBuilder: (context, index) {
                              return Card(
                                  margin: const EdgeInsets.only(
                                      bottom: AppSpacing.large),
                                  child: InkWell(
                                    onTap: () {
                                      final topicEntry = sortedTopics[index];
                                      final topicKey = topicEntry.key;
                                      final topic = topicEntry.value;
                                      final hint = hints[topicKey] as String?;
                                      ref
                                          .read(analyticsServiceProvider)
                                          .logPageView(
                                              pageTitle:
                                                  '/0004/bias_profile_topic_dialog',
                                              additionalParams: isHost
                                                  ? {'role': 'parent'}
                                                  : {'role': 'child'});
                                      _showTopicDialog(topic, hint, topicKey);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                          AppSpacing.large),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            sortedTopics[index].value,
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
            isCurrentParent
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.large),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              ref
                                  .read(analyticsServiceProvider)
                                  .logClick(button: '0004_determine_answer');

                              // API呼び出しのエラーハンドリング追加
                              try {
                                await ApiService.determineAnswer0004(
                                  context,
                                  roomId,
                                  currentUser.uid!,
                                  _selectedImageIndex,
                                );

                                Logger.log('💡 回答を提出: $_selectedImageIndex');

                                // 成功時のスナックバー表示
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('回答を送信しました'),
                                      backgroundColor: AppTheme.successColor,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                Logger.log('❌ 回答にに失敗: $e');
                                // エラーダイアログはErrorHandlerで表示される
                              }
                            },
                            child: const Text('この人物に決定する'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox()
          ],
        ),
      ),
    );
  }
}
