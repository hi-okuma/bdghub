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

class testBiasProfileCheckAnswerPage extends ConsumerStatefulWidget {
  const testBiasProfileCheckAnswerPage({super.key});

  @override
  ConsumerState<testBiasProfileCheckAnswerPage> createState() =>
      _testBiasProfileCheckAnswerPageState();
}

class _testBiasProfileCheckAnswerPageState
    extends ConsumerState<testBiasProfileCheckAnswerPage> {
  // 本番ページでは以下のmixinを設定
  // with GameExitHandler
  // // エラーメッセージを設定する関数（GameExitHandler用）
  // @override
  // void setError(String message) {
  //   if (mounted) {
  //     setState(() {
  //       _errorMessage = message;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // // プロバイダーからデータを取得
    // final currentUser = ref.watch(userProvider);
    // final currentGame = ref.watch(currentGameProvider);
    // final isHost = ref.watch(isHostProvider);
    // final roomId = currentUser.roomId;

    final isCurrentParent = true;
    final isHost = true;
    final roomId = 'dummyRoom';
    final isRight = false; // TODO 親の選択した画像のindexと正解のindexが一致するかを判定

    // 部屋情報がない場合のエラーハンドリング
    if (roomId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            '部屋情報が見つかりません',
            style: AppTextStyles.subtitle,
          ),
        ),
      );
    }
    //
    // // 必要な情報を直接取得
    // final gameData = currentGame.gameData;
    // final currentParent = gameData?['currentParent'] as String?;
    // final isCurrentParent = currentParent == currentUser.uid;

    // // 現在のユーザーのお題を取得
    // final topics = gameData?['topics'] as Map<String, dynamic>? ?? {};
    // final currentUserTopic = topics[currentUser.uid] as String? ?? '';
    //
    // // 画像情報を取得
    // final currentImages = gameData?['currentImages'] as List<dynamic>? ?? [];
    // final answerImageIndex = gameData?['answerImageIndex'] as int? ?? 0;
    // final answerImage =
    // (currentImages.isNotEmpty && answerImageIndex < currentImages.length)
    //     ? currentImages[answerImageIndex] as String? ?? ''
    //     : '';
    //
    // // 既に提出済みかどうかの確認
    // final hints = gameData?['hints'] as Map<String, dynamic>? ?? {};
    // final hasSubmittedHint = hints.containsKey(currentUser.uid);

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            // ホストプレイヤーのみ終了ボタンを表示
            if (isHost)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.small),
                child: ElevatedButton(
                  onPressed: () {},
                  // showExitGameDialog,
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
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            isRight
                ? Flexible(
                    flex: 1,
                    child: Text(
                      '正解！',
                      style: AppTextStyles.h5,
                    ),
                  )
                : Flexible(
                    flex: 1,
                    child: Text(
                      '不正解...',
                      style: AppTextStyles.h5,
                    ),
                  ),
            Flexible(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'お題',
                              style: AppTextStyles.body,
                            ),
                            Container(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: AspectRatio(
                                aspectRatio: 7 / 10,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    // TODO currentImagesの正解画像を表示
                                    'https://picsum.photos/200/300',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '親が選んだ人物',
                              style: AppTextStyles.body,
                            ),
                            Container(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: AspectRatio(
                                aspectRatio: 7 / 10,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    // TODO 親が選択した画像のindexの画像を表示
                                    'https://picsum.photos/200/300',
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
                ],
              ),
            ),
            Flexible(
              flex: 2,
              child: isCurrentParent
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('わかるde賞を選ぼう', style: AppTextStyles.titleMedium),
                        Text(
                          'もっとも「わかる！」と共感できたヒントを選ぼう\n選ばれたプレイヤーには1ポイントが与えられます',
                          textAlign: TextAlign.center,
                        ),
                        Expanded(
                          child: ListView.builder(
                              itemCount: 5,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.medium),
                                  child: Card(
                                    margin: EdgeInsets.fromLTRB(
                                        0, 0, 0, AppSpacing.medium),
                                    child: InkWell(
                                      onTap: () {
                                        // final topicKey = topics.keys.elementAt(index);
                                        // final topic = topicsValue[index];
                                        // final hint = hints[topicKey] as String?;
                                        // _showTopicDialog(topic, hint, topicKey);
                                      },
                                      child: Padding(
                                        padding:
                                            EdgeInsets.all(AppSpacing.medium),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('ここにお題が表示されます'),
                                            // Text(topicsValue[index]),
                                            Icon(Icons.arrow_forward),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        )
                      ],
                    )
                  : Center(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppSpacing.medium),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: () {}, child: Text('次に進む')))
                          ],
                        ),
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
