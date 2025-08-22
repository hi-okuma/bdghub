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

// NGワードゲーム画面用のプレイヤー表示データ
class NgWordPlayer {
  final String uid;
  final String nickname;
  final int points;
  final String ngWord;
  final bool isCurrentUser;
  final bool isAlive;
  final bool isHost;

  NgWordPlayer({
    required this.uid,
    required this.nickname,
    required this.points,
    required this.ngWord,
    this.isCurrentUser = false,
    this.isAlive = true,
    this.isHost = false,
  });
}

class NgWordPlayingPage extends ConsumerStatefulWidget {
  const NgWordPlayingPage({super.key});

  @override
  ConsumerState<NgWordPlayingPage> createState() => _NgWordPlayingPageState();
}

class _NgWordPlayingPageState extends ConsumerState<NgWordPlayingPage>
    with GameExitHandler {
  bool _hasReported = false;
  bool _isWaitingForOthers = false;
  bool _isSubmittingReport = false; // 追加
  String? _errorMessage; // エラーメッセージ用の状態

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

  // 型安全なbool値取得関数
  bool? _extractBoolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) return value != 0;
    if (value is List && value.isNotEmpty) {
      final firstValue = value.first;
      if (firstValue is bool) return firstValue;
      if (firstValue is String) return firstValue.toLowerCase() == 'true';
      if (firstValue is int) return firstValue != 0;
    }
    return false;
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
              style: AppTextStyles.subtitle,
            ),
          ),
        ),
      );
    }

    // NOTE: playersProvider (models/user_state.dart の Player クラス) は使用しない
    // 理由: Player クラスにはUIDが含まれておらず、ゲームデータとの結合にはUIDが必要なため
    // 代わりに roomStreamProvider から直接 Firestore の構造を使ってデータを取得
    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    final gamePlayers = roomSnapshot.when(
      data: (snapshot) {
        if (!snapshot.exists) return <NgWordPlayer>[];

        final roomData = snapshot.data() as Map<String, dynamic>?;
        final roomPlayersMap =
            roomData?['players'] as Map<String, dynamic>? ?? {};
        final hostPlayer = roomData?['hostPlayer'] as String?;

        // currentGameからプレイヤー固有データを取得
        final gameData = currentGame.gameData;
        final playersGameData =
            gameData?['players'] as Map<String, dynamic>? ?? {};

        List<NgWordPlayer> players = [];

        // UIDベースでデータを結合（型安全な関数を使用）
        for (final entry in roomPlayersMap.entries) {
          final uid = entry.key;
          final roomPlayerData = entry.value as Map<String, dynamic>;
          final gamePlayerData = playersGameData[uid] as Map<String, dynamic>?;

          // 型安全なデータ取得関数を使用
          final nickname =
              _extractStringValue(roomPlayerData['nickname']) ?? '名無し';
          final points = _extractIntValue(gamePlayerData?['point']) ?? 0;
          final ngWord = _extractStringValue(gamePlayerData?['ngWord']) ?? '';
          final isAlive = _extractBoolValue(gamePlayerData?['isAlive']) ?? true;

          players.add(NgWordPlayer(
            uid: uid,
            nickname: nickname,
            points: points,
            ngWord: ngWord,
            isCurrentUser: uid == currentUser.uid,
            isAlive: isAlive,
            isHost: uid == hostPlayer,
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

        return players;
      },
      loading: () => <NgWordPlayer>[],
      error: (_, __) => <NgWordPlayer>[],
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
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
                          return _buildPlayerCard(player, gamePlayers);
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
                    child: LoadingButton(
                      text: _hasReported ? '他プレイヤー待ち' : 'NGワードを言ってしまった！',
                      isLoading: _isSubmittingReport,
                      onPressed: _hasReported ? null : _onReportPressed,
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

  void _onReportPressed() {
    setState(() {
      _hasReported = true;
      _isWaitingForOthers = true;
      _isSubmittingReport = true; // 追加
    });

    // API経由で申告情報を送信
    final currentUser = ref.read(userProvider);
    final roomId = currentUser.roomId;

    if (roomId != null && currentUser.uid != null) {
      _submitReport(roomId, currentUser.uid!);
    }
  }

  // API経由で申告情報を送信する処理
  Future<void> _submitReport(String roomId, String uid) async {
    try {
      final result = await ApiService.declare0001(roomId, uid);

      if (result['success'] == true) {
        print('✅ 申告情報を送信しました: $uid');

        setState(() {
          _hasReported = true;
          _isWaitingForOthers = true;
          _isSubmittingReport = false; // 追加
        });

        // 成功時のスナックバー表示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('申告を受け付けました'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // APIからの失敗レスポンス
        if (mounted) {
          ApiErrorHandler.handleApiError(context, result, setError);
          _resetReportState();
        }
      }
    } catch (e) {
      print('❌ 申告情報の送信に失敗: $e');

      if (mounted) {
        // http.Response型のエラーかどうかで処理を分ける
        if (e is http.Response) {
          ApiErrorHandler.handleHttpError(context, e, setError);
        } else {
          ApiErrorHandler.handleException(context, e, setError);
        }
        _resetReportState();
      }
    }
  }

  // 申告ボタンの状態をリセット
  void _resetReportState() {
    setState(() {
      _hasReported = false;
      _isWaitingForOthers = false;
      _isSubmittingReport = false; // 追加
    });
  }

  Widget _buildPlayerCard(NgWordPlayer player, List<NgWordPlayer> allPlayers) {
    // 現在のユーザーの場合は何も表示しない
    if (player.isCurrentUser) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.medium),
      padding: EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: !player.isAlive
            ? AppTheme.hintTextColor.withValues(alpha: 0.3)
            : AppTheme.cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    style: AppTextStyles.title,
                  ),
                ],
              ),
              Text(
                '${player.points}点',
                style: AppTextStyles.subtitle.copyWith(
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
        ],
      ),
    );
  }
}
