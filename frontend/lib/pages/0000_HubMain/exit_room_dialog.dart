import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/custom_widgets.dart';
import '/components/app_theme.dart';
import '/utils/logger.dart';
import '/services/api_service.dart';
import '/providers/user_provider.dart';
import '/providers/analytics_provider.dart';
import 'top_page.dart';

class ExitRoomDialog extends ConsumerStatefulWidget {
  const ExitRoomDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<ExitRoomDialog> createState() => _ExitRoomPageState();
}

class _ExitRoomPageState extends ConsumerState<ExitRoomDialog> with RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  bool _isLoading = false;
  final String pageTitle = '/room_exit_confirmation_dialog';

  @override
  void initState() {
    super.initState();
    // RouteObserverの取得
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面遷移の監視登録
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  Future<void> _handleLeaveRoom() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userState = ref.read(userProvider);
      if (userState.roomId == null || userState.uid == null) {
        Logger.log('🚪 退出エラー: roomId or uid is null');
        throw Exception('ルーム情報が見つかりません');
      }

      Logger.log('🚪 退出開始: ${userState.nickname} が部屋 ${userState.roomId} から退出');

      // ApiServiceを使用して退出処理
      await ApiService.leaveRoom(
        context,
        userState.roomId!,
        userState.uid!,
      );

      Logger.log('🚪 API退出成功');

      ref
          .read(analyticsServiceProvider)
          .logUserProperty(property: 'roomID', value: '');

      // 状態クリアを実行
      ref.read(userProvider.notifier).leaveRoom();

      if (!mounted) return;

      // TopPageに直接遷移（全スタッククリア）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const TopPage(),
        ),
        (route) => false, // 全ての前のルートを削除
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('部屋を退出しました')),
        );
      }
    } catch (e) {
      Logger.log('🚪 退出エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出処理に失敗しました: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.large),
        child: Text(
          '部屋から退出しますか？',
          style: AppTextStyles.body,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null // ロード中はキャンセル不可にするか、あるいは通信キャンセル処理を入れる
              : () {
                  Navigator.pop(context);
                },
          child: const Text(
            'キャンセル',
            style: TextStyle(color: AppTheme.secondaryTextColor),
          ),
        ),
        TextLoadingButton(
          text: '退出する',
          isLoading: _isLoading, // ローディング状態を反映
          onPressed: () async {
            ref
                .read(analyticsServiceProvider)
                .logClick(button: 'confirm_game_exit');
            await _handleLeaveRoom();
          },
        ),
      ],
    );
  }
}
