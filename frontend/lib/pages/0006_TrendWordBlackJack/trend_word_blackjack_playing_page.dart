import 'dart:math' show max, pi;

import 'package:bodogehub/utils/logger.dart';
import 'package:confetti/confetti.dart';
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

// TrendWordBlackJackゲーム画面用のプレイヤー表示データ
class TrendWordBlackJackPlayer {
  final String uid;
  final String nickname;
  final int score;
  final int lastScore;
  final int cardCount;
  final bool isBurst;
  final bool isCurrentUser;

  TrendWordBlackJackPlayer({
    required this.uid,
    required this.nickname,
    required this.score,
    required this.lastScore,
    required this.cardCount,
    this.isBurst = false,
    this.isCurrentUser = false,
  });
}

class TrendWordBlackJackPlayingPage extends ConsumerStatefulWidget {
  const TrendWordBlackJackPlayingPage({super.key});

  @override
  ConsumerState<TrendWordBlackJackPlayingPage> createState() =>
      _TrendWordBlackJackPlayingPageState();
}

class _TrendWordBlackJackPlayingPageState
    extends ConsumerState<TrendWordBlackJackPlayingPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  // ignore: unused_field
  bool _isConfirmingCard = false;
  // ignore: unused_field
  bool _isAdoptingValue = false;
  bool _isWatchCardDialogOpen = false;
  bool _isResultDialogOpen = false;
  DateTime? _watchCardDialogOpenTime;
  String? _watchedCardId; // 観戦ダイアログを表示済みの selectedCardId
  bool _isRestorationHandled = false;
  bool _isCpuActing = false;
  int _cpuActionGeneration = 0;
  bool _hasLoggedPageView = false;

  // --- GameExitHandler 必須オーバーライド ---
  @override
  final String pageTitle = '/0006/trend_word_blackjack_playing_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void setError(String message) {
    if (mounted) {
      Logger.log('TrendWordBlackJackPlayingPageでエラー発生: $message');
    }
  }

  // --- RouteAware ライフサイクル ---
  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
    // 復帰時: 表示すべきダイアログを再現する & 初回 CPU ターンチェック
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestoreDialogs();
      _checkInitialCpuTurn();
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
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  // page_view は opponent_type パラメータ付きで送信するため、
  // didPush() ではなく roomStreamProvider のデータが揃った build 内で一度だけログする

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

  // --- カード確定APIコール ---
  Future<void> _onConfirmCard(String cardId) async {
    final currentUser = ref.read(userProvider);
    final roomId = currentUser.roomId;
    final uid = currentUser.uid;

    if (roomId == null || uid == null) return;

    setState(() {
      _isConfirmingCard = true;
    });

    try {
      ref.read(analyticsServiceProvider).logClick(
        button: '0006_select_card',
        additionalParams: {'cardId': cardId},
      );
      await ApiService.confirmCard0006(context, roomId, uid, cardId);
      Logger.log('カード確定を送信しました: $cardId');
    } catch (e) {
      Logger.log('カード確定の送信に失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingCard = false;
        });
      }
    }
  }

  // --- CPU スコア計算ヘルパー ---
  int _cpuToScoreFromWesternEra(int year) =>
      year >= 2000 ? year - 2000 : year - 1900;

  int _cpuToScoreFromJapaneseEra(int year) {
    if (year >= 2019) return year - 2018; // 令和
    if (year >= 1989) return year - 1988; // 平成
    if (year >= 1926) return year - 1925; // 昭和
    if (year >= 1912) return year - 1911; // 大正
    return year - 1867; // 明治
  }

  // 利用可能なカードの中から最適なカードIDを返す
  // 戦略: バーストしない範囲で targetScore に最も近くなるカード+年代の組み合わせを優先
  String? _cpuChooseBestCard(
      List<dynamic> availableCards, int cpuScore, int targetScore) {
    String? bestCardId;
    double bestValue = double.negativeInfinity;

    for (final card in availableCards) {
      final cardId = _extractStringValue(card['cardId']);
      if (cardId == null) continue;
      final year = _extractIntValue(card['year']) ?? 0;
      final westernAdd = _cpuToScoreFromWesternEra(year);
      final japaneseAdd = _cpuToScoreFromJapaneseEra(year);

      // 西暦・和暦の両オプションのうち、このカードの最良値を評価
      double cardBest = double.negativeInfinity;
      for (final add in [westernAdd, japaneseAdd]) {
        final newScore = cpuScore + add;
        // バーストしないほど高評価、バーストは超過量でペナルティ
        final v = newScore <= targetScore
            ? newScore.toDouble()
            : -(newScore - targetScore).toDouble() - 1000;
        if (v > cardBest) cardBest = v;
      }

      if (cardBest > bestValue) {
        bestValue = cardBest;
        bestCardId = cardId;
      }
    }
    return bestCardId;
  }

  // 確定済みカードに対して最適な年代種別 ('Western' / 'Japanese') を返す
  String _cpuChooseBestValueType(
      Map<String, dynamic> card, int cpuScore, int targetScore) {
    final year = _extractIntValue(card['year']) ?? 0;
    final westernAdd = _cpuToScoreFromWesternEra(year);
    final japaneseAdd = _cpuToScoreFromJapaneseEra(year);
    final newWestern = cpuScore + westernAdd;
    final newJapanese = cpuScore + japaneseAdd;

    // 両方バースト → 超過量が小さい方
    if (newWestern > targetScore && newJapanese > targetScore) {
      return newWestern <= newJapanese ? 'Western' : 'Japanese';
    }
    // 片方バースト → 安全な方
    if (newWestern > targetScore) return 'Japanese';
    if (newJapanese > targetScore) return 'Western';
    // どちらもセーフ → スコアが高い方（targetScore に近い方）
    return newWestern >= newJapanese ? 'Western' : 'Japanese';
  }

  // --- CPU アクション実行 ---
  // カード選択 → 年代選択を1つの非同期メソッドでチェーン実行する。
  // ref.listen の再発火に依存すると、Firestore リアルタイム更新と
  // API レスポンスの到着順が逆転し年代選択がスキップされるため。
  Future<void> _runCpuFullTurn(
      String roomId, String cpuUid, String cardId, String valueType) async {
    final generation = _cpuActionGeneration;
    try {
      // カード選択フェーズ
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || _cpuActionGeneration != generation) return;
      await ApiService.confirmCard0006(context, roomId, cpuUid, cardId);
      Logger.log('CPU カード選択完了: $cardId');

      // 年代選択フェーズ（観戦ダイアログのアニメーション考慮）
      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted || _cpuActionGeneration != generation) return;
      await ApiService.adoptValue0006(context, roomId, cpuUid, valueType);
      Logger.log('CPU 年代選択完了: $valueType');
      // 成功時は _isCpuActing をリセットしない。
      // ref.listen がターン変更を検知した時にリセットされる。
    } catch (e) {
      Logger.log('CPU ターンエラー: $e');
      // エラー時のみリセット（ref.listen によるリトライを許可）
      if (_cpuActionGeneration == generation) _isCpuActing = false;
    }
  }

  // 年代選択のみ（復帰時など、カード確定済みの状態から開始する場合）
  Future<void> _runCpuYearSelection(
      String roomId, String cpuUid, String valueType) async {
    final generation = _cpuActionGeneration;
    try {
      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted || _cpuActionGeneration != generation) return;
      await ApiService.adoptValue0006(context, roomId, cpuUid, valueType);
      Logger.log('CPU 年代選択完了: $valueType');
    } catch (e) {
      Logger.log('CPU 年代選択エラー: $e');
      if (_cpuActionGeneration == generation) _isCpuActing = false;
    }
  }

  // --- 復帰時ダイアログ再現 ---
  Future<void> _checkAndRestoreDialogs() async {
    if (_isRestorationHandled) return;
    final user = ref.read(userProvider);
    if (!user.isRestoring) return;

    _isRestorationHandled = true;

    final gameData = ref.read(currentGameProvider).gameData;
    if (gameData == null || !mounted) return;

    final roomId = user.roomId;
    if (roomId == null) return;

    final gameStatus = _extractStringValue(gameData['gameStatus']);
    final screenSize = MediaQuery.of(context).size;

    // --- 結果発表ダイアログの復帰 ---
    // winnerId が存在する場合のみゲーム終了後の waiting（結果確認待ち）と判定する
    final winnerId = _extractStringValue(gameData['winnerId']);
    if (gameStatus == 'waiting' && winnerId != null && !_isResultDialogOpen) {
      _isResultDialogOpen = true;
      final isWin = winnerId == user.uid;
      const double dialogHeight = 500.0;
      final double verticalInset =
          max(32.0, (screenSize.height - dialogHeight) / 2);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: verticalInset,
          ),
          child: SizedBox(
            height: dialogHeight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xLarge),
              child: _TrendWordResultDialogContent(
                isWin: isWin,
                roomId: roomId,
                onExitPressed: () => showExitGameDialog(),
              ),
            ),
          ),
        ),
      ).then((_) {
        if (mounted) _isResultDialogOpen = false;
      });
      return;
    }

    // --- 年代選択ダイアログの復帰（自分の手番 && カード確定済み）---
    if (gameStatus == 'playing') {
      final uid = user.uid;
      final turnOrder = gameData['turnOrder'] as List?;
      final currentTurnIndex =
          _extractIntValue(gameData['currentTurnPlayerIndex']);
      final currentTurnUid = (currentTurnIndex != null &&
              turnOrder != null &&
              currentTurnIndex < turnOrder.length)
          ? turnOrder[currentTurnIndex] as String?
          : null;
      final selectedCardId = _extractStringValue(gameData['selectedCardId']);

      if (uid == currentTurnUid && selectedCardId != null) {
        final boardCards = gameData['boardCards'] as List<dynamic>?;
        final selectedCardIndex = boardCards?.indexWhere(
            (card) => _extractStringValue(card['cardId']) == selectedCardId);

        if (boardCards != null &&
            selectedCardIndex != null &&
            selectedCardIndex != -1) {
          final card = boardCards[selectedCardIndex] as Map<String, dynamic>;
          final playersData = gameData['players'] as Map<String, dynamic>?;
          final myPlayerData = playersData?[uid] as Map<String, dynamic>?;
          final currentScore = _extractIntValue(myPlayerData?['score']) ?? 0;

          if (!mounted) return;
          final result = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.15,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                child: _CardSelectionDialogContent(
                  card: card,
                  onConfirm: null, // カードは既に確定済み
                  currentScore: currentScore,
                  startFlipped: true,
                ),
              ),
            ),
          );

          if (result != null && mounted) {
            await _onAdoptValue(result);
          }
        }
      }
    }
  }

  // --- 初回 CPU ターンチェック ---
  // ref.listen は状態変化でのみ発火するため、ゲーム開始時に既に CPU ターンだった場合を
  // initState の post-frame callback で拾う。roomStreamProvider が loading 中は
  // CPU 判定ができないため、データが届くまでリトライする。
  void _checkInitialCpuTurn() {
    if (!mounted || _isCpuActing) return;

    final user = ref.read(userProvider);
    final gameData = ref.read(currentGameProvider).gameData;
    if (gameData == null) return;

    final gameStatus = _extractStringValue(gameData['gameStatus']);
    if (gameStatus != 'playing') return;

    final roomId = user.roomId;
    if (roomId == null) return;

    // roomStreamProvider がまだ loading 中なら少し待ってリトライ
    final roomSnap = ref.read(roomStreamProvider(roomId));
    final roomData = roomSnap.whenOrNull(
      data: (snapshot) => snapshot.data() as Map<String, dynamic>?,
    );
    if (roomData == null) {
      // まだロードされていない → 少し待って再試行
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isCpuActing) _checkInitialCpuTurn();
      });
      return;
    }
    final roomPlayersMap = roomData['players'] as Map<String, dynamic>? ?? {};

    final playersGameData = gameData['players'] as Map<String, dynamic>? ?? {};
    final turnOrder = gameData['turnOrder'] as List?;
    final currentTurnIndex =
        _extractIntValue(gameData['currentTurnPlayerIndex']);
    final currentTurnUid = (currentTurnIndex != null &&
            turnOrder != null &&
            currentTurnIndex < turnOrder.length)
        ? turnOrder[currentTurnIndex] as String?
        : null;

    final isCpuTurn = currentTurnUid != null &&
        playersGameData.containsKey(currentTurnUid) &&
        !roomPlayersMap.containsKey(currentTurnUid);

    if (!isCpuTurn) return;

    _triggerCpuAction(
      gameData: gameData,
      playersGameData: playersGameData,
      roomPlayersMap: roomPlayersMap,
      currentTurnUid: currentTurnUid!,
      roomId: roomId,
    );
  }

  // --- CPU アクションの共通トリガー ---
  // ref.listen と _checkInitialCpuTurn の両方から呼ばれる
  void _triggerCpuAction({
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> playersGameData,
    required Map<String, dynamic> roomPlayersMap,
    required String currentTurnUid,
    required String roomId,
  }) {
    if (_isCpuActing) return;
    _isCpuActing = true;

    final cpuUid = currentTurnUid;
    final cpuPlayerData = playersGameData[cpuUid] as Map<String, dynamic>?;
    final cpuScore = _extractIntValue(cpuPlayerData?['score']) ?? 0;

    final assetsConfig = gameData['assets']?['config'] as Map<String, dynamic>?;
    final totalPlayerCount = playersGameData.length;
    final targetScore =
        (assetsConfig?[totalPlayerCount.toString()]?['targetScore'] as num?)
                ?.toInt() ??
            150;

    final selectedCardId = _extractStringValue(gameData['selectedCardId']);
    final boardCards = gameData['boardCards'] as List<dynamic>?;

    if (selectedCardId == null && boardCards != null) {
      // カード未選択 → カード選択＋年代選択を一括実行
      final availableCards = boardCards
          .where((card) =>
              card['isAvailable'] == null || card['isAvailable'] == true)
          .toList();
      final bestCardId =
          _cpuChooseBestCard(availableCards, cpuScore, targetScore);
      if (bestCardId != null) {
        final cardData = availableCards
            .firstWhere((c) => _extractStringValue(c['cardId']) == bestCardId);
        final valueType = _cpuChooseBestValueType(
            cardData as Map<String, dynamic>, cpuScore, targetScore);
        _runCpuFullTurn(roomId, cpuUid, bestCardId, valueType);
      } else {
        _isCpuActing = false;
      }
    } else if (selectedCardId != null && boardCards != null) {
      // カード確定済み → 年代選択のみ
      final idx = boardCards.indexWhere(
          (card) => _extractStringValue(card['cardId']) == selectedCardId);
      if (idx != -1) {
        final card = boardCards[idx] as Map<String, dynamic>;
        final valueType = _cpuChooseBestValueType(card, cpuScore, targetScore);
        _runCpuYearSelection(roomId, cpuUid, valueType);
      } else {
        _isCpuActing = false;
      }
    } else {
      _isCpuActing = false;
    }
  }

  // --- 値採用APIコール ---
  Future<void> _onAdoptValue(String valueType) async {
    final currentUser = ref.read(userProvider);
    final roomId = currentUser.roomId;
    final uid = currentUser.uid;

    if (roomId == null || uid == null) return;

    setState(() {
      _isAdoptingValue = true;
    });

    try {
      // GA ログ: 年代選択
      final gameData = ref.read(currentGameProvider).gameData;
      final selectedCardId = gameData?['selectedCardId'];
      final boardCards = gameData?['boardCards'] as List<dynamic>?;
      if (selectedCardId != null && boardCards != null) {
        final cardIdx = boardCards.indexWhere(
            (c) => (c as Map<String, dynamic>)['cardId'] == selectedCardId);
        if (cardIdx != -1) {
          final card = boardCards[cardIdx] as Map<String, dynamic>;
          final year = _extractIntValue(card['year']) ?? 0;
          final scoreAdded = valueType == 'Western'
              ? (year >= 2000 ? year - 2000 : year - 1900)
              : _extractIntValue(card['year']) != null
                  ? _cpuToScoreFromJapaneseEra(year)
                  : 0;
          ref.read(analyticsServiceProvider).logClick(
            button: '0006_select_year_type',
            additionalParams: {
              'year_type': valueType == 'Western' ? 'western' : 'japanese',
              'score_added': scoreAdded,
            },
          );
        }
      }

      await ApiService.adoptValue0006(context, roomId, uid, valueType);
      Logger.log('値採用を送信しました: $valueType');
    } catch (e) {
      Logger.log('値採用の送信に失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAdoptingValue = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // --- 手番でないプレイヤー向け: 相手カード選択ダイアログの開閉監視 ---
    ref.listen(currentGameProvider, (_, next) {
      final user = ref.read(userProvider);
      final gameData = next.gameData;
      if (gameData == null) return;

      final turnOrder = gameData['turnOrder'] as List?;
      final currentTurnIndex =
          _extractIntValue(gameData['currentTurnPlayerIndex']);
      final currentTurnUid = (currentTurnIndex != null &&
              turnOrder != null &&
              currentTurnIndex < turnOrder.length)
          ? turnOrder[currentTurnIndex] as String?
          : null;
      final isCurrentTurn = user.uid == currentTurnUid;

      final selectedCardId = _extractStringValue(gameData['selectedCardId']);
      final boardCards = gameData['boardCards'] as List<dynamic>?;
      final selectedCardIndex = boardCards?.indexWhere(
          (card) => _extractStringValue(card['cardId']) == selectedCardId);
      // 存在しない場合は -1 が返るため、 selectedCardIndex != -1 で判定

      // --- リプレイ検知 ---
      // playing に戻ったのに結果ダイアログが残っている場合は閉じる
      // CPU ターン処理より先に実行し、世代カウンタを更新してから CPU アクションを開始する
      final gameStatus = _extractStringValue(gameData['gameStatus']);
      if (gameStatus == 'playing' && _isResultDialogOpen) {
        _isResultDialogOpen = false;
        _cpuActionGeneration++;
        _isCpuActing = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(); // 結果ダイアログを閉じる
        });
      }

      // --- CPU ターン処理 ---
      // roomPlayersMap に存在しない UID = CPU プレイヤー
      final playersGameData =
          gameData['players'] as Map<String, dynamic>? ?? {};
      final roomSnap = ref.read(roomStreamProvider(user.roomId ?? ''));
      // roomStreamProvider がまだ loading 中の場合は CPU 判定を行わない
      // （空の roomPlayersMap だと全プレイヤーが CPU 扱いになってしまうため）
      final roomData = roomSnap.whenOrNull(
        data: (snapshot) => snapshot.data() as Map<String, dynamic>?,
      );
      final roomPlayersMap =
          roomData?['players'] as Map<String, dynamic>? ?? {};
      final isRoomLoaded = roomSnap.hasValue;

      if (isRoomLoaded) {
        final isCpuTurn = currentTurnUid != null &&
            playersGameData.containsKey(currentTurnUid) &&
            !roomPlayersMap.containsKey(currentTurnUid);

        // CPU のターンでなくなったらフラグをリセット
        // （_runCpuFullTurn 成功後、ターン変更の Firestore 更新で到達）
        // ただし currentTurnUid が null（ターン情報が不完全な中間状態）の場合は
        // リセットしない。loadFromCurrentGame の loadGameFromFirestore 直後など、
        // gameData が基本情報のみで turnOrder を持たない瞬間にリセットされると
        // 直後の完全な状態更新で CPU アクションが二重起動してしまう。
        if (currentTurnUid != null && !isCpuTurn && _isCpuActing) {
          _isCpuActing = false;
        }

        // playing 状態の時のみ CPU アクションを実行（waiting 中の誤発火を防止）
        if (gameStatus == 'playing' && isCpuTurn && !_isCpuActing) {
          final roomId = user.roomId;
          if (roomId != null) {
            _triggerCpuAction(
              gameData: gameData,
              playersGameData: playersGameData,
              roomPlayersMap: roomPlayersMap,
              currentTurnUid: currentTurnUid!,
              roomId: roomId,
            );
          }
        }
      }

      // 条件合致 → ダイアログを開く
      // 同じ selectedCardId に対して一度だけ表示する（手動で閉じた後の再表示を防止）
      if (!isCurrentTurn &&
          selectedCardId != null &&
          selectedCardId != _watchedCardId &&
          selectedCardIndex != -1 &&
          boardCards != null &&
          !_isWatchCardDialogOpen) {
        _isWatchCardDialogOpen = true;
        _watchedCardId = selectedCardId;
        _watchCardDialogOpenTime = DateTime.now();
        final card = boardCards[selectedCardIndex!] as Map<String, dynamic>;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.15,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                child: _WatchCardDialogContent(
                  card: card,
                  // フリップ後に手動クローズされた際、タイマーより先に同期的にフラグをリセット
                  // これにより自動クローズタイマーとの競合状態を防ぐ
                  onManualClose: () {
                    _isWatchCardDialogOpen = false;
                    _watchCardDialogOpenTime = null;
                  },
                ),
              ),
            ),
          ).then((_) {
            if (mounted) _isWatchCardDialogOpen = false;
          });
        });
      }

      // selectedCardId が null になった → 観戦ダイアログを閉じる＋追跡リセット
      // アニメーション(1000ms遅延 + 400ms flip)完了後にバッファを加えた
      // 最小表示時間(4000ms)を保証してから閉じる
      if (selectedCardId == null) {
        _watchedCardId = null; // 次のカード選択で再表示できるようリセット
        if (_isWatchCardDialogOpen) {
          const minShowDuration = Duration(milliseconds: 4000);
          final openTime = _watchCardDialogOpenTime;
          final elapsed = openTime != null
              ? DateTime.now().difference(openTime)
              : minShowDuration;
          final remaining = minShowDuration - elapsed;
          final delay = remaining > Duration.zero ? remaining : Duration.zero;
          final navigator = Navigator.of(context);
          Future.delayed(delay, () {
            if (mounted && _isWatchCardDialogOpen) {
              _isWatchCardDialogOpen = false;
              _watchCardDialogOpenTime = null;
              navigator.pop();
            }
          });
        }
      }

      // ゲーム終了 (waiting) → 結果発表ダイアログを表示
      final roomId = user.roomId;
      if (gameStatus == 'waiting' && !_isResultDialogOpen && roomId != null) {
        // 進行中の CPU アクションをキャンセル
        _cpuActionGeneration++;
        _isCpuActing = false;

        // 観戦ダイアログが開いていれば強制的に閉じる
        if (_isWatchCardDialogOpen) {
          _isWatchCardDialogOpen = false;
          _watchCardDialogOpenTime = null;
          _watchedCardId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }

        _isResultDialogOpen = true;
        final winnerId = _extractStringValue(gameData['winnerId']);
        final isWin = winnerId == user.uid;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black,
            builder: (_) {
              const double dialogHeight = 500.0;
              final double verticalInset =
                  max(32.0, (screenHeight - dialogHeight) / 2);
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
                ),
                insetPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: verticalInset,
                ),
                child: SizedBox(
                  height: dialogHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xLarge),
                    child: _TrendWordResultDialogContent(
                      isWin: isWin,
                      roomId: roomId,
                      onExitPressed: () => showExitGameDialog(),
                    ),
                  ),
                ),
              );
            },
          ).then((_) {
            if (mounted) _isResultDialogOpen = false;
          });
        });
      }
    });

    // --- ガード: gameData null check ---
    if (currentGame.gameData == null || currentGame.gameData!.isEmpty) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final gameData = currentGame.gameData;
    final gameTitle = gameData?['title'] as String;
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

    // --- プレイヤーデータ取得 ---
    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    final gamePlayers = roomSnapshot.when(
      data: (snapshot) {
        if (!snapshot.exists) return <TrendWordBlackJackPlayer>[];

        final roomData = snapshot.data() as Map<String, dynamic>?;
        final roomPlayersMap =
            roomData?['players'] as Map<String, dynamic>? ?? {};

        final playersGameData =
            gameData?['players'] as Map<String, dynamic>? ?? {};

        List<TrendWordBlackJackPlayer> players = [];

        // roomPlayersMapに存在する実プレイヤーを追加
        for (final entry in roomPlayersMap.entries) {
          final uid = entry.key;
          final roomPlayerData = entry.value as Map<String, dynamic>;
          final gamePlayerData = playersGameData[uid] as Map<String, dynamic>?;

          final nickname =
              _extractStringValue(roomPlayerData['nickname']) ?? '名無し';
          final score = _extractIntValue(gamePlayerData?['score']) ?? 0;
          final lastScore = _extractIntValue(gamePlayerData?['lastScore']) ?? 0;
          final cardCount = _extractIntValue(gamePlayerData?['cardCount']) ?? 0;
          final isBurst = gamePlayerData?['isBurst'] ?? false;

          players.add(TrendWordBlackJackPlayer(
            uid: uid,
            nickname: nickname,
            score: score,
            lastScore: lastScore,
            cardCount: cardCount,
            isBurst: isBurst,
            isCurrentUser: uid == currentUser.uid,
          ));
        }

        // gameDataにのみ存在するCPUプレイヤーを追加
        for (final entry in playersGameData.entries) {
          final uid = entry.key;
          if (roomPlayersMap.containsKey(uid)) continue;

          final gamePlayerData = entry.value as Map<String, dynamic>?;
          final nickname =
              _extractStringValue(gamePlayerData?['nickname']) ?? 'CPU';
          final score = _extractIntValue(gamePlayerData?['score']) ?? 0;
          final lastScore = _extractIntValue(gamePlayerData?['lastScore']) ?? 0;
          final cardCount = _extractIntValue(gamePlayerData?['cardCount']) ?? 0;
          final isBurst = gamePlayerData?['isBurst'] ?? false;

          players.add(TrendWordBlackJackPlayer(
            uid: uid,
            nickname: nickname,
            score: score,
            lastScore: lastScore,
            cardCount: cardCount,
            isBurst: isBurst,
            isCurrentUser: false,
          ));
        }

        return players;
      },
      loading: () => <TrendWordBlackJackPlayer>[],
      error: (_, __) => <TrendWordBlackJackPlayer>[],
    );

    // --- page_view ログ（opponent_type 付き、一度だけ送信）---
    if (!_hasLoggedPageView && gamePlayers.isNotEmpty) {
      _hasLoggedPageView = true;
      // roomPlayersMap に存在しない = CPU プレイヤー
      final hasCpu = roomSnapshot.whenOrNull(
            data: (snapshot) {
              final roomData = snapshot.data() as Map<String, dynamic>?;
              final roomPlayersMap =
                  roomData?['players'] as Map<String, dynamic>? ?? {};
              final allGamePlayers =
                  gameData?['players'] as Map<String, dynamic>? ?? {};
              return allGamePlayers.keys
                  .any((uid) => !roomPlayersMap.containsKey(uid));
            },
          ) ??
          false;
      ref.read(analyticsServiceProvider).logPageView(
        pageTitle: pageTitle,
        additionalParams: {
          'opponent_type': hasCpu ? 'cpu' : 'human',
        },
      );
    }

    // --- assets/config からプレイヤー数に応じた設定を取得 ---
    // CPU プレイヤーを含む全プレイヤー数で config を参照する
    final playersGameData = gameData?['players'] as Map<String, dynamic>? ?? {};
    final totalPlayerCount = playersGameData.length;
    final assetsConfig =
        gameData?['assets']?['config'] as Map<String, dynamic>?;
    final playerConfig =
        assetsConfig?[totalPlayerCount.toString()] as Map<String, dynamic>?;
    final maxCardCount =
        (playerConfig?['maxCardsPerPlayer'] as num?)?.toInt() ?? 5;
    final targetScore = (playerConfig?['targetScore'] as num?)?.toInt();

    // --- 直前ターンで加算されたスコア（currentGame直下） ---
    final lastTurnScore = _extractIntValue(gameData?['lastTurnScore']);

    // --- 現在の手番プレイヤーUIDを取得 ---
    final turnOrder = gameData?['turnOrder'] as List?;
    final currentTurnPlayerIndex =
        _extractIntValue(gameData?['currentTurnPlayerIndex']);
    final currentTurnPlayerUid = (currentTurnPlayerIndex != null &&
            turnOrder != null &&
            currentTurnPlayerIndex < turnOrder.length)
        ? turnOrder[currentTurnPlayerIndex] as String?
        : null;

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
        backgroundColor: AppTheme.trendWordGameBackGroundColor,
        body: Column(
          children: [
            // プレイヤーエリア
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: gamePlayers.isEmpty
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
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // 高さを揃え
                      children: [
                        // for文を使って直接Widgetを展開
                        for (final player in gamePlayers)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xSmall),
                              child: _AnimatedPlayerCard(
                                player: player,
                                maxCardCount: maxCardCount,
                                currentTurnPlayerUid: currentTurnPlayerUid,
                                targetScore: targetScore,
                                lastTurnScore: lastTurnScore,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // ボードカードエリア（4x4グリッド）
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.small),
                child: BoardGridSection(
                  gameData: gameData,
                  isCurrentTurn: currentUser.uid == currentTurnPlayerUid,
                  onConfirmCard: _onConfirmCard,
                  onAdoptValue: _onAdoptValue,
                  currentScore: gamePlayers
                      .firstWhere(
                        (p) => p.isCurrentUser,
                        orElse: () => TrendWordBlackJackPlayer(
                          uid: '',
                          nickname: '',
                          score: 0,
                          lastScore: 0,
                          cardCount: 0,
                        ),
                      )
                      .score,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// プレイヤーカードウィジェット（スコアカウントアップアニメーション付き）
class _AnimatedPlayerCard extends StatefulWidget {
  final TrendWordBlackJackPlayer player;
  final int maxCardCount;
  final String? currentTurnPlayerUid;
  final int? targetScore;
  final int? lastTurnScore;

  const _AnimatedPlayerCard({
    required this.player,
    required this.maxCardCount,
    this.currentTurnPlayerUid,
    this.targetScore,
    this.lastTurnScore,
  });

  @override
  State<_AnimatedPlayerCard> createState() => _AnimatedPlayerCardState();
}

class _AnimatedPlayerCardState extends State<_AnimatedPlayerCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _scoreAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _displayDelta = 0;
  bool _hasDelta = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnimation = AlwaysStoppedAnimation(widget.player.score);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 20), // フェードイン
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 47), // 表示維持
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 33), // フェードアウト
    ]).animate(_fadeController);
  }

  @override
  void didUpdateWidget(covariant _AnimatedPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.score != widget.player.score) {
      if (widget.player.score < oldWidget.player.score) {
        // スコアが減少（ゲームリセット時）→ アニメーションなしで即座に反映
        _scoreAnimation = AlwaysStoppedAnimation(widget.player.score);
        _controller.reset();
      } else {
        // スコアが増加（通常のターン）→ カウントアップアニメーション
        final fromScore = widget.player.score - (widget.lastTurnScore ?? 0);
        _scoreAnimation = IntTween(
          begin: fromScore,
          end: widget.player.score,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
        _controller.forward(from: 0.0);
      }
    }

    // +delta フェードアニメーション
    // このプレイヤーの手番が終わったタイミングでのみ発火（0点ターンも含む）
    // nullはゲーム開始前なので非表示
    if (oldWidget.currentTurnPlayerUid == widget.player.uid &&
        oldWidget.currentTurnPlayerUid != widget.currentTurnPlayerUid &&
        widget.lastTurnScore != null) {
      setState(() {
        _displayDelta = widget.lastTurnScore!;
        _hasDelta = true;
      });
      _fadeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isCurrentTurn = player.uid == widget.currentTurnPlayerUid;

    // 色を決定：自分の手番ならplayer、相手の手番ならopponent、それ以外はdisabled
    final Color cardColor;
    if (player.isCurrentUser) {
      cardColor = isCurrentTurn
          ? AppTheme.trendWordGamePlayerColor
          : AppTheme.trendWordGameDisabledColor;
    } else {
      cardColor = isCurrentTurn
          ? AppTheme.trendWordGameOpponentColor
          : AppTheme.trendWordGameDisabledColor;
    }

    final Color textColor;
    if (player.isCurrentUser) {
      textColor = isCurrentTurn
          ? AppTheme.trendWordGamePlayerColor
          : AppTheme.secondaryTextColor;
    } else {
      textColor = isCurrentTurn
          ? AppTheme.trendWordGameOpponentColor
          : AppTheme.secondaryTextColor;
    }

    final Color dotColor;
    player.isCurrentUser
        ? dotColor = AppTheme.trendWordGamePlayerColor
        : dotColor = AppTheme.trendWordGameOpponentColor;

    return Card(
      color: AppTheme.trendWordGamePlayerCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
        side: BorderSide(color: cardColor),
      ),
      margin: const EdgeInsets.all(AppSpacing.xxSmall),
      child: SizedBox(
        height: AppLayout.trendWordGameCardHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xSmall, horizontal: AppSpacing.large),
          child: AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              final animatedScore = _scoreAnimation.value;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.nickname,
                    style: AppTextStyles.subtitle
                        .copyWith(height: 1.0, color: textColor),
                  ),
                  const SizedBox(
                    height: AppSpacing.xSmall,
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        animatedScore.toString(),
                        style: AppTextStyles.h3.copyWith(
                          height: 1.1,
                          color: Colors.white,
                          textBaseline: TextBaseline.ideographic,
                        ),
                      ),
                      if (_hasDelta)
                        Positioned(
                          top: -6,
                          right: -24,
                          child: AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, _) => Opacity(
                              opacity: _fadeAnimation.value,
                              child: Text(
                                '+$_displayDelta',
                                style: AppTextStyles.h5.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: AppSpacing.xSmall,
                  ),
                  // カード数をドットで表示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.maxCardCount,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxSmall),
                        child: index < player.cardCount
                            ? Icon(
                                Icons.circle,
                                size: AppIconSizes.cardCountDot,
                                color: dotColor,
                              )
                            : const Icon(
                                Icons.circle,
                                size: AppIconSizes.cardCountDot,
                                color: AppTheme.trendWordGameDisabledColor,
                              ),
                      ),
                    ),
                  ),
                  if (widget.targetScore != null)
                    Text(
                      'あと${widget.targetScore! - animatedScore}',
                      style: AppTextStyles.subtitle2
                          .copyWith(color: AppTheme.secondaryTextColor),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ボードグリッドセクション
class BoardGridSection extends StatefulWidget {
  final Map<String, dynamic>? gameData;
  final bool isCurrentTurn;
  final Future<void> Function(String cardId)? onConfirmCard;
  final Future<void> Function(String valueType)? onAdoptValue;
  final int currentScore;

  const BoardGridSection({
    super.key,
    this.gameData,
    this.isCurrentTurn = false,
    this.onConfirmCard,
    this.onAdoptValue,
    required this.currentScore,
  });

  @override
  State<BoardGridSection> createState() => _BoardGridSectionState();
}

class _BoardGridSectionState extends State<BoardGridSection> {
  // 型安全な値抽出ヘルパー
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

  // カード選択確認ダイアログを表示
  Future<void> _showCardSelectionDialog(
      BuildContext context, Map<String, dynamic> card) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xLarge),
        ),
        // backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.15,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: _CardSelectionDialogContent(
            card: card,
            onConfirm: widget.onConfirmCard,
            currentScore: widget.currentScore,
          ),
        ),
      ),
    );

    // ダイアログから valueType が返ってきた場合、年代採用APIを呼び出す
    if (result != null && widget.onAdoptValue != null) {
      await widget.onAdoptValue!(result);
    }
  }

  // 個別ボードカードウィジェット
  Widget _buildBoardCard(Map<String, dynamic> card) {
    final buzzword = _extractStringValue(card['buzzword']) ?? '';
    final year = _extractIntValue(card['year']) ?? 0;
    final isAvailable = card['isAvailable'] ?? true;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxSmall),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.8,
          child: _TrendWordCardFace(
            buzzword: buzzword,
            isAvailable: isAvailable,
            onTap: isAvailable && widget.isCurrentTurn
                ? () {
                    Logger.log('カード選択: $buzzword ($year)');
                    _showCardSelectionDialog(context, card);
                  }
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardCards = widget.gameData?['boardCards'] as List<dynamic>?;

    if (boardCards == null || boardCards.isEmpty) {
      return Center(
        child: Text(
          'カード情報を読み込み中...',
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      );
    }

    const int crossAxisCount = 4;
    const double crossAxisSpacing = AppSpacing.xxSmall;
    const double gridPadding = AppSpacing.xSmall;
    const double aspectRatio = 0.8;
    const double maxCellHeight = 360.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // セル幅からアスペクト比で高さを計算し、上限でキャップ
        final cellWidth = (constraints.maxWidth -
                gridPadding * 2 -
                crossAxisSpacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final cellHeight = (cellWidth / aspectRatio).clamp(0.0, maxCellHeight);

        return GridView.builder(
          padding: const EdgeInsets.all(gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: AppSpacing.xxSmall,
            mainAxisExtent: cellHeight,
          ),
          itemCount: boardCards.length,
          itemBuilder: (context, index) {
            final card = boardCards[index] as Map<String, dynamic>;
            return _buildBoardCard(card);
          },
        );
      },
    );
  }
}

// ボード・ダイアログ共通のカード表面ウィジェット
class _TrendWordCardFace extends StatelessWidget {
  final String buzzword;
  final bool isAvailable;
  final double? fontSize;
  final VoidCallback? onTap;

  const _TrendWordCardFace({
    required this.buzzword,
    this.isAvailable = true,
    this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = isAvailable
        ? AppTextStyles.trendWordCard.copyWith(fontSize: fontSize)
        : AppTextStyles.trendWordCard.copyWith(
            color: AppTheme.secondaryTextColor,
            fontSize: fontSize,
          );
    final innerBorderColor = isAvailable
        ? AppTheme.trendWordGameWordCardBorderColor
        : AppTheme.trendWordGameDisabledColor;

    final cardContent = Padding(
      padding: const EdgeInsets.all(AppSpacing.trendWordCardInnerLine),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: innerBorderColor,
            strokeAlign: AppBorderStroke.trendWordWordCardOutline / 2,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xSmall),
            child: Text(
              buzzword,
              style: textStyle,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      color: isAvailable
          ? AppTheme.trendWordGameWordCardColor
          : AppTheme.trendWordGameBackGroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        side: BorderSide(
          color: isAvailable
              ? AppTheme.trendWordGameWordCardBorderColor
              : AppTheme.trendWordGameDisabledColor,
          width: AppBorderStroke.trendWordWordCardOutline,
        ),
      ),
      child: onTap != null
          ? InkWell(onTap: onTap, child: cardContent)
          : cardContent,
    );
  }
}

// カード選択確認ダイアログ内コンテンツ（フリップアニメーション付き）
class _CardSelectionDialogContent extends StatefulWidget {
  final Map<String, dynamic> card;
  final Future<void> Function(String cardId)? onConfirm;
  final int currentScore;
  // 復帰時など、カードが既に確定済みでフリップ済み状態から開始する場合に true
  final bool startFlipped;

  const _CardSelectionDialogContent({
    required this.card,
    this.onConfirm,
    required this.currentScore,
    this.startFlipped = false,
  });

  @override
  State<_CardSelectionDialogContent> createState() =>
      _CardSelectionDialogContentState();
}

class _CardSelectionDialogContentState
    extends State<_CardSelectionDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isLoading = false;
  bool _isFlipped = false;

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

    // 復帰時: カードが既に確定済みならアニメーションを完了状態にセット
    if (widget.startFlipped) {
      _isFlipped = true;
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 西暦から和暦の情報を取得する
  // (元号名, 元号年) のペアを返す
  ({String name, int yearNum}) _getJapaneseEraInfo(int year) {
    if (year >= 2019) return (name: '令和', yearNum: year - 2018);
    if (year >= 1989) return (name: '平成', yearNum: year - 1988);
    if (year >= 1926) return (name: '昭和', yearNum: year - 1925);
    if (year >= 1912) return (name: '大正', yearNum: year - 1911);
    return (name: '明治', yearNum: year - 1867);
  }

  String _toJapaneseEra(int year) {
    final info = _getJapaneseEraInfo(year);
    final yearStr = info.yearNum == 1 ? '元' : info.yearNum.toString();
    return '${info.name}$yearStr年';
  }

  //　西暦からスコア変換
  int _toScoreFromWesternEra(int year) {
    if (year >= 2000) {
      return year - 2000;
    } else {
      return year - 1900;
    }
  }

  // 和暦からスコア変換
  int _toScoreFromJapaneseEra(int year) {
    final info = _getJapaneseEraInfo(year);
    return info.yearNum;
  }

  // 決定ボタン押下: API実行 → 完了後にフリップアニメーション
  Future<void> _onDecide() async {
    if (_isLoading || _controller.isCompleted) return;
    final cardId = _extractStringValue(widget.card['cardId']) ?? '';
    Logger.log('カード決定: $cardId');
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm?.call(cardId);
      if (mounted) {
        setState(() => _isFlipped = true);
        _controller.forward();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 年代採用ボタン押下: valueType ('Western' or 'Japanese') をダイアログ結果として返す
  // 実際のAPI呼び出しは親コンポーネントで行われる
  void _onAdoptValue(String valueType) {
    if (_isLoading) return;
    if (mounted) {
      Navigator.of(context).pop(valueType);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final buzzword = _extractStringValue(widget.card['buzzword']) ?? '';
    final year = _extractIntValue(widget.card['year']) ?? 0;
    final japaneseEra = _toJapaneseEra(year);
    final westernScore = _toScoreFromWesternEra(year);
    final japaneseScore = _toScoreFromJapaneseEra(year);

    // スコア計算とBURST判定
    final currentScore = widget.currentScore;
    final newWesternScore = currentScore + westernScore;
    final newJapaneseScore = currentScore + japaneseScore;
    final isWesternBurst = newWesternScore > 150;
    final isJapaneseBurst = newJapaneseScore > 150;

    return PopScope(
      canPop: !_isFlipped,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isFlipped ? 'どちらの年代を採用しますか？' : 'このカードに決定しますか？',
            style: AppTextStyles.subtitle2,
          ),
          const SizedBox(height: AppSpacing.medium),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) {
              final value = _animation.value;
              final isFlipped = value >= 0.5;
              // 表面: 0 → π/2、裏面: -π/2 → 0
              final angle = isFlipped ? (value - 1) * pi : value * pi;
              return GestureDetector(
                onTap: () {},
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // パース設定
                    ..rotateY(angle),
                  child: isFlipped
                      ? _buildBackFace(year, japaneseEra)
                      : _buildFrontFace(buzzword),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.large),
          _isFlipped
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedLoadingButton(
                            onPressed: () => _onAdoptValue('Western'),
                            isLoading: _isLoading,
                            child: Column(
                              children: [
                                Text('西暦を採用（$westernScore点）',
                                    style: AppTextStyles.subtitle
                                        .copyWith(color: Colors.white)),
                                RichText(
                                  text: TextSpan(
                                      style: AppTextStyles.caption
                                          .copyWith(color: Colors.white),
                                      children: [
                                        TextSpan(
                                          text:
                                              '$currentScore点 → $newWesternScore点',
                                        ),
                                        isWesternBurst
                                            ? TextSpan(
                                                text: ' BURST!',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                        color: AppTheme
                                                            .error2Color,
                                                        fontWeight:
                                                            FontWeight.bold),
                                              )
                                            : const TextSpan(text: ''),
                                      ]),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedLoadingButton(
                            onPressed: () => _onAdoptValue('Japanese'),
                            isLoading: _isLoading,
                            child: Column(
                              children: [
                                Text('和暦を採用（$japaneseScore点）',
                                    style: AppTextStyles.subtitle
                                        .copyWith(color: Colors.white)),
                                RichText(
                                  text: TextSpan(
                                      style: AppTextStyles.caption
                                          .copyWith(color: Colors.white),
                                      children: [
                                        TextSpan(
                                          text:
                                              '$currentScore点 → $newJapaneseScore点',
                                        ),
                                        isJapaneseBurst
                                            ? TextSpan(
                                                text: ' BURST!',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                        color: AppTheme
                                                            .error2Color,
                                                        fontWeight:
                                                            FontWeight.bold),
                                              )
                                            : const TextSpan(text: ''),
                                      ]),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'キャンセル',
                          style: AppTextStyles.body
                              .copyWith(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.large),
                    Expanded(
                      child: ElevatedLoadingButton(
                        onPressed: _onDecide,
                        isLoading: _isLoading,
                        text: '決定',
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCardSized({required Widget child}) {
    const double aspectRatio = 0.7;
    const double maxHeight = 240.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredWidth = constraints.maxWidth * 0.6;
        final desiredHeight = desiredWidth / aspectRatio;
        final height = desiredHeight.clamp(0.0, maxHeight);
        final width = height * aspectRatio;
        return SizedBox(width: width, height: height, child: child);
      },
    );
  }

  Widget _buildFrontFace(String buzzword) {
    return _buildCardSized(
      child: _TrendWordCardFace(buzzword: buzzword, fontSize: 20),
    );
  }

  Widget _buildBackFace(int year, String japaneseEra) {
    return _buildCardSized(
      child: Card(
        margin: EdgeInsets.zero,
        color: AppTheme.trendWordGameWordCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          side: const BorderSide(
            color: AppTheme.trendWordGameWordCardBorderColor,
            width: AppBorderStroke.trendWordWordCardOutline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.trendWordCardInnerLine),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.trendWordGameWordCardInnerBorderColor,
                strokeAlign: AppBorderStroke.trendWordWordCardOutline / 2,
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '西暦',
                      style: AppTextStyles.trendWordCard
                          .copyWith(color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: AppSpacing.xSmall,
                    ),
                    Text(
                      '$year年',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const Divider(
                  color: AppTheme.trendWordGameWordCardInnerBorderColor,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '和暦',
                      style: AppTextStyles.trendWordCard
                          .copyWith(color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: AppSpacing.xSmall,
                    ),
                    Text(
                      japaneseEra,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 手番でないプレイヤー向け: 相手が選んだカードを観戦するダイアログ
class _WatchCardDialogContent extends StatefulWidget {
  final Map<String, dynamic> card;
  // フリップ後に手動クローズされたときに呼ばれるコールバック（競合状態防止用）
  final VoidCallback? onManualClose;

  const _WatchCardDialogContent({
    required this.card,
    this.onManualClose,
  });

  @override
  State<_WatchCardDialogContent> createState() =>
      _WatchCardDialogContentState();
}

class _WatchCardDialogContentState extends State<_WatchCardDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isFlipped = false;

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

    // フリップ完了を検知して手動クローズを許可
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _isFlipped = true);
      }
    });

    // 少し遅延してから裏返す（AnimatedBuilderが変化を自動検知）
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({String name, int yearNum}) _getJapaneseEraInfo(int year) {
    if (year >= 2019) return (name: '令和', yearNum: year - 2018);
    if (year >= 1989) return (name: '平成', yearNum: year - 1988);
    if (year >= 1926) return (name: '昭和', yearNum: year - 1925);
    if (year >= 1912) return (name: '大正', yearNum: year - 1911);
    return (name: '明治', yearNum: year - 1867);
  }

  String _toJapaneseEra(int year) {
    final info = _getJapaneseEraInfo(year);
    final yearStr = info.yearNum == 1 ? '元' : info.yearNum.toString();
    return '${info.name}$yearStr年';
  }

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

  @override
  Widget build(BuildContext context) {
    final buzzword = _extractStringValue(widget.card['buzzword']) ?? '';
    final year = _extractIntValue(widget.card['year']) ?? 0;
    final japaneseEra = _toJapaneseEra(year);

    return PopScope(
      canPop: _isFlipped,
      onPopInvokedWithResult: (didPop, _) {
        // 同期的にフラグをリセットすることでタイマーとの競合状態を防ぐ
        if (didPop) widget.onManualClose?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '相手がカードを選択しました',
            style: AppTextStyles.subtitle2,
          ),
          const SizedBox(height: AppSpacing.medium),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) {
              final value = _animation.value;
              final isFlipped = value >= 0.5;
              final angle = isFlipped ? (value - 1) * pi : value * pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFlipped
                    ? _buildBackFace(year, japaneseEra)
                    : _buildFrontFace(buzzword),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardSized({required Widget child}) {
    const double aspectRatio = 0.7;
    const double maxHeight = 240.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredWidth = constraints.maxWidth * 0.6;
        final desiredHeight = desiredWidth / aspectRatio;
        final height = desiredHeight.clamp(0.0, maxHeight);
        final width = height * aspectRatio;
        return SizedBox(width: width, height: height, child: child);
      },
    );
  }

  Widget _buildFrontFace(String buzzword) {
    return _buildCardSized(
      child: _TrendWordCardFace(buzzword: buzzword, fontSize: 20),
    );
  }

  Widget _buildBackFace(int year, String japaneseEra) {
    return _buildCardSized(
      child: Card(
        margin: EdgeInsets.zero,
        color: AppTheme.trendWordGameWordCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          side: const BorderSide(
            color: AppTheme.trendWordGameWordCardBorderColor,
            width: AppBorderStroke.trendWordWordCardOutline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.trendWordCardInnerLine),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.trendWordGameWordCardInnerBorderColor,
                strokeAlign: AppBorderStroke.trendWordWordCardOutline / 2,
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '西暦',
                      style: AppTextStyles.trendWordCard
                          .copyWith(color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      '$year年',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const Divider(
                  color: AppTheme.trendWordGameWordCardInnerBorderColor,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '和暦',
                      style: AppTextStyles.trendWordCard
                          .copyWith(color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      japaneseEra,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 結果発表ダイアログ用のローカルデータクラス
class _ResultEntry {
  final String uid;
  final String nickname;
  final int lastScore;
  final bool isCurrentUser;
  final bool isHost;
  final bool isBurst;
  final int rank;

  const _ResultEntry({
    required this.uid,
    required this.nickname,
    required this.lastScore,
    required this.isCurrentUser,
    required this.isHost,
    this.isBurst = false,
    this.rank = 1,
  });

  _ResultEntry copyWith({int? rank}) => _ResultEntry(
        uid: uid,
        nickname: nickname,
        lastScore: lastScore,
        isCurrentUser: isCurrentUser,
        isHost: isHost,
        isBurst: isBurst,
        rank: rank ?? this.rank,
      );
}

// 結果発表ダイアログコンテンツ
class _TrendWordResultDialogContent extends ConsumerStatefulWidget {
  final bool isWin;
  final String roomId;
  final VoidCallback onExitPressed;

  const _TrendWordResultDialogContent({
    required this.isWin,
    required this.roomId,
    required this.onExitPressed,
  });

  @override
  ConsumerState<_TrendWordResultDialogContent> createState() =>
      _TrendWordResultDialogContentState();
}

class _TrendWordResultDialogContentState
    extends ConsumerState<_TrendWordResultDialogContent> {
  bool _isPreparationCompleted = false;
  bool _isUpdatingReady = false;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (widget.isWin) {
      // 少し遅延させてダイアログ表示後に紙吹雪を開始
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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

  Future<void> _onReplayPressed() async {
    final user = ref.read(userProvider);
    final gameId = ref.read(currentGameProvider).gameId;
    final uid = user.uid;

    if (uid == null || gameId == null) return;

    setState(() => _isUpdatingReady = true);
    try {
      await ApiService.setReady(context, widget.roomId, uid, gameId);
      if (mounted) setState(() => _isPreparationCompleted = true);
    } catch (e) {
      Logger.log('リプレイ準備エラー: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingReady = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGame = ref.watch(currentGameProvider);
    final currentUser = ref.watch(userProvider);
    final isHost = ref.watch(isHostProvider);
    final roomSnapshot = ref.watch(roomStreamProvider(widget.roomId));
    final gameData = currentGame.gameData;

    // winnerId で勝者を判定
    final winnerId = _extractStringValue(gameData?['winnerId']);

    // roomStreamProvider + gameData からプレイヤーリストを構築
    final resultPlayers = roomSnapshot.when(
      data: (snapshot) {
        if (!snapshot.exists) return <_ResultEntry>[];

        final roomData = snapshot.data() as Map<String, dynamic>?;
        final roomPlayersMap =
            roomData?['players'] as Map<String, dynamic>? ?? {};
        final hostPlayer = roomData?['hostPlayer'] as String?;
        final playersGameData =
            gameData?['players'] as Map<String, dynamic>? ?? {};

        List<_ResultEntry> players = [];

        // 人間プレイヤー
        for (final entry in roomPlayersMap.entries) {
          final uid = entry.key;
          final roomPlayerData = entry.value as Map<String, dynamic>;
          final gamePlayerData = playersGameData[uid] as Map<String, dynamic>?;

          final nickname =
              _extractStringValue(roomPlayerData['nickname']) ?? '名無し';
          final lastScore = _extractIntValue(gamePlayerData?['lastScore']) ?? 0;
          final isBurst = gamePlayerData?['isBurst'] == true;

          players.add(_ResultEntry(
            uid: uid,
            nickname: nickname,
            lastScore: lastScore,
            isCurrentUser: uid == currentUser.uid,
            isHost: uid == hostPlayer,
            isBurst: isBurst,
          ));
        }

        // CPUプレイヤー（roomPlayersMapに存在しないUID）
        for (final entry in playersGameData.entries) {
          final uid = entry.key;
          if (roomPlayersMap.containsKey(uid)) continue;

          final gamePlayerData = entry.value as Map<String, dynamic>?;
          final nickname =
              _extractStringValue(gamePlayerData?['nickname']) ?? 'CPU';
          final lastScore = _extractIntValue(gamePlayerData?['lastScore']) ?? 0;
          final isBurst = gamePlayerData?['isBurst'] == true;

          players.add(_ResultEntry(
            uid: uid,
            nickname: nickname,
            lastScore: lastScore,
            isCurrentUser: false,
            isHost: false,
            isBurst: isBurst,
          ));
        }

        // 勝者を1番上、以降はlastScore降順（同点はホスト優先）
        players.sort((a, b) {
          if (a.uid == winnerId) return -1;
          if (b.uid == winnerId) return 1;
          if (a.lastScore != b.lastScore) {
            return b.lastScore.compareTo(a.lastScore);
          }
          if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
          return 0;
        });

        // 順位計算
        List<_ResultEntry> ranked = [];
        int currentRank = 1;
        for (int i = 0; i < players.length; i++) {
          if (i > 0 && players[i].lastScore != players[i - 1].lastScore) {
            currentRank = i + 1;
          }
          ranked.add(players[i].copyWith(rank: currentRank));
        }

        return ranked;
      },
      loading: () => <_ResultEntry>[],
      error: (_, __) => <_ResultEntry>[],
    );

    // targetScore を assets/config から取得（CPU 含む全プレイヤー数で参照）
    final playersGameData = gameData?['players'] as Map<String, dynamic>? ?? {};
    final totalPlayerCount = playersGameData.length;
    final assetsConfig =
        gameData?['assets']?['config'] as Map<String, dynamic>?;
    final playerConfig =
        assetsConfig?[totalPlayerCount.toString()] as Map<String, dynamic>?;
    final targetScore = (playerConfig?['targetScore'] as num?)?.toInt();

    // 全員同点かどうか判定
    final isDraw = resultPlayers.length > 1 &&
        resultPlayers
            .every((p) => p.lastScore == resultPlayers.first.lastScore);

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WIN / LOSE / DRAW バッジ
              Text(
                isDraw ? 'DRAW' : (widget.isWin ? 'WIN' : 'LOSE'),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: AppTheme.primaryColor),
              ),

              const SizedBox(height: AppSpacing.medium),

              // プレイヤーリスト（残り高さを占有）
              Expanded(
                child: resultPlayers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: resultPlayers.length,
                        itemBuilder: (_, index) {
                          final player = resultPlayers[index];
                          return _buildResultCard(
                              player, player.uid == winnerId, targetScore,
                              isDraw: isDraw);
                        },
                      ),
              ),

              const SizedBox(height: AppSpacing.medium),

              // もう一度遊ぶボタン
              ElevatedLoadingButton(
                text: _isPreparationCompleted ? '他プレイヤー待ち' : 'もう一度遊ぶ',
                isLoading: _isUpdatingReady,
                onPressed: _isPreparationCompleted || _isUpdatingReady
                    ? null
                    : _onReplayPressed,
              ),
              if (isHost) ...[
                const SizedBox(height: AppSpacing.small),
                // ゲーム終了ボタン（ホストのみ表示）
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(analyticsServiceProvider)
                        .logClick(button: 'game_quit');
                    widget.onExitPressed();
                  },
                  child: const Text('ゲームを終了する'),
                ),
              ],
            ],
          ),
          // 勝利時の紙吹雪アニメーション
          if (widget.isWin)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 20,
                maxBlastForce: 30,
                minBlastForce: 10,
                emissionFrequency: 0.06,
                gravity: 0.2,
                colors: const [
                  Color(0xFFE07000),
                  Color(0xFFFFD700),
                  Color(0xFFFF6B6B),
                  Color(0xFF4ECDC4),
                  Color(0xFFFFE66D),
                  Color(0xFFFF8C42),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_ResultEntry player, bool isWinner, int? targetScore,
      {bool isDraw = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      elevation: AppElevation.none,
      color: AppTheme.trendWordGameResultPlayerCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Row(
          children: [
            // 勝利したプレイヤーのみに王冠を表示
            SizedBox(
              width: AppIconSizes.winnerCrownIcon,
              height: AppIconSizes.winnerCrownIcon,
              child: isWinner
                  ? const Text('👑',
                      style: TextStyle(fontSize: AppTextStyles.h5FontSize))
                  : player.isBurst
                      ? const Text('🔥',
                          style: TextStyle(fontSize: AppTextStyles.h5FontSize))
                      : null,
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        player.nickname,
                        style: AppTextStyles.subtitle2
                            .copyWith(color: AppTheme.secondaryTextColor),
                      ),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${player.lastScore}',
                          style: AppTextStyles.h5.copyWith(
                            color: player.isCurrentUser
                                ? AppTheme.trendWordGamePlayerColor
                                : AppTheme.trendWordGameOpponentColor,
                          ),
                        ),
                        if (targetScore != null)
                          TextSpan(
                            text: ' / $targetScore',
                            style: AppTextStyles.subtitle2.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                      ],
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
}
