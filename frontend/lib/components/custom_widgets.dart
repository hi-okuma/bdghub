import 'package:flutter/material.dart';
import 'app_theme.dart';

// 汎用ウィジェット集

// ジャンルチップウィジェット
class GenreChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const GenreChip({
    Key? key,
    required this.label,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: AppTheme.selectedBackgroundColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}

// プレイヤーバッジウィジェット
class PlayerBadge extends StatelessWidget {
  final String nickname;
  final bool isHost;

  const PlayerBadge({
    Key? key,
    required this.nickname,
    required this.isHost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.selectedBackgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.playerBadge),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xSmall,
        horizontal: AppSpacing.small,
      ),
      child: Text(
        isHost ? '$nickname（ホスト）' : nickname,
      ),
    );
  }
}

// ゲームサムネイルウィジェット
class GameThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final double size;
  final double iconSize;
  final double borderRadius;

  const GameThumbnail({
    Key? key,
    this.thumbnailUrl,
    required this.size,
    required this.iconSize,
    this.borderRadius = AppBorderRadius.large,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.selectedBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          ? Image.network(
              thumbnailUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.broken_image_outlined,
                  size: iconSize,
                  color: AppTheme.borderColor1,
                );
              },
            )
          : Icon(
              Icons.image_outlined,
              size: iconSize,
              color: AppTheme.borderColor1,
            ),
    );
  }
}

// 内部利用向けのベースウィジェット
// activeShadows を渡すと DecoratedBox で影を制御する（elevation: 0 前提）
class _BaseLoadingButton extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget Function(BuildContext, VoidCallback?, Widget) buttonBuilder;
  final List<BoxShadow>? activeShadows; // アクティブ時のみ表示する影

  const _BaseLoadingButton({
    required this.child,
    required this.isLoading,
    this.onPressed,
    required this.buttonBuilder,
    this.activeShadows,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = !isLoading && onPressed != null;
    final effectiveChild = isLoading
        ? const SizedBox(
            width: AppIconSizes.small,
            height: AppIconSizes.small,
            child: CircularProgressIndicator(
              strokeWidth: AppLayout.circleIndicatorStroke,
              color: AppTheme.primaryColor,
            ),
          )
        : child;

    final button =
        buttonBuilder(context, isLoading ? null : onPressed, effectiveChild);

    if (activeShadows == null) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.pill),
        boxShadow: isActive ? activeShadows : null,
      ),
      child: button,
    );
  }
}

// Figma準拠のElevatedButton（影付き）。isLoading省略で普通のボタンとして使用可。
class ElevatedLoadingButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final bool isLoading;
  final VoidCallback? onPressed;

  static const List<BoxShadow> _shadows = [
    BoxShadow(
      color: AppTheme.elevatedButtonShadowDark,
      blurRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: AppTheme.elevatedButtonShadowGlow,
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  const ElevatedLoadingButton({
    super.key,
    this.text,
    this.child,
    this.isLoading = false,
    this.onPressed,
  }) : assert(text != null || child != null, 'textかchildのどちらかは必須です');

  @override
  Widget build(BuildContext context) {
    // 非活性時はテキスト色もグレーにする（明示色を渡すと theme の
    // disabledForegroundColor が効かないため、ここで状態に応じて切り替える）
    final isDisabled = !isLoading && onPressed == null;
    return _BaseLoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      activeShadows: _shadows,
      child: child ??
          Text(
            text!,
            style: AppTextStyles.subtitle2.copyWith(
              color: isDisabled ? AppTheme.disabledTextColor : Colors.white,
            ),
          ),
      buttonBuilder: (context, onBtnPressed, btnChild) => ElevatedButton(
        onPressed: onBtnPressed,
        child: btnChild,
      ),
    );
  }
}

// Figma準拠のOutlinedButton（影付き）。isLoading省略で普通のボタンとして使用可。
class OutlinedLoadingButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final bool isLoading;
  final VoidCallback? onPressed;

  static const List<BoxShadow> _shadows = [
    BoxShadow(
      color: AppTheme.outlinedButtonShadowLight,
      blurRadius: 0,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: AppTheme.outlinedButtonShadowMedium,
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  const OutlinedLoadingButton({
    super.key,
    this.text,
    this.child,
    this.isLoading = false,
    this.onPressed,
  }) : assert(text != null || child != null);

  @override
  Widget build(BuildContext context) {
    // 非活性時はテキスト色もグレーにする（明示色を渡すと theme の
    // disabledForegroundColor が効かないため、ここで状態に応じて切り替える）
    final isDisabled = !isLoading && onPressed == null;
    return _BaseLoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      activeShadows: _shadows,
      child: child ??
          Text(
            text!,
            style: AppTextStyles.subtitle2.copyWith(
              color: isDisabled
                  ? AppTheme.disabledTextColor
                  : AppTheme.outlinedButtonBorderColor,
            ),
          ),
      buttonBuilder: (context, onBtnPressed, btnChild) => OutlinedButton(
        onPressed: onBtnPressed,
        child: btnChild,
      ),
    );
  }
}

// Textローディングボタンウィジェット
class TextLoadingButton extends StatelessWidget {
  final String? text;
  final Widget? child; // 自由なカスタマイズ用に追加
  final bool isLoading;
  final VoidCallback? onPressed;

  const TextLoadingButton({
    Key? key,
    this.text,
    this.child,
    required this.isLoading,
    this.onPressed,
  })  : assert(text != null || child != null, 'textかchildのどちらかは必須です'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseLoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      // 通常時のテキストスタイルは AppTheme.primaryColor を適用
      child: child ??
          Text(
            text!,
            style:
                AppTextStyles.subtitle2.copyWith(color: AppTheme.primaryColor),
          ),
      // TextButton として構築
      buttonBuilder: (context, onBtnPressed, btnChild) => TextButton(
        onPressed: onBtnPressed,
        child: btnChild,
      ),
    );
  }
}

// // Elevatedローディングボタンウィジェット
// class ElevatedLoadingButton extends StatelessWidget {
//   final String text;
//   final bool isLoading;
//   final VoidCallback? onPressed;
//
//   const ElevatedLoadingButton({
//     Key? key,
//     required this.text,
//     required this.isLoading,
//     this.onPressed,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       onPressed: isLoading ? null : onPressed,
//       child: _buildChild(),
//     );
//   }
//
//   Widget _buildChild() {
//     return isLoading
//         ? const SizedBox(
//             width: AppIconSizes.small,
//             height: AppIconSizes.small,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: AppTheme.primaryColor,
//             ),
//           )
//         : Text(
//             text,
//             style: AppTextStyles.subtitle2.copyWith(color: Colors.white),
//           );
//   }
// }
//
// // Outlinedローディングボタンウィジェット
// class OutlinedLoadingButton extends StatelessWidget {
//   final String text;
//   final bool isLoading;
//   final VoidCallback? onPressed;
//
//   const OutlinedLoadingButton({
//     Key? key,
//     required this.text,
//     required this.isLoading,
//     this.onPressed,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return OutlinedButton(
//       onPressed: isLoading ? null : onPressed,
//       child: _buildChild(),
//     );
//   }
//
//   Widget _buildChild() {
//     return isLoading
//         ? const SizedBox(
//             width: AppIconSizes.small,
//             height: AppIconSizes.small,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: AppTheme.primaryColor,
//             ),
//           )
//         : Text(
//             text,
//             style:
//                 AppTextStyles.subtitle2.copyWith(color: AppTheme.primaryColor),
//           );
//   }
// }
//
// // Textローディングボタンウィジェット
// class TextLoadingButton extends StatelessWidget {
//   final String text;
//   final bool isLoading;
//   final VoidCallback? onPressed;
//
//   const TextLoadingButton({
//     Key? key,
//     required this.text,
//     required this.isLoading,
//     this.onPressed,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return TextButton(
//       onPressed: isLoading ? null : onPressed,
//       child: _buildChild(),
//     );
//   }
//
//   Widget _buildChild() {
//     return isLoading
//         ? const SizedBox(
//             width: AppIconSizes.small,
//             height: AppIconSizes.small,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: AppTheme.primaryColor,
//             ),
//           )
//         : Text(
//             text,
//             style:
//                 AppTextStyles.subtitle2.copyWith(color: AppTheme.primaryColor),
//           );
//   }
// }

// エラー表示ウィジェット
class ErrorDisplay extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ErrorDisplay({
    Key? key,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: AppIconSizes.xxLarge,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            errorMessage!,
            style: AppTextStyles.errorText,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.large),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('再試行'),
            ),
          ],
        ],
      ),
    );
  }
}

// カスタムタブデータクラス
class CustomTab {
  final String label;

  const CustomTab({
    required this.label,
  });
}

// カスタムタブバーウィジェット
class CustomTabBar extends StatelessWidget {
  final TabController controller;
  final List<CustomTab> tabs;

  const CustomTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.selectedBackgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.tabBar),
      ),
      child: TabBar(
        isScrollable: true,
        controller: controller,
        // CustomTabデータからTabウィジェットを直接生成
        tabs: tabs
            .map((customTab) => Tab(
                  height: AppLayout.tabHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.small),
                    child: Container(child: Text(customTab.label)),
                  ),
                ))
            .toList(),
        padding: const EdgeInsets.all(AppSpacing.small),
      ),
    );
  }
}

// メンテナンス画面ウィジェット
class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.build_circle,
              size: AppIconSizes.xxLarge * 2,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: AppSpacing.xLarge),
            const Text(
              'メンテナンス中です',
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              message.isNotEmpty ? message : '現在、システムメンテナンスのためサービスを一時停止しております。',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// インフォメーションカードウィジェット
class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const InfoCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.medium),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.medium),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xSmall),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.medium),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String gameTitle;
  final bool isHost;
  final VoidCallback onExitPressed;

  const GameAppBar({
    Key? key,
    required this.gameTitle,
    required this.isHost,
    required this.onExitPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      title: Text(gameTitle, style: AppTextStyles.title),
      actions: [
        if (isHost)
          TextButton(
            onPressed: onExitPressed,
            // ),
            child: Row(
              children: [
                const Icon(Icons.close,
                    size: AppIconSizes.xSmall, color: AppTheme.primaryColor),
                const SizedBox(width: AppSpacing.small), // アイコンとテキストの間隔
                Text('終了する',
                    style: AppTextStyles.subtitle2.copyWith(
                      color: AppTheme.primaryColor,
                    )),
              ],
            ),
          ),
      ],
      automaticallyImplyLeading: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
