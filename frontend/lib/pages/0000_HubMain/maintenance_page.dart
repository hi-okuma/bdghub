import 'package:flutter/material.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/components/app_theme.dart';

/// メンテナンス中に表示する専用ページ
/// Firebase認証前に表示されるため、認証に依存しない実装
class MaintenancePage extends StatelessWidget {
  final String message;

  const MaintenancePage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: MaintenanceScreen(message: message),
    );
  }
}
