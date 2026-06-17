import 'dart:async';
import 'dart:math';

import 'package:bodogehub/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';
import 'package:google_fonts/google_fonts.dart';

/// サンタ苦労スのダイアログ種別
enum _ResultType { success, failure }

/// サンタ苦労スゲーム画面
class SantaKurousuPlayingPage extends ConsumerStatefulWidget {
  const SantaKurousuPlayingPage({super.key});

  @override
  ConsumerState<SantaKurousuPlayingPage> createState() =>
      _SantaKurousuPlayingPageState();
}

class _SantaKurousuPlayingPageState
    extends ConsumerState<SantaKurousuPlayingPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  bool _isLoading = false;

  // タイマー関連
  Timer? _timer;
  int _remainingSeconds = 120; // 2:00 = 120秒
  DateTime? _currentEndsAt;

  // --- GameExitHandler 必須オーバーライド ---
  @override
  final String pageTitle = '/0007/santa_kurousu_playing_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void setError(String message) {
    if (mounted) {
      Logger.log('SantaKurousuPlayingPageでエラー発生: $message');
    }
  }

  // --- RouteAware ライフサイクル ---
  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;

    // 初回マウント時にendsAtを確認してタイマーを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTimerWithFirestore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  // --- 型安全な値抽出ヘルパー ---
  String? _extractStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value.first?.toString();
    return value.toString();
  }

  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) {
      final v = value.first;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  bool? _extractBoolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    if (value is List && value.isNotEmpty) {
      final v = value.first;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is int) return v != 0;
    }
    return false;
  }

  // --- タイマー管理 ---

  /// FirestoreのendsAtに合わせてタイマーを同期する
  void _syncTimerWithFirestore() {
    final gameData = ref.read(currentGameProvider).gameData;
    if (gameData == null) return;

    final endsAtRaw = gameData['endsAt'];
    final endsAt = endsAtRaw is Timestamp ? endsAtRaw.toDate() : null;

    _applyEndsAt(endsAt);
  }

  /// endsAt（DateTime or null）をもとにタイマー状態を更新する
  void _applyEndsAt(DateTime? endsAt) {
    if (endsAt == null) {
      // タイマー未開始: 2:00を表示してタイマー停止
      _timer?.cancel();
      _timer = null;
      _currentEndsAt = null;
      if (mounted) {
        setState(() {
          _remainingSeconds = 120;
        });
      }
    } else {
      // 同一のendsAtなら何もしない（Firestoreのリアルタイム更新で重複発火を防ぐ）
      if (_currentEndsAt == endsAt) return;

      _timer?.cancel();
      _currentEndsAt = endsAt;

      // 即座に残り秒数を計算して表示
      final remaining = endsAt.difference(DateTime.now()).inSeconds;
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining.clamp(0, 120);
        });
      }

      if (remaining > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) {
            _timer?.cancel();
            return;
          }
          final secs = endsAt.difference(DateTime.now()).inSeconds;
          if (secs <= 0) {
            setState(() {
              _remainingSeconds = 0;
            });
            _timer?.cancel();
            _timer = null;
          } else {
            setState(() {
              _remainingSeconds = secs;
            });
          }
        });
      }
    }
  }

  // --- API呼び出し ---

  Future<void> _onStartTimer(String roomId, String uid) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      ref.read(analyticsServiceProvider).logClick(button: '0007_start_timer');
      await ApiService.startTimer0007(context, roomId, uid);
      Logger.log('startTimer0007を送信しました');
    } catch (e) {
      Logger.log('startTimer0007の送信に失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ダイアログ表示 ---

  void _showResultDialog(
    BuildContext context,
    _ResultType resultType,
    String roomId,
    String uid,
    List<_SantaPlayer> players,
    String? currentPresenterUid,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: 40.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: _ResultDialogContent(
            resultType: resultType,
            roomId: roomId,
            uid: uid,
            players: players,
            currentPresenterUid: currentPresenterUid,
          ),
        ),
      ),
    );
  }

  // タイマー文字列フォーマット
  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);

    // --- FirestoreのendsAtリアルタイム変化を監視してタイマーを同期 ---
    ref.listen(currentGameProvider, (_, next) {
      final gameData = next.gameData;
      if (gameData == null) return;

      final endsAtRaw = gameData['endsAt'];
      final endsAt = endsAtRaw is Timestamp ? endsAtRaw.toDate() : null;
      _applyEndsAt(endsAt);
    });

    // --- ガード: gameData null check ---
    if (currentGame.gameData == null || currentGame.gameData!.isEmpty) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppTheme.santaKurousuBgTop,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final gameData = currentGame.gameData!;
    final gameTitle = gameData['title'] as String? ?? 'サンタ苦労ス';
    final roomId = currentUser.roomId;

    // --- ガード: roomId null check ---
    if (roomId == null) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Text('部屋情報が見つかりません', style: AppTextStyles.subtitle),
          ),
        ),
      );
    }

    // --- ゲームデータ取得 ---
    final currentPresenterUid =
        _extractStringValue(gameData['currentPresenter']);
    final currentTopic = _extractStringValue(gameData['currentTopic']) ?? '';
    final currentRoleCardUrl =
        _extractStringValue(gameData['currentRoleCard']) ?? '';
    final endsAtRaw = gameData['endsAt'];
    final endsAt = endsAtRaw is Timestamp ? endsAtRaw.toDate() : null;

    // おじさん判定
    final uid = currentUser.uid;
    final isPresenter =
        currentPresenterUid != null && currentPresenterUid == uid;

    // タイマー開始済み判定
    final isTimerStarted = endsAt != null;

    // 残り時間の警告判定
    final isWarning = isTimerStarted && _remainingSeconds <= 15;
    final timerColor =
        isWarning ? AppTheme.primaryColor : AppTheme.santaKurousuNavyBadge;

    // --- プレイヤーデータ取得 ---
    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    final players = roomSnapshot.when(
      data: (snapshot) {
        if (!snapshot.exists) return <_SantaPlayer>[];
        final roomData = snapshot.data() as Map<String, dynamic>?;
        final roomPlayersMap =
            roomData?['players'] as Map<String, dynamic>? ?? {};
        final playersGameData =
            gameData['players'] as Map<String, dynamic>? ?? {};

        return roomPlayersMap.entries.map((entry) {
          final pUid = entry.key;
          final roomPlayerData = entry.value as Map<String, dynamic>;
          final gamePlayerData = playersGameData[pUid] as Map<String, dynamic>?;

          final nickname =
              _extractStringValue(roomPlayerData['nickname']) ?? '名無し';
          final point = _extractIntValue(gamePlayerData?['point']) ?? 0;
          final isEverPresenter =
              _extractBoolValue(gamePlayerData?['isEverPresenter']) ?? false;

          return _SantaPlayer(
            uid: pUid,
            nickname: nickname,
            point: point,
            isEverPresenter: isEverPresenter,
            isCurrentUser: pUid == uid,
            isPresenter: pUid == currentPresenterUid,
          );
        }).toList();
      },
      loading: () => <_SantaPlayer>[],
      error: (_, __) => <_SantaPlayer>[],
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
          gameTitle: gameTitle,
          isHost: isHost,
          onExitPressed: () {
            ref.read(analyticsServiceProvider).logClick(button: 'game_quit');
            showExitGameDialog();
          },
        ),
        // 背景グラデーション
        // Containerに明示的に画面いっぱいの制約を与え、
        // 子要素が小さくても背景グラデーションがScaffold全域を覆うようにする
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.santaKurousuBgTop,
                AppTheme.santaKurousuTopicArea
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large,
                vertical: AppSpacing.medium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 役割バッジ + タイマー エリア
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 役割バッジ（濃紺pill）
                      Expanded(
                        child: _RoleBadge(isPresenter: isPresenter),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      // タイマー
                      _TimerCompact(
                        timeText: _formatTime(_remainingSeconds),
                        timerColor: timerColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),

                  // 白カード: お約束 + おじさんカード画像
                  _MainCard(
                    isPresenter: isPresenter,
                    roleCardUrl: currentRoleCardUrl,
                  ),
                  const SizedBox(height: AppSpacing.medium),

                  // おじさん専用UI
                  // カードめくり演出: 濃紺の「お題をめくってスタート」カード（表面）を
                  // タップした瞬間に rotateY でめくれ始める（startTimer0007 のレスポンスは待たない）。
                  // めくり切るまで裏面は見えず、めくり完了時に Firestore の endsAt/お題が
                  // まだ反映されていなければ裏面でローディングを表示し、反映後にお題＋結果報告
                  // ボタンへ差し替わる。
                  if (isPresenter) ...[
                    _FlipStartCard(
                      isFlipped: isTimerStarted,
                      onTap: () {
                        if (uid != null) _onStartTimer(roomId, uid);
                      },
                      front: const _StartCardFront(),
                      back: _TopicResultCard(
                        topic: currentTopic,
                        onSantaCorrect: () {
                          ref
                              .read(analyticsServiceProvider)
                              .logClick(button: '0007_santa_correct');
                          _showResultDialog(
                            context,
                            _ResultType.success,
                            roomId,
                            uid ?? '',
                            players,
                            currentPresenterUid,
                          );
                        },
                        onSkip: () {
                          ref
                              .read(analyticsServiceProvider)
                              .logClick(button: '0007_skip');
                          _showResultDialog(
                            context,
                            _ResultType.failure,
                            roomId,
                            uid ?? '',
                            players,
                            currentPresenterUid,
                          );
                        },
                      ),
                      backLoading: const _TopicResultCardLoading(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- プレイヤーデータクラス ---

class _SantaPlayer {
  final String uid;
  final String nickname;
  final int point;
  final bool isEverPresenter;
  final bool isCurrentUser;
  final bool isPresenter;

  const _SantaPlayer({
    required this.uid,
    required this.nickname,
    required this.point,
    required this.isEverPresenter,
    required this.isCurrentUser,
    required this.isPresenter,
  });
}

// --- 役割バッジ（Figma: 濃紺 pill #1f4a6a） ---

class _RoleBadge extends StatelessWidget {
  final bool isPresenter;

  const _RoleBadge({required this.isPresenter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xLarge,
        vertical: AppSpacing.medium,
      ),
      decoration: BoxDecoration(
        color: AppTheme.santaKurousuNavyBadge,
        borderRadius: BorderRadius.circular(AppBorderRadius.elevatedButton),
      ),
      child: Text(
        isPresenter ? 'あなたは おじさん（出題者）です' : 'あなたは サンタ（回答者）です',
        style: const TextStyle(
          fontSize: AppTextStyles.labelFontSize,
          color: Colors.white,
          fontWeight: FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

// --- コンパクトタイマー（Figma: 右側配置、のこりじかんラベル + 時計アイコン + 数字） ---

class _TimerCompact extends StatelessWidget {
  final String timeText;
  final Color timerColor;

  const _TimerCompact({
    required this.timeText,
    required this.timerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 「のこりじかん」ラベル
        const Text(
          'のこりじかん',
          style: TextStyle(
            fontSize: AppTextStyles.captionFontSize,
            fontWeight: FontWeight.w500,
            color: AppTheme.santaKurousuNavyBadge,
          ),
        ),
        // const SizedBox(height: AppSpacing.xxSmall),
        // crossAxisAlignment.center + Text.style.height=1.0 で
        // Iconと数字のbounding box中心が一致し、見た目の縦位置が揃う
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Baseline(
              baseline: 20.0,
              baselineType: TextBaseline.alphabetic,
              child: Icon(
                Icons.alarm,
                size: AppTextStyles.h5FontSize,
                color: timerColor,
              ),
            ),
            const SizedBox(width: AppSpacing.xSmall),
            Baseline(
              baseline: 22.0,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                timeText,
                style: TextStyle(
                  fontSize: AppTextStyles.santakurousuTimerFontSize,
                  fontFamily: GoogleFonts.nunito().fontFamily,
                  fontWeight: FontWeight.bold,
                  color: timerColor,
                  // height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- メインカード（Figma: 白カード #fffcf4、角丸20px） ---
// お約束pillオレンジ + お約束テキスト + おじさんカード画像をまとめる

// Figma基準のおじさんカード画像サイズ（縦横比維持＋上限値として使用）
const double _roleCardMaxWidth = 227.0;
const double _roleCardAspectRatio = 227.0 / 319.0;

class _MainCard extends StatelessWidget {
  final bool isPresenter;
  final String roleCardUrl;

  const _MainCard({
    required this.isPresenter,
    required this.roleCardUrl,
  });

  @override
  Widget build(BuildContext context) {
    final rules = isPresenter
        ? [
            '名詞は「アレ」としか言えません',
            '擬音やジェスチャーは使ってOK',
          ]
        : [
            'サンタは質問禁止',
            'ちょっとしたおじさんのミスは笑って許そう',
          ];

    return Container(
      decoration: ShapeDecoration(
        color: AppTheme.santaKurousuCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        shadows: const [
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowLight,
            blurRadius: 0,
            offset: Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowMedium,
            blurRadius: 24,
            offset: Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // オレンジpill: 「お約束 と 今回のおじさん」
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.santaKurousuOrangePill,
                  borderRadius:
                      BorderRadius.circular(AppBorderRadius.elevatedButton),
                ),
                child: const Text(
                  'お約束 と 今回のおじさん',
                  style: TextStyle(
                    fontSize: AppTextStyles.captionFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.santaKurousuNavyBadge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),

            // お約束テキスト
            ...rules.map(
              (rule) => Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xSmall),
                  child: Text(
                    '･$rule',
                    style: const TextStyle(
                      fontSize: AppTextStyles.santaKurousuRulesFrontSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.santaKurousuNavyBadge,
                      letterSpacing: -0.05,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),

            // おじさんカード画像（Figma: 227x319px、角丸20px、border #15324a）
            // ConstrainedBox+AspectRatioでFigma基準227x319を上限としつつ、
            // 親が狭ければ縦横比を保ったまま縮小される（小型端末対応）
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _roleCardMaxWidth),
                child: AspectRatio(
                  aspectRatio: _roleCardAspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.card),
                      border: Border.all(
                        color: AppTheme.santaKurousuNavyDark,
                        width: AppBorderStroke.small,
                      ),
                      color: AppTheme.selectedBackgroundColor,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: roleCardUrl.isNotEmpty
                        ? Image.network(
                            roleCardUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: AppTheme.secondaryTextColor,
                                size: AppIconSizes.xLarge,
                              ),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: AppTheme.secondaryTextColor,
                              size: AppIconSizes.xLarge,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- カードめくりスタートカード ---
// 表面（濃紺「お題をめくってスタート！」）をタップした瞬間に rotateY でめくれ始める。
// startTimer0007 のレスポンス（Firestore の endsAt 反映 = isFlipped）は待たず、
// アニメーションを最後まで再生してから裏面を表示する。めくり完了時点で endsAt/お題が
// まだ反映されていなければ backLoading（裏面ローディング）を表示し、反映後に back
// （お題＋結果報告ボタン）へ差し替える。trend_word_blackjack の
// _CardSelectionDialogContent と同じ Matrix4.rotateY によるフリップ演出。
class _FlipStartCard extends StatefulWidget {
  // API レスポンスが Firestore に反映済み（endsAt 有り = 裏面データ準備完了）かどうか。
  // false の間はめくり完了後も裏面で backLoading を表示する。
  final bool isFlipped;

  // 表面タップ時のコールバック（startTimer0007 を実行）。
  final VoidCallback onTap;

  final Widget front;
  final Widget back;

  // 裏面データ未準備（API レスポンス待ち）時に表示するローディング裏面。
  final Widget backLoading;

  const _FlipStartCard({
    required this.isFlipped,
    required this.onTap,
    required this.front,
    required this.back,
    required this.backLoading,
  });

  @override
  State<_FlipStartCard> createState() => _FlipStartCardState();
}

class _FlipStartCardState extends State<_FlipStartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  // めくりを開始したか。タップ即フリップ開始するためのフラグ兼二重タップガード。
  bool _flipTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // 復帰時（リロードで既にタイマー開始済み）はアニメーションなしでめくれた状態にする。
    if (widget.isFlipped) {
      _flipTriggered = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _FlipStartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlipped && !widget.isFlipped) {
      // 次ラウンドなどでリセットされた場合は表面へ戻し、再タップを許可する。
      _flipTriggered = false;
      _controller.reverse();
    } else if (!oldWidget.isFlipped && widget.isFlipped && !_flipTriggered) {
      // タップ以外（復帰など）でフリップ状態になった場合もめくる。
      _flipTriggered = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_flipTriggered) return;
    // API レスポンスを待たず、タップ即めくり開始。
    setState(() => _flipTriggered = true);
    _controller.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // めくり開始後はタップ無効。
    final canTap = !_flipTriggered;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final value = _animation.value;
        final isShowingBack = value >= 0.5;
        // 表面: 0 → π/2、裏面: -π/2 → 0
        final angle = isShowingBack ? (value - 1) * pi : value * pi;
        // めくり完了側を表示する際、API レスポンス（isFlipped）が未到達なら
        // ローディング裏面を表示する。
        final backChild = widget.isFlipped ? widget.back : widget.backLoading;
        return GestureDetector(
          onTap: canTap ? _handleTap : null,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // パース設定
              ..rotateY(angle),
            child: isShowingBack ? backChild : widget.front,
          ),
        );
      },
    );
  }
}

// --- フリップ表面 ---
// 2層構造: 背景に濃紺(#15324A / Ink-900)のベースコンテナ、その上に Ink-700(#1F4A6A) +
// クリーム枠(#FBE8C7 / Surface-Cream-200)のカードを重ねて、中央に「お題をめくってスタート！」を表示。
class _StartCardFront extends StatelessWidget {
  const _StartCardFront();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      // 背景: 今ある濃紺ベース。padding 分だけ外周にフチとして見える。
      padding: const EdgeInsets.all(AppSpacing.xSmall),
      decoration: BoxDecoration(
        color: AppTheme.santaKurousuNavyDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      // 前面: Ink-700 + クリーム点線枠カード（枠は CustomPaint で点線描画）
      child: CustomPaint(
        foregroundPainter: const _DashedRoundedBorderPainter(
          color: AppTheme.santaKurousuCream200,
          strokeWidth: 1,
          radius: 14,
          dashLength: 4,
          gapLength: 2,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme.santaKurousuNavyBadge,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'お題をめくってスタート！',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.zenMaruGothic(
                    color: AppTheme.santaKurousuCardBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.30,
                    letterSpacing: 0.36,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // タップ促進アイコン
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.touch_app,
                  size: AppIconSizes.large,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 点線の角丸ボーダー描画 ---
// Flutter には点線ボーダーが無いため、Path.computeMetrics で輪郭を辿り
// dashLength / gapLength の周期で破線を描く。
class _DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  const _DashedRoundedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // strokeWidth/2 内側に寄せて、線がカード内に収まるようにする
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

// --- フリップ裏面（お題＋結果報告ボタンの白カード） ---
// フリップで表面の濃紺カードがめくれると現れる。お題と「サンタが当てた！」「スキップ」ボタンを表示。
class _TopicResultCard extends StatelessWidget {
  final String topic;
  final VoidCallback onSantaCorrect;
  final VoidCallback onSkip;

  const _TopicResultCard({
    required this.topic,
    required this.onSantaCorrect,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: ShapeDecoration(
        color: AppTheme.santaKurousuCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        shadows: const [
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowLight,
            blurRadius: 0,
            offset: Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowMedium,
            blurRadius: 24,
            offset: Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TopicCard(topic: topic),
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedLoadingButton(
                    text: 'サンタが当てた！',
                    isLoading: false,
                    onPressed: onSantaCorrect,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  flex: 1,
                  child: OutlinedLoadingButton(
                    text: 'スキップ',
                    isLoading: false,
                    onPressed: onSkip,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- フリップ裏面ローディング（APIレスポンス待ち） ---
// タップ即フリップ開始後、Firestore に endsAt/お題が反映されるまで（API レスポンス待ち）
// 表示する裏面。_TopicResultCard と同じ白カードの外観で中央にスピナーを表示する。
class _TopicResultCardLoading extends StatelessWidget {
  const _TopicResultCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: ShapeDecoration(
        color: AppTheme.santaKurousuCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        shadows: const [
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowLight,
            blurRadius: 0,
            offset: Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.santaKurousuCardShadowMedium,
            blurRadius: 24,
            offset: Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.large),
            child: CircularProgressIndicator(
              color: AppTheme.santaKurousuNavyBadge,
            ),
          ),
        ),
      ),
    );
  }
}

// --- お題カード ---

class _TopicCard extends StatelessWidget {
  final String topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.santaKurousuTopicArea,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxLarge,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'お題：',
            style: TextStyle(
              fontSize: AppTextStyles.captionFontSize,
              color: AppTheme.santaKurousuNavyBadge,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            topic,
            style: AppTextStyles.title
                .copyWith(color: AppTheme.santaKurousuNavyBadge),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- 成功/失敗ダイアログ内コンテンツ ---

class _ResultDialogContent extends ConsumerStatefulWidget {
  final _ResultType resultType;
  final String roomId;
  final String uid;
  final List<_SantaPlayer> players;
  final String? currentPresenterUid;

  const _ResultDialogContent({
    required this.resultType,
    required this.roomId,
    required this.uid,
    required this.players,
    required this.currentPresenterUid,
  });

  @override
  ConsumerState<_ResultDialogContent> createState() =>
      _ResultDialogContentState();
}

class _ResultDialogContentState extends ConsumerState<_ResultDialogContent> {
  String? _selectedAnswererUid;
  bool _isBonus = false;
  bool _isLoading = false;

  bool get _isSuccess => widget.resultType == _ResultType.success;

  /// 次に進むボタンが活性かどうか
  bool get _canProceed {
    if (!_isSuccess) return true; // 失敗の場合は常に活性
    return _selectedAnswererUid != null; // 成功の場合は正解者が選択されるまで非活性
  }

  Future<void> _onProceed() async {
    if (!_canProceed || _isLoading) return;
    setState(() => _isLoading = true);

    // ダイアログの navigator とルートを await 前に確保しておく。
    // 最終ラウンドで reportResult を送るとゲームが終了(playing→waiting)し、
    // game_state_provider がルート navigator 上で結果発表画面へ pushReplacement する。
    // これは「最前面のルート = このダイアログ」を置き換えるため、await 後に無条件で
    // pop すると結果発表画面の方を pop してしまい、出題者だけプレイ画面（次のお題）に
    // 戻ってしまう（結果発表に遷移できない）。ダイアログがまだ最前面に残っているとき
    // だけ閉じることで、この競合を防ぐ。
    final navigator = Navigator.of(context);
    final dialogRoute = ModalRoute.of(context);

    try {
      ref.read(analyticsServiceProvider).logClick(
        button: '0007_report_result',
        additionalParams: {'result': _isSuccess ? 'success' : 'failure'},
      );
      await ApiService.reportResult0007(
        context,
        widget.roomId,
        widget.uid,
        _isSuccess,
        answererUid: _isSuccess ? _selectedAnswererUid : null,
        bonus: _isBonus,
      );
      Logger.log('reportResult0007を送信しました: result=$_isSuccess');
      // ダイアログがまだ最前面のとき（非最終ラウンド、または結果発表への自動遷移が
      // まだ起きていないとき）のみ閉じる。既に結果発表画面へ置き換わっている場合は
      // 何もしない（pop すると結果発表画面を閉じてしまうため）。
      if (dialogRoute != null && dialogRoute.isCurrent) {
        navigator.pop();
      }
    } catch (e) {
      Logger.log('reportResult0007の送信に失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 正解者選択用リスト（currentPresenterを除外）
    final selectablePlayers = widget.players
        .where((p) => p.uid != widget.currentPresenterUid)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 画像 + タイトル
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _isSuccess
                  ? 'assets/images/0007/santa_kurousu_success.png'
                  : 'assets/images/0007/santa_kurousu_failure.png',
              height: _isSuccess ? 79 : 81,
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              _isSuccess ? 'それやがな！' : 'ちゃうちゃう！',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppTheme.santaKurousuNavyBadge,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxxLarge),

        // 正解者選択（成功時のみ）
        if (_isSuccess) ...[
          const Text(
            '正解したサンタ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.santaKurousuNavyBadge,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.medium,
            ),
            decoration: BoxDecoration(
              color: AppTheme.santaKurousuTopicArea,
              border: Border.all(color: AppTheme.santaKurousuNavyDark),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButton<String>(
              value: _selectedAnswererUid,
              hint: const Text(
                'タップして選択…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.santaKurousuNavyDark,
                ),
              ),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppTheme.santaKurousuTopicArea,
              items: selectablePlayers
                  .map(
                    (player) => DropdownMenuItem<String>(
                      value: player.uid,
                      child: Text(
                        player.isCurrentUser
                            ? '${player.nickname}（あなた）'
                            : player.nickname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.santaKurousuNavyDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAnswererUid = value;
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.medium),

          // ボーナスチェックボックス（成功時のみ）
          GestureDetector(
            onTap: () => setState(() => _isBonus = !_isBonus),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.small,
                vertical: AppSpacing.large,
              ),
              decoration: BoxDecoration(
                color: AppTheme.santaKurousuTopicArea,
                border: Border.all(color: AppTheme.santaKurousuNavyDark),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _isBonus,
                    activeColor: AppTheme.primaryColor,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) =>
                        setState(() => _isBonus = value ?? false),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '縛りルールも達成！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.santaKurousuNavyBadge,
                        ),
                      ),
                      Text(
                        '（ボーナス +1点）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.santaKurousuNavyBadge,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxLarge),
        ],

        // 次に進むボタン
        // 非活性時の見た目は OutlinedLoadingButton / app_theme のグレーアウトで表現される
        // （正解者未選択のあいだは選択を促すため非活性）。
        OutlinedLoadingButton(
          text: '次に進む',
          isLoading: _isLoading,
          onPressed: _canProceed ? _onProceed : null,
        ),
      ],
    );
  }
}
