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
    final gameData = currentGame.gameData;
    final gameTitle = gameData?['title'] as String;

    // 部屋情報がない場合のエラーハンドリング
    if (roomId == null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Text(
              '部屋情報が見つかりません',
              style: AppTextStyles.subtitle,
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
        appBar: GameAppBar(
          gameTitle: gameTitle,
          isHost: isHost,
          onExitPressed: showExitGameDialog,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xLarge),
              child: Text('結果発表', style: AppTextStyles.h5),
            ),
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
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
                    ? const Center(
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
                        padding: const EdgeInsets.all(AppSpacing.medium),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
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
    return Card(
      margin: const EdgeInsets.only(
        bottom: AppSpacing.xLarge,
      ),
      elevation: AppElevation.low,
      color: isWinner ? AppTheme.winnerResultCardColor : AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Row(
          children: [
            // 順位表示
            Container(
              width: AppIconSizes.rankIcon,
              height: AppIconSizes.rankIcon,
              decoration: BoxDecoration(
                color: _getRankColor(player.rank),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${player.rank}',
                  style: player.rank < 4
                      ? AppTextStyles.subtitle.copyWith(color: Colors.white)
                      : AppTextStyles.subtitle
                          .copyWith(color: AppTheme.secondaryTextColor),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            // プレイヤー情報
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(player.nickname,
                      style: AppTextStyles.subtitle2
                          .copyWith(color: AppTheme.secondaryTextColor)),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '${player.points}点',
                    style: AppTextStyles.subtitle2
                        .copyWith(color: AppTheme.secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppTheme.winnerResultRank1stColor; // 金
      case 2:
        return AppTheme.winnerResultRank2ndColor; // 銀
      case 3:
        return AppTheme.winnerResultRank3rdColor; // 銅
      default:
        return AppTheme.resultRankDefaultColor; // その他
    }
  }
}
