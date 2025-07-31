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
import 'package:bodogehub/services/navigation_service.dart';
import 'package:bodogehub/utils/error_handler.dart';

/// ゲーム終了処理の共通ロジックを提供するミックスイン
mixin GameExitHandler<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// エラーメッセージを設定する関数（各クラスで実装する必要がある）
  void setError(String message);

  /// 状態クリア処理
  void clearGameState() {
    // プロバイダーの状態をクリア
    ref.read(currentGameProvider.notifier).clearGame();
    print('🔄 ゲーム終了: currentGameProviderをクリア完了');
  }

  /// 統合されたゲーム終了処理
  Future<void> exitGame(String roomId) async {
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('部屋情報が見つかりません')),
      );
      return;
    }

    try {
      // 1. ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.medium),
                  Text(
                    'ゲームを終了しています...',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 2. API呼び出し（ゲーム終了処理）
      final result = await ApiService.endGame(roomId);

      // 3. ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる
      }

      if (result['success'] == true) {
        print('✅ ゲーム終了処理が完了しました');

        // 4. ★修正★ 手動遷移を削除
        // room.statusがwaitingに変更されることで、
        // 全プレイヤー（ホスト含む）が自動的に画面遷移する

        // 5. 状態をクリア
        if (mounted) {
          clearGameState();

          // 6. 成功時のメッセージ表示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ゲームを終了しました'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 7. APIからの失敗レスポンス処理
        if (mounted) {
          ApiErrorHandler.handleApiError(context, result, setError);
        }
      }
    } catch (e) {
      print('❌ ゲーム終了処理に失敗: $e');

      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる（エラー時）

        // 8. エラーハンドリング
        if (e is http.Response) {
          ApiErrorHandler.handleHttpError(context, e, setError);
        } else {
          ApiErrorHandler.handleException(context, e, setError);
        }
      }
    }
  }

  /// 終了確認ダイアログを表示
  void showExitGameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ゲームを終了しますか？'),
          content: const Text('ホストがゲームを終了すると、全参加者がゲーム選択画面に戻ります。'),
          actions: [
            LoadingButton(
              text: 'キャンセル',
              isLoading: false,
              isElevated: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
            LoadingButton(
              text: 'ゲーム終了',
              isLoading: false,
              onPressed: () async {
                Navigator.of(context).pop();

                // 部屋IDを取得してゲーム終了処理を実行
                final currentUser = ref.read(userProvider);
                final roomId = currentUser.roomId;

                if (roomId != null) {
                  await exitGame(roomId);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
