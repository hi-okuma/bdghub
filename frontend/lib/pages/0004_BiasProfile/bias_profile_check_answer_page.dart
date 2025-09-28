import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/error_handler.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';

class BiasProfileCheckAnswerPage extends ConsumerStatefulWidget {
  const BiasProfileCheckAnswerPage({super.key});

  @override
  ConsumerState<BiasProfileCheckAnswerPage> createState() =>
      _BiasProfileCheckAnswerPageState();
}

class _BiasProfileCheckAnswerPageState
    extends ConsumerState<BiasProfileCheckAnswerPage> with GameExitHandler {
  String? _errorMessage;
  int? parentSelectedIndex;
  bool isLoading = false;
  bool hasProceeded = false;

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
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

    parentSelectedIndex = gameData?['parentSelectedIndex'] as int? ?? 0;

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
    final answerImageIndex = gameData?['answerImageIndex'] as int? ?? 0;

    final isRight = answerImageIndex == parentSelectedIndex;

    String _getNicknameByUid(String uid) {
      return players[uid]?['nickname'] ?? 'Unknown';
    }

    void _showTopicDialog(String topic, String? hint, String uid) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          bool dialogIsLoading = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(topic),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$hint', style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.large),
                    Text(_getNicknameByUid(uid),
                        style: AppTextStyles.body
                            .copyWith(color: AppTheme.secondaryTextColor)),
                    if (dialogIsLoading) ...[
                      const Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  0, AppSpacing.large, 0, 0),
                              child: SizedBox(
                                width: AppIconSizes.large,
                                height: AppIconSizes.large,
                                child: CircularProgressIndicator(
                                    strokeWidth:
                                        AppLayout.circleIndicatorStroke),
                              ),
                            ),
                            Text('他プレイヤー待ち...', style: AppTextStyles.body),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  dialogIsLoading
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('閉じる'),
                        ),
                  dialogIsLoading
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: () async {
                            setDialogState(() {
                              dialogIsLoading = true;
                            });

                            // API呼び出しのエラーハンドリング追加
                            try {
                              final result = await ApiService.proceedToNext0004(
                                roomId,
                                currentUser.uid!,
                                uid,
                              );

                              if (result['success'] == true) {
                                print(
                                    '💡 わかるde賞を提出: ${_getNicknameByUid(uid)}の回答');

                                // 成功時のスナックバー表示
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('わかるde賞を提出しました'),
                                      backgroundColor: AppTheme.successColor,
                                      duration: AppAnimations.snackBarDuration,
                                    ),
                                  );
                                }
                              } else {
                                // APIからの失敗レスポンス
                                if (mounted) {
                                  ApiErrorHandler.handleApiError(
                                      context, result, setError);
                                }
                                setDialogState(() {
                                  dialogIsLoading = false;
                                });
                              }
                            } catch (e) {
                              print('❌ 送信に失敗: $e');

                              if (mounted) {
                                // http.Response型のエラーかどうかで処理を分ける
                                if (e is http.Response) {
                                  ApiErrorHandler.handleHttpError(
                                      context, e, setError);
                                } else {
                                  ApiErrorHandler.handleException(
                                      context, e, setError);
                                }
                              }
                              setDialogState(() {
                                dialogIsLoading = false;
                              });
                            }
                          },
                          child: const Text('わかるde賞に決定')),
                ],
              );
            },
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
            onExitPressed: showExitGameDialog),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            // 上部のコンテンツ
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
              child: isRight
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
                      Container(
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
                            child: Image.network(
                              currentImages[answerImageIndex],
                              fit: BoxFit.cover,
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
                      Container(
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
                            child: Image.network(
                              currentImages[parentSelectedIndex!],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 中央部分のコンテンツ（親プレイヤーの場合）
            if (isCurrentParent)
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('わかるde賞を選ぼう', style: AppTextStyles.h5),
                      const SizedBox(height: AppSpacing.medium),
                      const Text(
                        'もっとも「わかる！」と共感できたヒントを選ぼう\n選ばれたプレイヤーには1ポイントが与えられます',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      Expanded(
                        child: ListView.builder(
                            itemCount: sortedTopics.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin:
                                    EdgeInsets.only(bottom: AppSpacing.medium),
                                child: InkWell(
                                  onTap: () {
                                    final topicEntry = sortedTopics[index];
                                    final topicKey = topicEntry.key;
                                    final topic = topicEntry.value;
                                    final hint = hints[topicKey] as String?;
                                    _showTopicDialog(topic, hint, topicKey);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.medium,
                                        horizontal: AppSpacing.large),
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
                                ),
                              );
                            }),
                      )
                    ],
                  ),
                ),
              ),

            // 親プレイヤーでない場合、余白を作る
            if (!isCurrentParent) const Spacer(),

            // 下部に固定するボタン（親プレイヤーでない場合のみ）
            if (!isCurrentParent)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Row(
                  children: [
                    Expanded(
                      child: LoadingButton(
                        text: hasProceeded ? '他プレイヤー待ち' : '次に進む',
                        isLoading: isLoading,
                        onPressed: hasProceeded
                            ? null
                            : () async {
                                setState(() {
                                  isLoading = true;
                                });

                                // API呼び出しのエラーハンドリング追加
                                try {
                                  final result = await ApiService.proceedToNext0004(
                                      roomId,
                                      currentUser.uid!,
                                      ''); // 子プレイヤーによるAPI実行のため、bestHintPlayerUidは空文字でリクエスト実行
                                  if (result['success'] == true) {
                                    print('プレイヤー${currentUser.uid} 準備完了');

                                    // 成功時のスナックバー表示
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('準備完了！'),
                                          backgroundColor:
                                              AppTheme.successColor,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    // APIからの失敗レスポンス
                                    if (mounted) {
                                      ApiErrorHandler.handleApiError(
                                          context, result, setError);
                                    }
                                  }
                                } catch (e) {
                                  print('❌ 準備完了に失敗: $e');

                                  if (mounted) {
                                    // http.Response型のエラーかどうかで処理を分ける
                                    if (e is http.Response) {
                                      ApiErrorHandler.handleHttpError(
                                          context, e, setError);
                                    } else {
                                      ApiErrorHandler.handleException(
                                          context, e, setError);
                                    }
                                    setState(() {
                                      hasProceeded = false;
                                    });
                                  }
                                } finally {
                                  setState(() {
                                    isLoading = false;
                                    hasProceeded = true;
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
