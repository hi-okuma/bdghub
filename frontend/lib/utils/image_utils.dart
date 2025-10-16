import 'package:flutter/material.dart';
import 'logger.dart';

/// 複数の画像URLをプリキャッシュする
///
/// [urls] に含まれる全ての画像のキャッシュを試みる。
/// 一部の画像が失敗しても処理を継続する。
///
/// [context] - ビルドコンテキスト
/// [urls] - プリキャッシュする画像URLのリスト
/// [timeout] - 各画像のタイムアウト時間（デフォルト: 3秒）
Future<void> precacheImages(
  BuildContext context,
  List<dynamic> urls, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  // 有効なURLのみをフィルタリング（型安全性を向上）
  final validUrls = urls
      .whereType<String>()
      .where((url) => url.startsWith('http://') || url.startsWith('https://'))
      .toList();

  if (validUrls.isEmpty) {
    Logger.log('⚠️ プリキャッシュする画像がありません');
    return;
  }

  Logger.log('🖼️ ${validUrls.length}枚の画像をプリキャッシュ開始');

  // 全ての画像を並列でプリキャッシュ（エラーは無視）
  final results = await Future.wait(
    validUrls.map((url) => precacheImage(NetworkImage(url), context).timeout(
          timeout,
          onTimeout: () {
            Logger.log('⏱️ プリキャッシュがタイムアウト: $url');
          },
        ).catchError((error) {
          Logger.log('❌ プリキャッシュに失敗: $url\nエラー: $error');
        })),
    eagerError: false, // 一部のエラーで全体を止めない
  );

  Logger.log('✅ プリキャッシュ完了: ${validUrls.length}枚');
}
