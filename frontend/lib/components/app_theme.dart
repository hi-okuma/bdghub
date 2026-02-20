import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // TODO UI適応後、不要なカラーを削除
  static const Color primaryColor = Color(0xFFE07000); // Mango Tango
  static const Color secondaryColor = Color(0xFFF5A524); // Buttercup
  static const Color disabledBackgroundColor = Color(0x1F000000);
  static const Color selectedBackgroundColor = Color(0xFFF2F4F7);
  static const Color backgroundColor = Colors.white;
  static const Color errorBackgroundColor = Color(0xFFFDEDED);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color cardBorderColor = Color(0xFFF1F5F9);
  static const Color winnerResultCardColor = Color(0xFFFFF0B3);
  static const Color winnerResultRank1stColor = Color(0xFFFFC700);
  static const Color winnerResultRank2ndColor = Color(0xFF999999);
  static const Color winnerResultRank3rdColor = Color(0xFF927200);
  static const Color resultRankDefaultColor = Color(0xFFE6E6E6);
  static const Color error1Color = Color(0xFFEC0001);
  static const Color error2Color = Color(0xFFCE0000);
  static const Color errorColor = Color(0xFF757575); // grey[600] - エラーもグレー
  static const Color warningColor = Color(0xFF9E9E9E); // grey[500] - 警告もグレー
  static const Color success1Color = Color(0xFF239D63);
  static const Color success2Color = Color(0xFF197A4B);
  static const Color successGreyColor = Color(0xFF616161); // grey[700] - 成功もグレー
  static const Color trendWordGameBackGroundColor = Color(0xFF0F171B);
  static const Color trendWordGamePlayerCardColor = Color(0xFF15161B);
  static const Color trendWordGameWordCardColor = Color(0xFFF5F3EF);
  static const Color trendWordGameWordCardBorderColor = Color(0xFFFBE586);
  static const Color trendWordGameWordCardInnerBorderColor = Color(0xFFEAE4D9);
  static const Color trendWordGameWordCardBackFaceDivider = Color(0x3B000000);
  static const Color trendWordGamePlayerColor = Color(0xFF00D19D);
  static const Color trendWordGameOpponentColor = Color(0xFF5B8DEF);
  static const Color trendWordGameDisabledColor = Color(0xFF252A2E);

  // テキストカラー - グレースケール階調
  static const Color primaryTextColor = Color(0xFF111827);
  static const Color secondaryTextColor = Color(0xFF6B7280);
  static const Color disabledTextColor = Color(0x61000000);
  static const Color hintTextColor = Color(0xFFBDBDBD); // grey[400] - 淡い

  // ボーダー・背景カラー - グレースケール
  static const Color borderColor1 = Color(0x3B000000);
  static const Color borderColor2 = Color(0xFFF1F5F9);
  static const Color borderColor = Color(0xFFE0E0E0); // grey[300] - 境界線
  static const Color tabBackgroundColor = Color(0xFFF5F5F5); // grey[100] - タブ背景

  // ThemeDataの作成
  static ThemeData get lightTheme {
    // Google Fontsを使用してNoto Sans JPのTextThemeを取得
    final textTheme = GoogleFonts.notoSansJpTextTheme();

    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: surfaceColor,
        // background: backgroundColor,
      ),

      // AppBarテーマ
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansJp(
          fontSize: AppTextStyles.h5FontSize,
          fontWeight: FontWeight.bold,
        ),
      ),

      //Drawerテーマ
      drawerTheme: DrawerThemeData(
        backgroundColor: AppTheme.backgroundColor,
        elevation: AppElevation.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.none),
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
          side: const BorderSide(color: primaryColor),
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
          side: const BorderSide(color: cardBorderColor),
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        margin: const EdgeInsets.all(AppSpacing.small),
      ),

      // InputDecorationテーマ
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: secondaryTextColor),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: error1Color),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: disabledBackgroundColor),
        ),
        filled: true,
        fillColor: surfaceColor,
        hintStyle: TextStyle(color: secondaryTextColor),
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
        actionsPadding: const EdgeInsets.all(AppSpacing.medium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
        ),
      ),
    );
  }
}

// スペーシング定数
class AppSpacing {
  static const double xxSmall = 2.0;
  static const double xSmall = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xLarge = 20.0;
  static const double xxLarge = 24.0;
  static const double xxxLarge = 32.0;
  static const double trendWordCardInnerLine = 6.0;
}

// ボーダー半径定数
class AppBorderRadius {
  static const double none = 0.0;
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

class AppBorderStroke {
  static const double none = 0.0;
  static const double small = 1.0;
  static const double medium = 2.0;
  static const double large = 4.0;
  static const trendWordWordCardOutline = 1.42;
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
  static const double h3FontSize = 48.0;
  static const double titleMediumFontSize = 20.0;
  static const double titleFontSize = 18.0;
  static const double subtitleFontSize = 16.0;
  static const double subtitle2FontSize = 14.0;
  static const double bodyFontSize = 14.0;
  static const double captionFontSize = 11.0;
  static const double bdghubTitleFontSize = 40.0;
  static const double bdghubHeaderFontSize = 28.0;
  static const double trendWordCardFontSize = 12.0;
  // static const double smallFontSize = 10.0;

  // タイトルスタイル
  static const TextStyle h5 = TextStyle(
    fontSize: h5FontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: h3FontSize,
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

  static const TextStyle trendWordCard = TextStyle(
    fontSize: trendWordCardFontSize,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryTextColor,
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
    color: AppTheme.secondaryTextColor,
  );

  static const TextStyle bdghubTitleStyle = TextStyle(
      fontSize: bdghubTitleFontSize,
      fontWeight: FontWeight.normal,
      color: AppTheme.primaryColor,
      fontFamily: 'ZouFont');

  static const TextStyle bdghubHeaderStyle = TextStyle(
      fontSize: bdghubHeaderFontSize,
      fontWeight: FontWeight.normal,
      color: AppTheme.primaryColor,
      fontFamily: 'ZouFont');
}

// アイコンサイズ定数
class AppIconSizes {
  static const double xSmall = 16.0;
  static const double small = 20.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xLarge = 40.0;
  static const double xxLarge = 48.0;
  static const double appIcon = 220.0;
  static const double gameCardThumbnail = 112.0;
  static const double gameDetailThumbnail = 100.0;
  static const double rankIcon = 28.0;
  static const double cardCountDot = 10.0;
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
  static const double tutorialImageSize = 340.0;
  static const double circleIndicatorStroke = 2;
  static const double iconSize = 24.0;
  static const double tutorialIconSize = 36.0;
  static const double trendWordGameCardHeight = 124.0;
}

// アニメーション定数
class AppAnimations {
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(milliseconds: 4000);
  static const Curve defaultCurve = Curves.easeInOut;
}
