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

class NoForeignWordPlayingPage extends ConsumerStatefulWidget {
  const NoForeignWordPlayingPage({super.key});

  @override
  ConsumerState<NoForeignWordPlayingPage> createState() =>
      _NoForeignWordPlayingPageState();
}

class _NoForeignWordPlayingPageState
    extends ConsumerState<NoForeignWordPlayingPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  bool isCorrectButtonLoading = false;
  bool isSkipButtonLoading = false;
  final pageTitle = '/0002/no_foreign_word_playing_page';
  String? isSelectedPlayer;

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
      Logger.log('NoForeignWordPlayingPageでエラー発生: $message');
    }
  }

  // 正解ボタンが押された時の処理
  Future<void> _handleCorrect(String roomId) async {
    // プレイヤーが選択されていない場合はスナックバーで警告
    if (isSelectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正解したプレイヤーを選択してください'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      isCorrectButtonLoading = true;
    });

    try {
      // result: true, answerUid: 選択されたUID
      await ApiService.reportResult0002(
        context,
        roomId,
        true,
        isSelectedPlayer!,
      );
      // 成功時の処理（必要であればログ出力など。画面遷移はStreamで検知される想定）
      Logger.log('正解を送信しました');
    } catch (e) {
      Logger.log('正解送信エラー: $e');
    } finally {
      if (mounted) {
        setState(() {
          isCorrectButtonLoading = false;
        });
      }
    }
  }

  // スキップボタンが押された時の処理
  Future<void> _handleSkip(String roomId) async {
    setState(() {
      isSkipButtonLoading = true;
    });

    try {
      // result: false, answerUid: 空文字（APIの仕様上必須のため）
      await ApiService.reportResult0002(
        context,
        roomId,
        false,
        '',
      );
      Logger.log('スキップを送信しました');
    } catch (e) {
      Logger.log('スキップ送信エラー: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSkipButtonLoading = false;
        });
      }
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

    final gameData = currentGame.gameData;
    final gameTitle = gameData?['title'] as String;

    final roomId = currentUser.roomId;

    // 現在の出題者情報を取得
    final currentPresenterUid = gameData?['currentPresenter'] as String?;
    final bool isCurrentPresenter = (currentPresenterUid != null &&
        currentUser.uid != null &&
        currentPresenterUid == currentUser.uid);

    // 現在のお題を取得
    final String currentTopic =
        gameData?['currentTopic'] as String? ?? 'お題待機中...';

    // 出題者名を表示するための変数を初期化
    String presenterNickname = '読み込み中...';

    // ドロップダウンリストに表示するプレイヤーリストを取得
    List<DropdownMenuItem<String>> playerDropdownItems = [];

    if (roomId != null) {
      final roomAsyncValue = ref.watch(roomStreamProvider(roomId));

      roomAsyncValue.whenData((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final players = data['players'] as Map<String, dynamic>?;

          if (players != null) {
            // 現在の出題者のニックネームを取得するロジック
            if (currentPresenterUid != null &&
                players.containsKey(currentPresenterUid)) {
              final presenterData =
                  players[currentPresenterUid] as Map<String, dynamic>;
              presenterNickname = presenterData['nickname'] as String? ?? '名無し';
            }

            players.forEach((uid, playerData) {
              // 自分（出題者）以外をリストに追加
              if (uid != currentUser.uid) {
                final nickname = playerData['nickname'] as String? ?? '名無し';
                playerDropdownItems.add(
                  DropdownMenuItem(
                    value: nickname,
                    child: Text(nickname),
                  ),
                );
              }
            });
          }
        }
      });
    }

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
        body: Center(
          child: isCurrentPresenter
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'あなたは出題者です',
                      style: AppTextStyles.h5,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.medium),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.large),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('お題',
                                        style: AppTextStyles.subtitle.copyWith(
                                            color:
                                                AppTheme.secondaryTextColor)),
                                    const SizedBox(height: AppSpacing.small),
                                    Text(currentTopic,
                                        style: AppTextStyles.subtitle.copyWith(
                                            color: AppTheme.error2Color)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSpacing.large),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '"カタカナ語を使わずに"お題を説明してください。',
                            style: AppTextStyles.body,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppSpacing.medium),
                          Text(
                            'お題を当てられたらそのプレイヤーを選んで「正解！」を押してください。正解者がいない場合や説明にカタカナ語を使ってしまった場合は「スキップ」を押してください。',
                            style: AppTextStyles.body,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.medium),
                      child: SizedBox(
                        width: 220,
                        child: DropdownButton(
                          isExpanded: true,
                          hint: const Text('プレイヤーを選択'),
                          items: playerDropdownItems,
                          onChanged: (String? value) {
                            setState(() {
                              isSelectedPlayer = value;
                            });
                          },
                          value: isSelectedPlayer,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.medium),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedLoadingButton(
                                text: '正解！',
                                isLoading: isCorrectButtonLoading,
                                onPressed: isSelectedPlayer != null
                                    ? () => _handleCorrect(roomId)
                                    : null,
                              ),
                            ),
                            SizedBox(width: AppSpacing.large),
                            Expanded(
                              child: OutlinedLoadingButton(
                                text: 'スキップ',
                                isLoading: isSkipButtonLoading,
                                onPressed: () => _handleSkip(roomId),
                              ),
                            )
                          ]),
                    )
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.medium),
                      child: Text('あなたは回答者です', style: AppTextStyles.h5),
                    ),
                    Text(
                      '出題者の説明を聞いてお題を当ててください。\n説明にカタカナ語が含まれていれば指摘しましょう。',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.medium),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.large),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('今回の出題者',
                                        style: AppTextStyles.subtitle.copyWith(
                                            color:
                                                AppTheme.secondaryTextColor)),
                                    const SizedBox(height: AppSpacing.small),
                                    Text(presenterNickname,
                                        style: AppTextStyles.subtitle.copyWith(
                                            color:
                                                AppTheme.secondaryTextColor)),
                                  ],
                                ),
                              ),
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
}
