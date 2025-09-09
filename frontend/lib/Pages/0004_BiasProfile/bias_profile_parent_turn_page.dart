import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/game_state_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/error_handler.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:bodogehub/utils/validation_utils.dart';

class BiasProfileParentTurnPage extends ConsumerStatefulWidget {
  const BiasProfileParentTurnPage({super.key});

  @override
  ConsumerState<BiasProfileParentTurnPage> createState() =>
      _BiasProfileParentTurnPageState();
}

class _BiasProfileParentTurnPageState
    extends ConsumerState<BiasProfileParentTurnPage> with GameExitHandler {
  String? _errorMessage;
  int? _selectedImageIndex;

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
                  '${hint}',
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
            onExitPressed: showExitGameDialog),
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                isCurrentParent
                    ? const Column(
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
                            '子プレイヤーが入力した偏見から\nお題となる人物を当てよう',
                            style: AppTextStyles.body,
                            textAlign: TextAlign.center,
                          )
                        ],
                      )
                    : const Column(
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
                            '親が回答している間、他のプレイヤーが入力した\nプロフィールを覗いてみましょう',
                            style: AppTextStyles.body,
                            textAlign: TextAlign.center,
                          )
                        ],
                      ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.small),
                  child: Flexible(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index < currentImages.length
                                        ? AppSpacing.xSmall
                                        : 0,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 7 / 10,
                                    child: Stack(
                                      children: [
                                        Opacity(
                                          opacity: _selectedImageIndex == index
                                              ? 0.5
                                              : 1.0,
                                          child: Card(
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppBorderRadius.small),
                                              // 枠線の部分を削除
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: isCurrentParent
                                                  ? () {
                                                      setState(() {
                                                        _selectedImageIndex =
                                                            index;
                                                      });
                                                    }
                                                  : null,
                                              child: Image.network(
                                                currentImages[index],
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Center(
                                                    child: Text(
                                                      '画像の読み込みに\n失敗しました',
                                                      style: AppTextStyles.body,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        // チェックマークを右下に配置
                                        if (_selectedImageIndex == index)
                                          Positioned(
                                            right: 15,
                                            bottom: 25,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check_circle,
                                                color: AppTheme.primaryColor,
                                                size: AppIconSizes.large,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                      itemCount: sortedTopics.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.fromLTRB(
                              0, 0, 0, AppSpacing.medium),
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
                ),
                isCurrentParent
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.medium),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceColor,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedImageIndex != null
                                    ? () async {
                                        // API呼び出しのエラーハンドリング追加
                                        try {
                                          final result = await ApiService
                                              .determineAnswer0004(
                                            roomId,
                                            currentUser.uid!,
                                            _selectedImageIndex!,
                                          );

                                          if (result['success'] == true) {
                                            print(
                                                '💡 回答を提出: $_selectedImageIndex');

                                            // 成功時のスナックバー表示
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text('回答を送信しました'),
                                                  backgroundColor:
                                                      AppTheme.successColor,
                                                  duration:
                                                      Duration(seconds: 2),
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
                                          print('❌ 回答にに失敗: $e');

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
                                        }
                                      }
                                    : null,
                                child: const Text('この人物に決定'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
