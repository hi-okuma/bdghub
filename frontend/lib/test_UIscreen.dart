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

class testBiasProfileParentTurnPage extends ConsumerStatefulWidget {
  const testBiasProfileParentTurnPage({super.key});

  @override
  ConsumerState<testBiasProfileParentTurnPage> createState() =>
      _BiasProfileParentTurnPageState();
}

class _BiasProfileParentTurnPageState
    extends ConsumerState<testBiasProfileParentTurnPage> {
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

    final isCurrentParent = false;
    final isHost = true;
    final roomId = 'dummyRoom';

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
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
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
                        // TODO ListView.builderで表示させている画像は currentImages に格納されている配列から取得
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.medium),
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            return InkWell(
                              onTap: () {
                                //   TODO API(determineAPI004)に渡す画像を選択する処理 一度に選択できるのは１つの画像のみ
                              },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < 4 ? AppSpacing.small : 0,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 7 / 10,
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.network(
                                      // TODO currentImagesに格納されている画像を表示
                                      'https://picsum.photos/200/300',
                                      fit: BoxFit.cover,
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
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.medium),
                            child: Card(
                              margin: EdgeInsets.fromLTRB(
                                  0, 0, 0, AppSpacing.medium),
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.medium),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // TODO topics に格納されているお題を表示
                                    Text('ここにお題プロフィールを表示'),
                                    Icon(Icons.arrow_forward),
                                  ],
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
                                    onPressed: () {
                                      //   ここでAPI(determineAnswer0004)を叩く
                                    },
                                    child: Text('この人物に決定'))),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: MediaQuery.of(context).size.width * 0.1,
                      )
              ],
            ),
          )),
    );
  }
}
