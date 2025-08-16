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
      return Scaffold(
        body: Center(
          child: Text(
            '部屋情報が見つかりません',
            style: AppTextStyles.bodyLarge,
          ),
        ),
      );
    }

    // 必要な情報を直接取得
    final gameData = currentGame.gameData;
    final currentParent = gameData?['currentParent'] as String?;
    final isCurrentParent = currentParent == currentUser.uid;

    // 現在の部屋のお題を取得
    final topics = gameData?['topics'] as Map<String, dynamic>? ?? {};
    final topicsValue = topics.values.toList();

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
                Text('${_getNicknameByUid(uid)}のヒント'),
                SizedBox(height: AppSpacing.small),
                Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: AppTheme.backgroundColor),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Text(
                        '${hint}',
                        style: AppTextStyles.bodyLarge,
                      ),
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('閉じる'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          // ホストプレイヤーのみ終了ボタンを表示
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: AppTheme.errorColor),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      '終了',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            isCurrentParent
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'あなたは親プレイヤーです',
                        style: AppTextStyles.titleLarge,
                      ),
                      Text(
                        '子プレイヤーが入力した偏見から\nお題となる人物を当てよう',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      )
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'あなたは子プレイヤーです',
                        style: AppTextStyles.titleLarge,
                      ),
                      Text(
                        '親が回答している間、他のプレイヤーが入力した\nプロフィールを覗いてみましょう',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      )
                    ],
                  ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                      itemCount: currentImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < currentImages.length
                                ? AppSpacing.small
                                : 0,
                          ),
                          child: AspectRatio(
                            aspectRatio: 7 / 10,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                                side: _selectedImageIndex == index
                                    ? BorderSide(
                                        width: 3.0,
                                        color: AppTheme.primaryColor)
                                    : BorderSide.none,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: isCurrentParent
                                    ? () {
                                        setState(() {
                                          _selectedImageIndex = index;
                                        });
                                      }
                                    : null,
                                child: Image.network(
                                  currentImages[index],
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
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
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        '画像の読み込みに\n失敗しました',
                                        style: AppTextStyles.body,
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: topics.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                        child: Card(
                          margin:
                              EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.medium),
                          child: InkWell(
                            onTap: () {
                              final topicKey = topics.keys.elementAt(index);
                              final topic = topicsValue[index];
                              final hint = hints[topicKey] as String?;
                              _showTopicDialog(topic, hint, topicKey);
                            },
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.medium),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(topicsValue[index]),
                                  Icon(Icons.arrow_forward),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
              ),
            ),
            isCurrentParent
                ? Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.medium),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _selectedImageIndex != null
                                ? () async {
                                    try {
                                      await ApiService.determineAnswer0004(
                                        roomId,
                                        currentUser.uid!,
                                        _selectedImageIndex.toString(),
                                      );
                                    } catch (e) {
                                      setError('回答の決定に失敗しました: $e');
                                    }
                                  }
                                : null,
                            child: Text('この人物に決定'),
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: MediaQuery.of(context).size.width * 0.1,
                  )
          ],
        ),
      ),
    );
  }
}
