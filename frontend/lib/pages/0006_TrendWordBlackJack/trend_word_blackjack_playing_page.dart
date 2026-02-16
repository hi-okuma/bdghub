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
  bool _isConfirmingCard = false;
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
                child: BoardGridSection(gameData: gameData),
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

// ボードグリッドセクション（スクロール対応フェード付き）
class BoardGridSection extends StatefulWidget {
  final Map<String, dynamic>? gameData;

  const BoardGridSection({super.key, this.gameData});

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

  // 個別ボードカードウィジェット
  Widget _buildBoardCard(Map<String, dynamic> card) {
    final buzzword = _extractStringValue(card['buzzword']) ?? '';
    final year = _extractIntValue(card['year']) ?? 0;
    final isAvailable = card['isAvailable'] ?? true;
    return Card(
      margin: const EdgeInsets.all(AppSpacing.xSmall),
      color: AppTheme.trendWordGameWordCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        side: const BorderSide(
          color: AppTheme.trendWordGameWordCardBorderColor,
          width: AppBorderStroke.trendWordWordCardOutline,
        ),
      ),
      child: InkWell(
        onTap: isAvailable
            ? () {
                // TODO: カード選択処理
                Logger.log('カード選択: $buzzword ($year)');
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.trendWordCardInnerLine),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFFEAE4D9),
                  strokeAlign: AppBorderStroke.trendWordWordCardOutline / 2),
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xSmall),
                  child: Text(
                    buzzword,
                    style: AppTextStyles.trendWordCard,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.xSmall),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpacing.xxSmall,
        mainAxisSpacing: AppSpacing.xxSmall,
        childAspectRatio: 0.7,
      ),
      itemCount: boardCards.length,
      itemBuilder: (context, index) {
        final card = boardCards[index] as Map<String, dynamic>;
        return _buildBoardCard(card);
      },
    );
  }
}
