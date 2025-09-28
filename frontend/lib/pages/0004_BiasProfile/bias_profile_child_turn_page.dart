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

class BiasProfileChildTurnPage extends ConsumerStatefulWidget {
  const BiasProfileChildTurnPage({super.key});

  @override
  ConsumerState<BiasProfileChildTurnPage> createState() =>
      _BiasProfileChildTurnPageState();
}

class _BiasProfileChildTurnPageState
    extends ConsumerState<BiasProfileChildTurnPage> with GameExitHandler {
  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
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
      return PopScope(
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

    bool isSoftwareKeyboardVisible =
        MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
            gameTitle: gameTitle,
            isHost: isHost,
            onExitPressed: showExitGameDialog),
        backgroundColor: AppTheme.backgroundColor,
        body: isCurrentParent
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
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.5,
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
                                    child: Image.network(
                                      answerImage,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
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
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
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
                              : SizedBox.shrink(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Row(
                        children: [
                          Expanded(
                            child: LoadingButton(
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
                                      if (profileText.isEmpty) {
                                        setState(() {
                                          _errorMessage = 'ヒントを入力してください';
                                        });
                                        return;
                                      }

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

                                      // API呼び出しのエラーハンドリング追加
                                      try {
                                        final result =
                                            await ApiService.submitHint0004(
                                                roomId,
                                                currentUser.uid!,
                                                profileText);

                                        if (result['success'] == true) {
                                          print('💡 ヒント提出: $profileText');

                                          // 成功時のスナックバー表示
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('提出を受け付けました'),
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
                                            setState(() {
                                              _isSubmitting = false;
                                            });
                                          }
                                        }
                                      } catch (e) {
                                        print('❌ ヒント提出に失敗: $e');

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
                                            _isSubmitting = false;
                                          });
                                        }
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
              ),
      ),
    );
  }
}
