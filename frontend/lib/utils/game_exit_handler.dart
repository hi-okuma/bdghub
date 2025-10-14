import 'package:bodogehub/utils/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/game_state_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/services/navigation_service.dart';

/// ゲーム終了処理の共通ロジックを提供するミックスイン
mixin GameExitHandler<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// エラーメッセージを設定する関数（各クラスで実装する必要がある）
  void setError(String message);

  /// 状態クリア処理
  void clearGameState() {
    // プロバイダーの状態をクリア
    ref.read(currentGameProvider.notifier).clearGame();
    Logger.log('🔄 ゲーム終了: currentGameProviderをクリア完了');
  }

  /// 統合されたゲーム終了処理
  Future<void> exitGame(String roomId) async {
    if (roomId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('部屋情報が見つかりません')),
        );
      }
      return;
    }

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Dialog(
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

    try {
      // API呼び出し（ゲーム終了処理）
      await ApiService.endGame(context, roomId);

      Logger.log('✅ ゲーム終了処理が完了しました');

      // 状態をクリア
      if (mounted) {
        clearGameState();

        // 成功時のメッセージ表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ゲームを終了しました'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // room.statusがwaitingに変更されることで、
      // 全プレイヤー（ホスト含む）が自動的に画面遷移する
    } catch (e) {
      Logger.log('❌ ゲーム終了処理に失敗: $e');
      // エラーダイアログはErrorHandlerで表示される
    } finally {
      // ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();
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
          content: const Text('ゲームを終了すると、参加者全員がゲーム選択画面に戻ります。'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('キャンセル',
                    style: TextStyle(color: AppTheme.secondaryTextColor))),
            TextButton(
              child: const Text('ゲーム終了'),
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
