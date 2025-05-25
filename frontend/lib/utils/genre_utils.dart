import 'package:flutter/material.dart';
import '../components/custom_widgets.dart';
import '../components/app_theme.dart';

class GenreUtils {
  // ゲームデータからジャンル名のリストを取得
  static List<String> getGenreNames(Map<String, dynamic> game) {
    if (game['genreName'] is List) {
      return List<String>.from(game['genreName']);
    } else {
      String genreName = (game['genreName'] ?? 'すべて').toString();
      return [genreName];
    }
  }

  // ジャンルチップウィジェットを生成
  static Widget buildGenreChips(Map<String, dynamic> game) {
    List<String> genreNames = getGenreNames(game);
    
    if (genreNames.isEmpty) {
      genreNames = ['すべて'];
    }

    return Wrap(
      spacing: AppSpacing.xSmall,
      runSpacing: AppSpacing.xSmall,
      children: genreNames.map((name) => GenreChip(label: name)).toList(),
    );
  }
}
