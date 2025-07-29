import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/models/user_state.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';

// プレイヤーのデータモデル（NGワードゲーム用）
class NgWordPlayer {
  final String nickname;
  final int points;
  final String ngWord;
  final bool isCurrentUser;
  final bool hasReported;
  final bool isHost;

  NgWordPlayer({
    required this.nickname,
    required this.points,
    required this.ngWord,
    this.isCurrentUser = false,
    this.hasReported = false,
    this.isHost = false,
  });
}

class NgWordPlayingPage extends ConsumerStatefulWidget {
  const NgWordPlayingPage({super.key});

  @override
  ConsumerState<NgWordPlayingPage> createState() => _NgWordPlayingPageState();
}

class _NgWordPlayingPageState extends ConsumerState<NgWordPlayingPage> {
  bool _hasReported = false;
  bool _isWaitingForOthers = false;

  @override
  Widget build(BuildContext context) {
    // プロバイダーからデータを取得
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);

    final roomId = currentUser.roomId;

    // 部屋情報がない場合のエラーハンドリング
    if (roomId == null) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Text(
              '部屋情報が見つかりません',
              style: AppTextStyles.bodyLarge,
            ),
          ),
        ),
      );
    }

    // 部屋のプレイヤー情報を取得
    final roomPlayers = ref.watch(playersProvider(roomId));

    // NGワードゲーム用のプレイヤーデータを構築
    final gamePlayers = _buildGamePlayers(
      roomPlayers,
      currentGame,
      currentUser.nickname,
    );

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            // ホストプレイヤーのみ終了ボタンを表示
            if (isHost)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.small),
                child: ElevatedButton(
                  onPressed: _onExitGame,
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
                child: gamePlayers.isEmpty
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
                        padding: EdgeInsets.only(
                          left: AppSpacing.medium,
                          right: AppSpacing.medium,
                          top: AppSpacing.medium,
                          bottom: AppSpacing.xxxLarge,
                        ),
                        itemCount: gamePlayers.length,
                        itemBuilder: (context, index) {
                          final player = gamePlayers[index];
                          return _buildPlayerCard(player);
                        },
                      ),
              ),
            ),

            // 申告ボタン（画面下部固定）
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasReported ? null : _onReportPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasReported
                            ? AppTheme.hintTextColor
                            : AppTheme.errorColor,
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.large),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.medium),
                        ),
                      ),
                      child: Text(
                        _isWaitingForOthers ? '他プレイヤー待ち' : 'NGワードを言ってしまった！',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  // プロバイダーのデータからNGワードゲーム用のプレイヤーリストを構築
  List<NgWordPlayer> _buildGamePlayers(
    List<Player> roomPlayers,
    CurrentGameState currentGame,
    String? currentUserNickname,
  ) {
    // ゲームデータからプレイヤー固有の情報を取得
    final gameData = currentGame.gameData;
    final playersGameData = gameData?['players'] as Map<String, dynamic>?;
    final ngWords = gameData?['ngWords'] as Map<String, dynamic>?;
    final points = gameData?['points'] as Map<String, dynamic>?;
    final reportedPlayers = gameData?['reportedPlayers'] as List<dynamic>?;

    // room_provider.dartのPlayerから、NGワードゲーム用のNgWordPlayerに変換
    List<NgWordPlayer> gamePlayers = roomPlayers.map((roomPlayer) {
      // プレイヤー固有のゲームデータを取得
      final playerData =
          playersGameData?[roomPlayer.nickname] as Map<String, dynamic>?;

      return NgWordPlayer(
        nickname: roomPlayer.nickname,
        // ゲームデータからポイントを取得、なければデフォルト値0
        points: playerData?['points'] ?? points?[roomPlayer.nickname] ?? 0,
        // ゲームデータからNGワードを取得、なければデフォルト値空文字
        ngWord: playerData?['ngWord'] ?? ngWords?[roomPlayer.nickname] ?? '',
        // 現在のユーザーかどうかを判定
        isCurrentUser: roomPlayer.nickname == currentUserNickname,
        // 申告済みかどうかを判定
        hasReported: reportedPlayers?.contains(roomPlayer.nickname) ??
            playerData?['hasReported'] ??
            false,
        // ホストかどうか
        isHost: roomPlayer.isHost,
      );
    }).toList();

    // ポイント順でソート（高い順 → 同点の場合は元の順序）
    gamePlayers.sort((a, b) {
      if (a.points != b.points) {
        return b.points.compareTo(a.points); // ポイント降順
      }
      // 同点の場合は元の順序を維持（ホストが先頭になるように）
      return roomPlayers
          .indexWhere((p) => p.nickname == a.nickname)
          .compareTo(roomPlayers.indexWhere((p) => p.nickname == b.nickname));
    });

    return gamePlayers;
  }

  void _onReportPressed() {
    setState(() {
      _hasReported = true;
      _isWaitingForOthers = true;
    });

    // TODO: 実際の実装では、Firestoreに申告情報を送信
    // 例: ゲーム状態プロバイダーを通じて申告処理を行う

    // 一時的な処理（実際は他プレイヤーの状態変化を監視）
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        // TODO: 結果画面への遷移処理
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultScreen()));
      }
    });
  }

  void _onExitGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ゲーム終了'),
        content: Text('ゲームを終了しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: ゲーム終了処理をプロバイダー経由で実行
              // ゲーム選択画面に戻る
              Navigator.of(context).pop();
            },
            child: Text('終了'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(NgWordPlayer player) {
    // 最高ポイントかどうかを判定
    final gamePlayers = _buildGamePlayers(
      ref.read(playersProvider(ref.read(userProvider).roomId!)),
      ref.read(currentGameProvider),
      ref.read(userProvider).nickname,
    );
    final maxPoints = gamePlayers.isNotEmpty ? gamePlayers.first.points : 0;
    final isTopPlayer = player.points == maxPoints && maxPoints > 0;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.medium),
      padding: EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: player.hasReported
            ? AppTheme.hintTextColor.withOpacity(0.3)
            : (isTopPlayer
                ? Colors.yellow.withOpacity(0.3)
                : AppTheme.cardColor),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: AppElevation.low,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // プレイヤー名とポイント
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    player.nickname,
                    style: AppTextStyles.titleSmall,
                  ),
                  if (player.isHost) ...[
                    SizedBox(width: AppSpacing.small),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.small,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.small),
                      ),
                      child: Text(
                        'ホスト',
                        style: AppTextStyles.caption.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (player.isCurrentUser) ...[
                    SizedBox(width: AppSpacing.small),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.small,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.small),
                      ),
                      child: Text(
                        '自分',
                        style: AppTextStyles.caption.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${player.points}点',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.small),

          // NGワード表示
          RichText(
            text: TextSpan(
              style: AppTextStyles.body,
              children: [
                TextSpan(
                  text: 'NGワード：',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                TextSpan(
                  text: player.ngWord.isEmpty ? '読み込み中...' : player.ngWord,
                  style: TextStyle(
                    color: player.ngWord.isEmpty
                        ? AppTheme.hintTextColor
                        : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 申告済み表示
          if (player.hasReported) ...[
            SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 16,
                  color: AppTheme.warningColor,
                ),
                SizedBox(width: AppSpacing.small),
                Text(
                  '申告済み',
                  style: AppTextStyles.caption.copyWith(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
