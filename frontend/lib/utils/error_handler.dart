import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../components/app_theme.dart';

class ErrorHandler {
  /// Firebase Functions (onCall) からのエラーを処理する
  static void handleFirebaseFunctionsException(
      BuildContext context, FirebaseFunctionsException e) {
    // FunctionsExceptionに含まれるメッセージを直接使用する
    final message = e.message ?? '不明なエラーが発生しました。';
    _showErrorSnackBar(context, message);
  }

  /// その他の予期せぬエラーを処理する
  static void handleGenericError(BuildContext context, Object e) {
    const message = '予期せぬエラーが発生しました。';
    _showErrorSnackBar(context, message);
  }

  /// エラーメッセージをスナックバーで表示する共通メソッド
  static void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error1Color,
        ),
      );
    }
  }
}
