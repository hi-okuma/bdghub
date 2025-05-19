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
          color: AppTheme.genreChipBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
        ),
        child: Text(
          label,
          style: AppTextStyles.genreChip,
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
        color: isHost ? AppTheme.hostBadgeColor : AppTheme.tabBackgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xSmall,
        horizontal: AppSpacing.small,
      ),
      child: Text(
        isHost ? '$nickname（ホスト）' : nickname,
        style: isHost ? AppTextStyles.hostBadge : AppTextStyles.body,
      ),
    );
  }
}

// ゲームサムネイルウィジェット
class GameThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final double size;
  final double borderRadius;

  const GameThumbnail({
    Key? key,
    this.thumbnailUrl,
    this.size = AppIconSizes.gameCardThumbnail,
    this.borderRadius = AppBorderRadius.medium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppTheme.tabBackgroundColor,
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
                  Icons.broken_image,
                  size: size * 0.6,
                  color: AppTheme.secondaryTextColor,
                );
              },
            )
          : Icon(
              Icons.casino,
              size: size * 0.6,
              color: AppTheme.secondaryTextColor,
            ),
    );
  }
}

// ローディングボタンウィジェット
class LoadingButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isElevated;

  const LoadingButton({
    Key? key,
    required this.text,
    required this.isLoading,
    this.onPressed,
    this.isElevated = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button = isElevated
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: _buildChild(),
          )
        : TextButton(
            onPressed: isLoading ? null : onPressed,
            child: _buildChild(),
          );

    return button;
  }

  Widget _buildChild() {
    return isLoading
        ? const SizedBox(
            width: AppIconSizes.small,
            height: AppIconSizes.small,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(text);
  }
}

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

// カスタムタブバーウィジェット
class CustomTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;

  const CustomTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.tabBackgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.tabIndicatorColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        padding: const EdgeInsets.all(AppSpacing.xSmall),
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
            Icon(
              Icons.build_circle,
              size: AppIconSizes.xxLarge * 2,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: AppSpacing.xLarge),
            Text(
              'メンテナンス中です',
              style: AppTextStyles.titleLarge,
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
                    Text(title, style: AppTextStyles.titleSmall),
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
