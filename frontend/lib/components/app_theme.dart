import 'package:flutter/material.dart';

class AppTheme {
  // カラーパレット - グレースケールに調整
  static const Color primaryColor = Color(0xFF424242); // grey[800] - 深いグレー
  static const Color accentColor = Color(0xFF616161); // grey[700] - やや薄いグレー
  static const Color backgroundColor = Color(0xFFFAFAFA); // grey[50] - 極薄グレー
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // ステータスカラー - グレースケール対応
  static const Color hostBadgeColor = Color(0xFFEEEEEE); // grey[200] - 薄いグレー
  static const Color hostTextColor = Color(0xFF424242); // grey[800] - 深いグレー
  static const Color genreChipBackground =
      Color(0xFFF5F5F5); // grey[100] - 極薄グレー
  static const Color genreChipText = Color(0xFF616161); // grey[700] - 中間グレー
  static const Color errorColor = Color(0xFF757575); // grey[600] - エラーもグレー
  static const Color warningColor = Color(0xFF9E9E9E); // grey[500] - 警告もグレー
  static const Color successColor = Color(0xFF616161); // grey[700] - 成功もグレー

  // テキストカラー - グレースケール階調
  static const Color primaryTextColor = Color(0xFF212121); // grey[900] - 最も濃い
  static const Color secondaryTextColor = Color(0xFF757575); // grey[600] - 中間
  static const Color hintTextColor = Color(0xFFBDBDBD); // grey[400] - 淡い

  // ボーダー・背景カラー - グレースケール
  static const Color borderColor = Color(0xFFE0E0E0); // grey[300] - 境界線
  static const Color tabBackgroundColor = Color(0xFFF5F5F5); // grey[100] - タブ背景
  static const Color tabIndicatorColor = Colors.white;

  // ThemeDataの作成
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansJP',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),

      // AppBarテーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppTextStyles.titleLargeFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansJP',
        ),
      ),

      // ElevatedButtonテーマ
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          elevation: AppElevation.low,
        ),
      ),

      // TextButtonテーマ
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
        ),
      ),

      // Cardテーマ
      cardTheme: CardTheme(
        color: cardColor,
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        margin: const EdgeInsets.all(AppSpacing.small),
      ),

      // InputDecorationテーマ
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: const BorderSide(color: errorColor),
        ),
        filled: true,
        fillColor: surfaceColor,
        hintStyle: const TextStyle(color: hintTextColor),
      ),

      // SnackBarテーマ
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryTextColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: AppTextStyles.bodyFontSize,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // TabBarテーマ
      tabBarTheme: TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: secondaryTextColor,
        indicator: BoxDecoration(
          color: tabIndicatorColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }
}

// スペーシング定数
class AppSpacing {
  static const double xSmall = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xLarge = 20.0;
  static const double xxLarge = 24.0;
  static const double xxxLarge = 32.0;
}

// ボーダー半径定数
class AppBorderRadius {
  static const double small = 4.0;
  static const double medium = 8.0;
  static const double large = 12.0;
  static const double xLarge = 16.0;
}

// エレベーション定数
class AppElevation {
  static const double none = 0.0;
  static const double low = 2.0;
  static const double medium = 4.0;
  static const double high = 8.0;
}

// テキストスタイル定数
class AppTextStyles {
  // フォントサイズ
  static const double titleLargeFontSize = 24.0;
  static const double titleMediumFontSize = 20.0;
  static const double titleSmallFontSize = 18.0;
  static const double bodyLargeFontSize = 16.0;
  static const double bodyFontSize = 14.0;
  static const double captionFontSize = 12.0;
  static const double smallFontSize = 10.0;

  // タイトルスタイル
  static const TextStyle titleLarge = TextStyle(
    fontSize: titleLargeFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: titleMediumFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: titleSmallFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  // ボディスタイル
  static const TextStyle bodyLarge = TextStyle(
    fontSize: bodyLargeFontSize,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle body = TextStyle(
    fontSize: bodyFontSize,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle caption = TextStyle(
    fontSize: captionFontSize,
    color: AppTheme.secondaryTextColor,
  );

  // 特殊用途スタイル
  static const TextStyle gameCardTime = TextStyle(
    fontSize: bodyFontSize,
    color: AppTheme.secondaryTextColor,
  );

  static const TextStyle genreChip = TextStyle(
    fontSize: captionFontSize,
    color: AppTheme.genreChipText,
  );

  static const TextStyle hostBadge = TextStyle(
    fontSize: bodyFontSize,
    color: AppTheme.hostTextColor,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: bodyFontSize,
    color: AppTheme.errorColor,
  );
}

// アイコンサイズ定数
class AppIconSizes {
  static const double xSmall = 16.0;
  static const double small = 20.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xLarge = 40.0;
  static const double xxLarge = 48.0;
  static const double gameCardThumbnail = 70.0;
  static const double gameDetailThumbnail = 100.0;
}

// レイアウト定数
class AppLayout {
  static const double dialogWidth = 400.0;
  static const double maxContentWidth = 600.0;
  static const int maxGameDescriptionLines = 3;
  static const int maxNicknameLength = 10;
  static const int minNicknameLength = 2;
}

// アニメーション定数
class AppAnimations {
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(milliseconds: 4000);
  static const Curve defaultCurve = Curves.easeInOut;
}
