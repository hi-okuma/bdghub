import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/game_state_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/error_handler.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';

// 全ゲーム共通の結果表示用プレイヤーデータ
class ResultPlayer {
  final String uid;
  final String nickname;
  final int points;
  final bool isCurrentUser;
  final bool isHost;
  final int rank; // 順位

  ResultPlayer({
    required this.uid,
    required this.nickname,
    required this.points,
    required this.isCurrentUser,
    required this.isHost,
    required this.rank,
  });
}

class GameResultPage extends ConsumerStatefulWidget {
  const GameResultPage({super.key});

  @override
  ConsumerState<GameResultPage> createState() => _GameResultPageState();
}

class _GameResultPageState extends ConsumerState<GameResultPage>
    with GameExitHandler {
  String? _errorMessage;
  bool _isPreparationCompleted = false; // 準備完了状態
  bool _isUpdatingReady = false; // ★API呼び出し中かどうか
  bool _isLoading = true;

  // エラーメッセージを設定する関数（GameExitHandler用）
  @override
  void setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  // 型安全なString値取得関数
  String? _extractStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return value.first?.toString();
    }
    return value.toString();
  }

  // 型安全なint値取得関数
  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) {
      final firstValue = value.first;
      if (firstValue is int) return firstValue;
      if (firstValue is double) return firstValue.toInt();
      if (firstValue is String) return int.tryParse(firstValue);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // プロバイダーからデータを取得
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);

    final roomId = currentUser.roomId;

    // 部屋情報がない場合のエラーハンドリング
    if (roomId == null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Text(
              '部屋情報が見つかりません',
              style: AppTextStyles.bodyLarge,
            ),
          ),
        ),
      );
    }

    // 結果データの取得と順位計算
    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    final resultPlayers = roomSnapshot.when(
      data: (snapshot) {
        if (!snapshot.exists) return <ResultPlayer>[];

        final roomData = snapshot.data() as Map<String, dynamic>?;
        final roomPlayersMap =
            roomData?['players'] as Map<String, dynamic>? ?? {};
        final hostPlayer = roomData?['hostPlayer'] as String?;

        // currentGameからプレイヤー固有データを取得
        final gameData = currentGame.gameData;
        final playersGameData =
            gameData?['players'] as Map<String, dynamic>? ?? {};

        List<ResultPlayer> players = [];

        // UIDベースでデータを結合
        for (final entry in roomPlayersMap.entries) {
          final uid = entry.key;
          final roomPlayerData = entry.value as Map<String, dynamic>;
          final gamePlayerData = playersGameData[uid] as Map<String, dynamic>?;

          // 型安全なデータ取得
          final nickname =
              _extractStringValue(roomPlayerData['nickname']) ?? '名無し';
          final points = _extractIntValue(gamePlayerData?['point']) ?? 0;

          players.add(ResultPlayer(
            uid: uid,
            nickname: nickname,
            points: points,
            isCurrentUser: uid == currentUser.uid,
            isHost: uid == hostPlayer,
            rank: 1, // 一時的に1を設定、後で正しい順位を計算
          ));
        }

        // ポイント順でソート（高い順 → 同点の場合はホスト優先）
        players.sort((a, b) {
          if (a.points != b.points) {
            return b.points.compareTo(a.points); // ポイント降順
          }
          if (a.isHost != b.isHost) {
            return a.isHost ? -1 : 1; // ホスト優先
          }
          return 0; // その他は元の順序
        });

        // 順位を計算
        List<ResultPlayer> rankedPlayers = [];
        int currentRank = 1;
        for (int i = 0; i < players.length; i++) {
          // 前のプレイヤーと同じポイントでない場合、順位を更新
          if (i > 0 && players[i].points != players[i - 1].points) {
            currentRank = i + 1;
          }

          rankedPlayers.add(ResultPlayer(
            uid: players[i].uid,
            nickname: players[i].nickname,
            points: players[i].points,
            isCurrentUser: players[i].isCurrentUser,
            isHost: players[i].isHost,
            rank: currentRank,
          ));
        }

        return rankedPlayers;
      },
      loading: () => <ResultPlayer>[],
      error: (_, __) => <ResultPlayer>[],
    );

    // 最高ポイントの計算
    final maxPoints = resultPlayers.isNotEmpty
        ? resultPlayers.map((p) => p.points).reduce((a, b) => a > b ? a : b)
        : 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '結果発表',
            style: AppTextStyles.titleLarge,
          ),
          centerTitle: true,
          actions: [
            // ホストプレイヤーのみ終了ボタンを表示
            if (isHost)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.small),
                child: ElevatedButton(
                  onPressed: showExitGameDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.medium,
                      horizontal: AppSpacing.small,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: AppTheme.errorColor),
                      const SizedBox(width: AppSpacing.small),
                      Text(
                        '終了',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          automaticallyImplyLeading: false,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.9, 0.95, 0.98],
                    colors: [
                      Color.fromARGB(0, 255, 255, 255),
                      Color.fromARGB(50, 255, 255, 255),
                      Color.fromARGB(128, 255, 255, 255),
                      Color.fromARGB(255, 255, 255, 255),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstOut,
                child: resultPlayers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: AppSpacing.medium),
                            Text(
                              'プレイヤー情報を読み込み中...',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(AppSpacing.medium),
                        itemCount: resultPlayers.length,
                        itemBuilder: (context, index) {
                          final player = resultPlayers[index];
                          final isWinner = player.points == maxPoints;
                          return _buildPlayerResultCard(player, isWinner);
                        },
                      ),
              ),
            ),

            // もう一度遊ぶボタン（画面下部固定）
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: LoadingButton(
                        text: _isPreparationCompleted ? '他プレイヤー待ち' : 'もう一度遊ぶ',
                        isLoading: _isUpdatingReady, // ★API呼び出し中はスピナー表示
                        onPressed: _isPreparationCompleted || _isUpdatingReady
                            ? null // ★準備完了済みまたは通信中は押せない
                            : () async {
                                setState(() {
                                  _isUpdatingReady = true; // ★通信開始
                                });

                                try {
                                  await _updateReadyStatus(); // ★API呼び出し
                                  setState(() {
                                    _isPreparationCompleted =
                                        true; // ★成功時のみtrue
                                  });
                                } catch (e) {
                                  // エラー時は_isPreparationCompletedはfalseのまま
                                } finally {
                                  setState(() {
                                    _isUpdatingReady = false; // ★通信終了
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReadyStatus() async {
    final userState = ref.read(userProvider);
    final currentGame = ref.read(currentGameProvider);

    final roomId = userState.roomId;
    final nickname = userState.nickname;
    final uid = userState.uid; // ★ uidを追加で取得
    final gameId = currentGame.gameId; // ★ gameIdを取得

    if (roomId == null || nickname == null || uid == null || gameId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('準備完了の更新に失敗しました（必要な情報が不足しています）')),
      );
      return;
    }

    try {
      print('準備完了状態を更新: $nickname in room $roomId');

      // ★ API呼び出し実装
      final response = await ApiService.setReady(roomId, uid, gameId);

      print('準備完了状態の更新成功: $response');

      // 成功時のフィードバック（オプション）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('準備完了しました！')),
      );

      // 全員の準備が完了すると、Cloud Functionsにより
      // gameStatus が 'waiting' → 'playing' に自動更新され、
      // RoomGameStateNotifierが検知して自動ナビゲーション実行
    } catch (e) {
      print('準備完了状態の更新エラー: $e');

      // ★ エラー時の状態復旧
      setState(() {
        _isPreparationCompleted = false;
      });

      // エラーメッセージ表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('準備完了の更新に失敗しました: $e')),
      );
    }
  }

  Widget _buildPlayerResultCard(ResultPlayer player, bool isWinner) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.medium),
      padding: EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        // 最高ポイントプレイヤーは黄色背景
        color: isWinner
            ? Colors.amber.shade100.withValues(alpha: 0.3)
            : AppTheme.cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: isWinner ? Colors.amber.shade300 : AppTheme.borderColor,
          width: isWinner ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isWinner
                ? Colors.amber.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: AppElevation.medium,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 順位表示
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _getRankColor(player.rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${player.rank}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(width: AppSpacing.medium),

          // プレイヤー情報
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  player.nickname,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppSpacing.small),
                Text(
                  '${player.points}点',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWinner
                        ? Colors.amber.shade700
                        : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // 金
      case 2:
        return Colors.grey.shade400; // 銀
      case 3:
        return Colors.brown.shade400; // 銅
      default:
        return AppTheme.accentColor; // その他
    }
  }
}
