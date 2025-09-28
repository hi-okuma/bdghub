// frontend/lib/pages/app_initialization_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bodogehub/models/game_enums.dart';
import '/components/app_theme.dart';
import '/providers/user_provider.dart';
import '/providers/game_provider.dart';
import '/providers/game_state_provider.dart';
import '/services/auth_service.dart';
import '/services/navigation_service.dart';
import '/Pages/0000_HubMain/select_game_page.dart';
import '/Pages/0000_HubMain/top_page.dart';

class AppInitializationPage extends ConsumerStatefulWidget {
  final String? urlRoomId;

  const AppInitializationPage({super.key, this.urlRoomId});

  @override
  ConsumerState<AppInitializationPage> createState() =>
      _AppInitializationPageState();
}

class _AppInitializationPageState extends ConsumerState<AppInitializationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      await AuthService.ensureAuthenticated();

      if (widget.urlRoomId != null && widget.urlRoomId!.isNotEmpty) {
        _navigateToJoinRoom(widget.urlRoomId!);
        return;
      }

      final restoreSuccess =
          await ref.read(userProvider.notifier).tryRestoreFromStorage();

      if (restoreSuccess) {
        await _handleDetailedGameStateRestore();
      } else {
        _navigateToTop();
      }
    } catch (e) {
      print('❌ アプリ初期化エラー: $e');
      _showErrorAndNavigateToTop('アプリの初期化に失敗しました');
    }
  }

  Future<void> _handleDetailedGameStateRestore() async {
    try {
      final userState = ref.read(userProvider);
      final roomId = userState.roomId;
      final savedGamePhase = userState.gamePhase ?? GamePhase.initial;

      if (roomId == null) {
        _navigateToTop();
        return;
      }

      print('🔍 詳細ゲーム状態復帰開始: $roomId (savedGamePhase: $savedGamePhase)');

      // 部屋の基本状態確認
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        _showErrorAndNavigateToTop('部屋が見つかりませんでした');
        return;
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final roomStatus = roomData['status'] as String?;

      if (roomStatus != 'inProgress') {
        _navigateToSelectGame();
        return;
      }

      // currentGameから詳細状態取得
      final currentGameQuery = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('currentGame')
          .get();

      if (currentGameQuery.docs.isEmpty) {
        _navigateToSelectGame();
        return;
      }

      final gameDoc = currentGameQuery.docs.first;
      final gameId = gameDoc.id;
      final gameData = gameDoc.data();
      final gameStatus = _parseGameStatus(gameData['gameStatus']);

      print(
          '🔍 Game ID: $gameId, Game Status: $gameStatus, Saved Phase: $savedGamePhase');

      // currentGameProviderにデータ読み込み
      await ref
          .read(currentGameProvider.notifier)
          .loadFromCurrentGame(roomId, gameId);

      if (!mounted) return;

      // 保存されたgamePhaseを使用して正確な画面に遷移
      final navigationService = ref.read(navigationServiceProvider);

      if (gameStatus == GameStatus.waiting) {
        if (savedGamePhase == GamePhase.ended) {
          print('🔍 ゲーム終了後のwaiting → 結果画面に遷移');
          navigationService.navigateToResult(gameData);
        } else {
          print('🔍 ゲーム開始前のwaiting → ゲームタイトルに遷移');
          navigationService.navigateToGameTitle();
        }
      } else {
        print('🔍 ゲーム進行中 → 適切な画面に遷移');
        navigationService.navigateToGameScreenByStatus(gameStatus, gameData,
            isRestore: true);
      }

      // 遷移後に状態監視を開始
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔍 復帰後にゲーム状態監視を開始: $roomId');
        ref.read(roomGameStateProvider(roomId));
      });
    } catch (e) {
      print('❌ 詳細ゲーム状態復帰エラー: $e');
      _showErrorAndNavigateToTop('ゲーム状態の復帰に失敗しました');
    }
  }

  GameStatus _parseGameStatus(dynamic status) {
    switch (status?.toString()) {
      case 'playing':
        return GameStatus.playing;
      case 'childTurn':
        return GameStatus.childTurn;
      case 'parentTurn':
        return GameStatus.parentTurn;
      case 'result':
        return GameStatus.result;
      default:
        return GameStatus.waiting;
    }
  }

  void _navigateToJoinRoom(String roomId) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => TopPage(roomId: roomId)),
    );
  }

  void _navigateToSelectGame() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SelectGamePage()),
    );
  }

  void _navigateToTop() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TopPage()),
    );
  }

  void _showErrorAndNavigateToTop(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('復帰エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToTop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppBorderRadius.brandLogo),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Icon(
                  Icons.videogame_asset_outlined,
                  color: Colors.white,
                  size: AppIconSizes.xxLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxLarge),
            const Text(
              'ボードゲームハブ',
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: AppSpacing.xxLarge),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.large),
          ],
        ),
      ),
    );
  }
}
