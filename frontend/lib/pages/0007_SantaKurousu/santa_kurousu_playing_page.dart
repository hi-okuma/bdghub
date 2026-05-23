import 'dart:async';

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
                  // Stack 構造: 白カード（下地）の上にスタートカード（濃紺）を重ね、
                  // スワイプで濃紺カードが剥がれると白カードが現れるカード・リビール演出
                  if (isPresenter) ...[
                    Stack(
                      children: [
                        // 下地: TopicCard エリアと同じ白いカード（常時表示）
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: isTimerStarted
                              ? Container(
                                  key: const ValueKey('topic'),
                                  constraints:
                                      const BoxConstraints(minHeight: 140),
                                  decoration: ShapeDecoration(
                                    color: AppTheme.santaKurousuCardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppBorderRadius.card),
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: AppTheme
                                            .santaKurousuCardShadowLight,
                                        blurRadius: 0,
                                        offset: Offset(0, 6),
                                        spreadRadius: 0,
                                      ),
                                      BoxShadow(
                                        color: AppTheme
                                            .santaKurousuCardShadowMedium,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _TopicCard(topic: currentTopic),
                                        const SizedBox(
                                            height: AppSpacing.medium),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: ElevatedLoadingButton(
                                                text: 'サンタが当てた！',
                                                isLoading: false,
                                                onPressed: () {
                                                  ref
                                                      .read(
                                                          analyticsServiceProvider)
                                                      .logClick(
                                                          button:
                                                              '0007_santa_correct');
                                                  _showResultDialog(
                                                    context,
                                                    _ResultType.success,
                                                    roomId,
                                                    uid ?? '',
                                                    players,
                                                    currentPresenterUid,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.medium),
                                            Expanded(
                                              flex: 1,
                                              child: OutlinedLoadingButton(
                                                text: 'スキップ',
                                                isLoading: false,
                                                onPressed: () {
                                                  ref
                                                      .read(
                                                          analyticsServiceProvider)
                                                      .logClick(
                                                          button: '0007_skip');
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
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const _SkeletonCard(key: ValueKey('bg')),
                        ),

                        // 前面: スタートカード（上スワイプで飛んで白カードを露出）
                        if (!isTimerStarted)
                          _StartArea(
                            isLoading: _isLoading,
                            onPressed: () {
                              if (uid != null) _onStartTimer(roomId, uid);
                            },
                          ),
                      ],
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
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
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
            Icon(
              Icons.access_time,
              size: AppTextStyles.h5FontSize,
              color: timerColor,
            ),
            const SizedBox(width: AppSpacing.xxSmall),
            Text(
              timeText,
              style: TextStyle(
                fontSize: AppTextStyles.h5FontSize,
                fontWeight: FontWeight.bold,
                color: timerColor,
                height: 1.0,
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
                  vertical: AppSpacing.xxSmall,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.santaKurousuOrangePill,
                  borderRadius:
                      BorderRadius.circular(AppBorderRadius.elevatedButton),
                ),
                child: const Text(
                  'お約束 と 今回のおじさん',
                  style: TextStyle(
                    fontSize: AppTextStyles.bodyFontSize,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.santaKurousuNavyBadge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.small),

            // お約束テキスト
            ...rules.map(
              (rule) => Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xSmall),
                  child: Text(
                    '・$rule',
                    style: const TextStyle(
                      fontSize: AppTextStyles.bodyFontSize,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.santaKurousuNavyBadge,
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

// --- スタートエリア（Figma: 濃紺 #15324a、角丸20px） ---
// 「お題をめくってスタート！」テキスト + 右下キャラ小画像風
// 上スワイプでタイマー開始。スワイプ量60px超 or 速度500px/s超で発火し上方へ飛ぶ。
class _StartArea extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _StartArea({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_StartArea> createState() => _StartAreaState();
}

class _StartAreaState extends State<_StartArea>
    with SingleTickerProviderStateMixin {
  double _dragDy = 0.0;
  late final AnimationController _animController;
  Animation<double>? _animation;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
    _animController.addListener(_onAnimTick);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onAnimTick() {
    if (mounted) setState(() => _dragDy = _animation?.value ?? _dragDy);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_triggered) return;
    _animController.stop();
    setState(() {
      _dragDy = (_dragDy + details.delta.dy).clamp(-300.0, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_triggered) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDy < -60 || velocity < -500) {
      _flyOff();
    } else {
      _snapBack();
    }
  }

  void _flyOff() {
    _triggered = true;
    widget.onPressed();
    _animation = Tween<double>(begin: _dragDy, end: -300.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController
      ..duration = const Duration(milliseconds: 200)
      ..reset()
      ..forward();
  }

  void _snapBack() {
    _animation = Tween<double>(begin: _dragDy, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController
      ..duration = const Duration(milliseconds: 500)
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading || _triggered ? null : widget.onPressed,
      onVerticalDragUpdate:
          widget.isLoading || _triggered ? null : _onDragUpdate,
      onVerticalDragEnd: widget.isLoading || _triggered ? null : _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragDy),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppTheme.santaKurousuNavyDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xLarge,
            vertical: AppSpacing.xLarge,
          ),
          child: Row(
            children: [
              Expanded(
                child: widget.isLoading
                    ? const Center(
                        child: SizedBox(
                          width: AppIconSizes.small,
                          height: AppIconSizes.small,
                          child: CircularProgressIndicator(
                            strokeWidth: AppLayout.circleIndicatorStroke,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'お題をめくってスタート！',
                        style: TextStyle(
                          fontSize: AppTextStyles.titleFontSize,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.santaKurousuCardBg,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // 右下キャラ小画像（タップ促進アイコン）
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

// --- スケルトンカード（_StartArea 背後の下地。スワイプで剥がれると露出） ---

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({super.key});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // お題エリア スケルトン
              Container(
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
                    Text(
                      'お題：',
                      style: TextStyle(
                        fontSize: AppTextStyles.captionFontSize,
                        color: AppTheme.santaKurousuNavyBadge
                            .withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.large),
                    Container(
                      width: 100,
                      height: AppTextStyles.titleFontSize + 4,
                      decoration: BoxDecoration(
                        color: AppTheme.santaKurousuNavyBadge
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.small),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              // ボタン スケルトン
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.santaKurousuNavyBadge
                              .withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      if (mounted) {
        Navigator.of(context).pop();
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
                'タップして選択...',
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
        OutlinedLoadingButton(
          text: '次に進む',
          isLoading: _isLoading,
          onPressed: _canProceed ? _onProceed : null,
        ),
      ],
    );
  }
}
