import 'dart:math' show pi;

import 'package:bodogehub/utils/logger.dart';
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

    // --- ガード: gameData null check ---
    if (currentGame.gameData == null || currentGame.gameData!.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
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

    // --- maxCardCount を取得（デフォルト5枚） ---
    final maxCardCount = _extractIntValue(gameData?['maxCardCount']) ?? 5;

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
              padding: const EdgeInsets.all(AppSpacing.medium),
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
                      crossAxisAlignment: CrossAxisAlignment.start, // 高さを揃える
                      children: [
                        // for文を使って直接Widgetを展開
                        for (final player in gamePlayers)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildPlayerCard(
                                  player, maxCardCount, currentTurnPlayerUid),
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

  // プレイヤーカードウィジェット
  Widget _buildPlayerCard(TrendWordBlackJackPlayer player, int maxCardCount,
      String? currentTurnPlayerUid) {
    // 現在の手番プレイヤーかどうかを判定
    final isCurrentTurn = player.uid == currentTurnPlayerUid;

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
              vertical: AppSpacing.small, horizontal: AppSpacing.large),
          child: Column(
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
              Text(
                player.score.toString(),
                style: AppTextStyles.h3.copyWith(
                  height: 1.1,
                  color: Colors.white,
                  textBaseline: TextBaseline.ideographic,
                ),
              ),
              const SizedBox(
                height: AppSpacing.xSmall,
              ),
              // カード数をドットで表示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  maxCardCount,
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
              Text(
                'あと${150 - player.score}',
                style: AppTextStyles.subtitle2
                    .copyWith(color: AppTheme.secondaryTextColor),
              ),
            ],
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
          horizontal: screenWidth * 0.2,
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
      padding: const EdgeInsets.all(AppSpacing.xSmall),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.7,
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
    const double aspectRatio = 0.7;
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
              maxLines: 2,
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

  const _CardSelectionDialogContent({
    required this.card,
    this.onConfirm,
    required this.currentScore,
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

    return Column(
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
                                                      color:
                                                          AppTheme.error2Color,
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
                                                      color:
                                                          AppTheme.error2Color,
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
                  color: AppTheme.trendWordGameWordCardBackFaceDivider,
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
