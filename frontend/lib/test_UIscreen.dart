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

class testBiasProfileChildrenTurnPage extends ConsumerStatefulWidget {
  const testBiasProfileChildrenTurnPage({super.key});

  @override
  ConsumerState<testBiasProfileChildrenTurnPage> createState() =>
      _testBiasProfileChildrenTurnPageState();
}

class _testBiasProfileChildrenTurnPageState
    extends ConsumerState<testBiasProfileChildrenTurnPage>
    with GameExitHandler {
  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  bool isHost = true;
  bool isSubmitted = false;
  final TextEditingController _profileController = TextEditingController();
  String? _errorMessage;

  void _onProfileChanged(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    final validation = ValidationUtils.validateProfile(value);
    if (!validation.isValid && value.isNotEmpty) {
      setState(() {
        _errorMessage = validation.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
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
        body: isHost
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'あなたは親プレイヤーです',
                      style: AppTextStyles.titleLarge,
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
                  children: <Widget>[
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'あなたは子プレイヤーです',
                          style: AppTextStyles.titleLarge,
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
                    Placeholder(
                      child: Container(
                        width: 180,
                        height: 270,
                        child: Text('ここにお題画像'),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ニックネーム入力
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.medium),
                          child: TextField(
                            maxLength: AppLayout.maxProfileLength,
                            controller: _profileController,
                            decoration: InputDecoration(
                              labelText:
                                  'ここにお題プロフィールを表示（${AppLayout.maxProfileLength}文字以内）',
                              hintText: '偏見を入力してください',
                              helperText: '※ \' \" ; - = / * は使用できません',
                            ),
                            onChanged: _onProfileChanged,
                          ),
                        ),
                        // エラー表示
                        if (_errorMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.small),
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.errorText,
                            ),
                          ),
                      ],
                    ),
                    Container(
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
                                setState(() {
                                  isSubmitted = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSubmitted
                                    ? AppTheme.hintTextColor
                                    : AppTheme.errorColor,
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.large),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppBorderRadius.medium),
                                ),
                              ),
                              child: Text(
                                isSubmitted ? '他プレイヤー待ち' : '提出',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
