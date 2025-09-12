import 'package:flutter/material.dart';

class AppTheme {
  // TODO UI適応後、不要なカラーを削除
  static const Color primaryColor = Color(0xFFE07000); // Mango Tango
  static const Color secondaryColor = Color(0xFFF5A524); // Buttercup
  // static const Color primaryColor = Color(0xFF424242); // grey[800] - 深いグレー
  static const Color accentColor = Color(0xFF616161); // grey[700] - やや薄いグレー
  static const Color disabledBackgroundColor = Color(0x1F000000);
  static const Color selectedBackgroundColor = Color(0xFFF2F4F7);
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color cardBorderColor = Color(0xFFF1F5F9);
  static const Color winnerResultCardColor = Color(0xFFFFF0B3);
  static const Color winnerResultRank1stColor = Color(0xFFFFC700);
  static const Color winnerResultRank2ndColor = Color(0xFF999999);
  static const Color winnerResultRank3rdColor = Color(0xFF927200);
  static const Color resultRankDefaultColor = Color(0xFFE6E6E6);

  // ステータスカラー - グレースケール対応
  // static const Color hostBadgeColor = Color(0xFFEEEEEE); // grey[200] - 薄いグレー
  // static const Color hostTextColor = Color(0xFF424242); // grey[800] - 深いグレー
  // static const Color genreChipBackground =
  //     Color(0xFFF5F5F5); // grey[100] - 極薄グレー
  // static const Color genreChipText = Color(0xFF616161); // grey[700] - 中間グレー
  static const Color error1Color = Color(0xFFEC0001);
  static const Color error2Color = Color(0xFFCE0000);
  static const Color errorColor = Color(0xFF757575); // grey[600] - エラーもグレー
  static const Color warningColor = Color(0xFF9E9E9E); // grey[500] - 警告もグレー
  static const Color success1Color = Color(0xFF111827);
  static const Color success2Color = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF616161); // grey[700] - 成功もグレー

  // テキストカラー - グレースケール階調
  static const Color primaryTextColor = Color(0xFF111827);
  // static const Color primaryTextColor = Color(0xFF212121); // grey[900] - 最も濃い
  static const Color secondaryTextColor = Color(0xFF6B7280);
  // static const Color secondaryTextColor = Color(0xFF757575); // grey[600] - 中間
  static const Color disabledTextColor = Color(0x61000000);
  static const Color hintTextColor = Color(0xFFBDBDBD); // grey[400] - 淡い

  // ボーダー・背景カラー - グレースケール
  static const Color borderColor1 = Color(0x3B000000);
  static const Color borderColor2 = Color(0xFFF1F5F9);
  static const Color borderColor = Color(0xFFE0E0E0); // grey[300] - 境界線
  static const Color tabBackgroundColor = Color(0xFFF5F5F5); // grey[100] - タブ背景

  // ThemeDataの作成
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansJP',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: surfaceColor,
        // background: backgroundColor,
      ),

      // AppBarテーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppTextStyles.h5FontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansJP',
        ),
      ),

      // ElevatedButtonテーマ
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabledBackgroundColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.large,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.elevatedButton),
          ),
          elevation: AppElevation.low,
        ),
      ),

      // OutlinedButtonテーマ
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.large,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.elevatedButton),
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
            vertical: AppSpacing.large,
          ),
        ),
      ),

      // Cardテーマ
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: AppElevation.veryLow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cardBorderColor),
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        margin: const EdgeInsets.all(AppSpacing.small),
      ),

      // InputDecorationテーマ
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: secondaryTextColor),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: error1Color),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: disabledBackgroundColor),
        ),
        filled: true,
        fillColor: surfaceColor,
        hintStyle: const TextStyle(color: secondaryTextColor),
      ),

      // SnackBarテーマ
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryTextColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: AppTextStyles.subtitle2FontSize,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // TabBarテーマ
      tabBarTheme: TabBarThemeData(
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: primaryTextColor,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.tabBar),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xSmall),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: AppTextStyles.title,
        actionsPadding: EdgeInsets.all(AppSpacing.medium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
        ),
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
  static const double elevatedButton = 20.0;
  static const double card = 20.0;
  static const double brandLogo = 6.0;
  static const double tabBar = 22.0;
  static const double tabSelected = 18.0;
  static const double playerBadge = 20.0;
}

// エレベーション定数
class AppElevation {
  static const double none = 0.0;
  static const double veryLow = 1.0;
  static const double low = 2.0;
  static const double medium = 4.0;
  static const double high = 8.0;
}

// テキストスタイル定数
class AppTextStyles {
  // フォントサイズ
  static const double h5FontSize = 24.0;
  static const double titleMediumFontSize = 20.0;
  static const double titleFontSize = 18.0;
  static const double subtitleFontSize = 16.0;
  static const double subtitle2FontSize = 14.0;
  static const double bodyFontSize = 14.0;
  static const double captionFontSize = 11.0;
  // static const double smallFontSize = 10.0;

  // タイトルスタイル
  static const TextStyle h5 = TextStyle(
    fontSize: h5FontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: titleMediumFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle title = TextStyle(
    fontSize: titleFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  // ボディスタイル
  static const TextStyle subtitle = TextStyle(
    fontSize: subtitleFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  // ボディスタイル
  static const TextStyle subtitle2 = TextStyle(
    fontSize: subtitle2FontSize,
    fontWeight: FontWeight.bold,
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
  static const TextStyle gameCard = TextStyle(
    fontSize: bodyFontSize,
    color: AppTheme.secondaryTextColor,
  );

  // static const TextStyle genreChip = TextStyle(
  //   fontSize: captionFontSize,
  //   color: AppTheme.genreChipText,
  // );

  // static const TextStyle hostBadge = TextStyle(
  //   fontSize: subtitle2FontSize,
  //   color: AppTheme.hostTextColor,
  // );

  static const TextStyle errorText = TextStyle(
    fontSize: subtitle2FontSize,
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
  static const double gameCardThumbnail = 112.0;
  static const double gameDetailThumbnail = 100.0;
  static const double rankIcon = 28.0;
}

// レイアウト定数
class AppLayout {
  static const double dialogWidth = 400.0;
  static const double maxContentWidth = 600.0;
  static const int maxGameDescriptionLines = 3;
  static const int maxNicknameLength = 10;
  // static const int minNicknameLength = 2;
  static const int maxProfileLength = 100;
  static const int maxProfileLines = 2;
  static const double tabHeight = 36;
  static const double tutorialImageSize = 400.0;
  static const double circleIndicatorStroke = 2;
}

// アニメーション定数
class AppAnimations {
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(milliseconds: 4000);
  static const Curve defaultCurve = Curves.easeInOut;
}
