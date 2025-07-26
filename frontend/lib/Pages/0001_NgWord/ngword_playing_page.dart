import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/models/user_state.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/error_handler.dart';

// NGワードゲーム画面用のプレイヤー表示データ
class NgWordPlayer {
  final String uid;
  final String nickname;
  final int points;
  final String ngWord;
  final bool isCurrentUser;
  final bool hasReported;
  final bool isHost;

  NgWordPlayer({
    required this.uid,
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
  String? _errorMessage; // エラーメッセージ用の状態

  // エラーメッセージを設定する関数（ApiErrorHandler用）
  void _setError(String message) {
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
      return Scaffold(
        body: Center(
          child: Text(
            '部屋情報が見つかりません',
            style: AppTextStyles.bodyLarge,
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
          final points = _extractIntValue(gamePlayerData?['points']) ?? 0;
          final ngWord = _extractStringValue(gamePlayerData?['ngWord']) ?? '';
          final hasReported =
              _extractBoolValue(gamePlayerData?['hasReported']) ?? false;

          players.add(NgWordPlayer(
            uid: uid,
            nickname: nickname,
            points: points,
            ngWord: ngWord,
            isCurrentUser: uid == currentUser.uid,
            hasReported: hasReported,
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

    return Scaffold(
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
                  child: ElevatedButton(
                    onPressed: _hasReported ? null : _onReportPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasReported
                          ? AppTheme.hintTextColor
                          : AppTheme.errorColor,
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.large),
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
    );
  }

  void _onReportPressed() {
    setState(() {
      _hasReported = true;
      _isWaitingForOthers = true;
    });

    // API経由で申告情報を送信
    final currentUser = ref.read(userProvider);
    final roomId = currentUser.roomId;

    if (roomId != null && currentUser.uid != null) {
      _submitReport(roomId, currentUser.uid!);
    }

    // 一時的な処理（実際は他プレイヤーの状態変化を監視）
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        // TODO: 結果画面への遷移処理
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultScreen()));
      }
    });
  }

  // API経由で申告情報を送信する処理
  Future<void> _submitReport(String roomId, String uid) async {
    try {
      final result = await ApiService.declare0001(roomId, uid);

      if (result['success'] == true) {
        print('✅ 申告情報を送信しました: $uid');

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
          ApiErrorHandler.handleApiError(context, result, _setError);
          _resetReportState();
        }
      }
    } catch (e) {
      print('❌ 申告情報の送信に失敗: $e');

      if (mounted) {
        // http.Response型のエラーかどうかで処理を分ける
        if (e is http.Response) {
          ApiErrorHandler.handleHttpError(context, e, _setError);
        } else {
          ApiErrorHandler.handleException(context, e, _setError);
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
            onPressed: () async {
              Navigator.of(context).pop(); // ダイアログを閉じる

              // API経由でゲーム終了処理
              final currentUser = ref.read(userProvider);
              final roomId = currentUser.roomId;

              if (roomId != null) {
                await _endGameProcess(roomId);
              }
            },
            child: Text('終了'),
          ),
        ],
      ),
    );
  }

  // API経由でゲーム終了処理
  Future<void> _endGameProcess(String roomId) async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.medium),
                  Text(
                    'ゲームを終了しています...',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await ApiService.endGame(roomId);

      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる
      }

      if (result['success'] == true) {
        print('✅ ゲーム終了処理が完了しました');

        // 成功時：ゲーム選択画面に戻る
        if (mounted) {
          Navigator.of(context).pop(); // ゲーム画面を閉じる

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ゲームを終了しました'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // APIからの失敗レスポンス
        if (mounted) {
          ApiErrorHandler.handleApiError(context, result, _setError);
        }
      }
    } catch (e) {
      print('❌ ゲーム終了処理に失敗: $e');

      if (mounted) {
        Navigator.of(context).pop(); // ローディングダイアログを閉じる（エラー時）

        // http.Response型のエラーかどうかで処理を分ける
        if (e is http.Response) {
          ApiErrorHandler.handleHttpError(context, e, _setError);
        } else {
          ApiErrorHandler.handleException(context, e, _setError);
        }
      }
    }
  }

  Widget _buildPlayerCard(NgWordPlayer player, List<NgWordPlayer> allPlayers) {
    // 現在のユーザーの場合は何も表示しない
    if (player.isCurrentUser) {
      return SizedBox.shrink();
    }

    // 最高ポイントかどうかを判定
    final maxPoints = allPlayers.isNotEmpty ? allPlayers.first.points : 0;
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
