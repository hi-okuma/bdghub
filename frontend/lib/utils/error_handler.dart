import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiErrorHandler {
  static void handleApiError(
    BuildContext context,
    Map<String, dynamic> responseData,
    Function(String) setError,
  ) {
    final String errorMsg = responseData.containsKey('message')
        ? responseData['message']
        : '操作に失敗しました';

    setError(errorMsg);
    _showSnackBar(context, errorMsg);
  }

  static void handleHttpError(
    BuildContext context,
    http.Response response,
    Function(String) setError,
  ) {
    try {
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      final String errorMsg = errorData.containsKey('message')
          ? '${errorData['message']}'
          : 'エラー: ${response.statusCode}';

      setError(errorMsg);
      _showSnackBar(context, errorMsg);
    } catch (e) {
      final String errorMsg = '応答の解析に失敗しました: ${response.body}';
      setError(errorMsg);
      _showSnackBar(context, errorMsg);
    }
  }

  static void handleException(
    BuildContext context,
    dynamic e,
    Function(String) setError,
  ) {
    final String errorMsg = '通信エラー: $e';
    setError(errorMsg);
    _showSnackBar(context, errorMsg);
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
