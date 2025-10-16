import 'package:bodogehub/utils/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/components/game_list_widget.dart';
import '/components/custom_widgets.dart';
import '/components/app_theme.dart';
import 'top_page.dart';
import 'package:bodogehub/models/game_enums.dart';
import '/Pages/0000_HubMain/game_detail_page.dart';
import '/utils/game_service.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';
import '/providers/game_state_provider.dart';
import '/services/api_service.dart';

class SelectGamePage extends ConsumerStatefulWidget {
  const SelectGamePage({Key? key}) : super(key: key);

  @override
  ConsumerState<SelectGamePage> createState() => _SelectGamePageState();
}

class _SelectGamePageState extends ConsumerState<SelectGamePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _gameList = [];
  bool _isGameLoading = true;
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  final List<CustomTab> _tabs = const <CustomTab>[
    CustomTab(label: '全て'),
    CustomTab(label: '定番'),
    // CustomTab(label: 'カード'),
    // CustomTab(label: '協力'),
  ];

  bool _isFromGameExit = false; // ★追加: ゲーム終了からの遷移かどうか

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedGenre = {GameGenre.all};
              break;
            case 1:
              _selectedGenre = {GameGenre.popular};
              break;
            // case 2:
            //   _selectedGenre = {GameGenre.card};
            //   break;
            // case 3:
            //   _selectedGenre = {GameGenre.cooperation};
            //   break;
          }
        });
      }
    });

    _fetchGames();

    // ★修正: ゲーム状態監視の開始を条件付きに ★
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGameStateMonitoringConditionally();
    });
  }

  Future<void> _fetchGames() async {
    setState(() {
      _isGameLoading = true;
    });

    try {
      final games = await fetchGamesFromFirestore();
      setState(() {
        _gameList = games;
        _isGameLoading = false;
      });
    } catch (e) {
      Logger.log('ゲームデータの取得エラー: $e');
      setState(() {
        _gameList = getDummyGames();
        _isGameLoading = false;
      });
    }
  }

  // ★追加: 条件付きでゲーム状態監視を開始 ★
  void _startGameStateMonitoringConditionally() {
    final userState = ref.read(userProvider);
    final roomId = userState.roomId;

    if (roomId == null || roomId.isEmpty) {
      Logger.log('❌ roomIdが無効なため、ゲーム状態監視を開始できません');
      return;
    }

    // ★追加: room statusをチェックしてから監視開始 ★
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get()
        .then((doc) {
      if (!doc.exists) {
        Logger.log('❌ 部屋が存在しないため、ゲーム状態監視を開始しません');
        return;
      }

      final data = doc.data() as Map<String, dynamic>?;
      final roomStatus = data?['status'] as String?;

      Logger.log('🔍 Room status確認: $roomStatus');

      // inProgressの場合のみ監視開始
      if (roomStatus == 'inProgress') {
        Logger.log('🔍 ゲーム状態監視を開始: $roomId');
        ref.read(roomGameStateProvider(roomId));
      } else {
        Logger.log('🔍 Room status is $roomStatus - ゲーム状態監視は開始しません');
      }
    }).catchError((error) {
      Logger.log('❌ Room status確認エラー: $error');
    });
  }

  @override
  void dispose() {
    // ★ 注意：dispose内ではrefを使用できません ★
    // ゲーム状態監視の停止は UserNotifier.leaveRoom() で行われます

    _tabController.dispose();
    super.dispose();
  }

  void _copyRoomUrl() {
    final roomId = ref.read(currentRoomIdProvider);
    if (roomId == null) return;

    String shareUrl = dotenv.env['SHARE_URL']! + '$roomId';
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('URLをコピーしました'),
          duration: AppAnimations.snackBarDuration,
        ),
      );
    });
  }

  void _onGameSelected(Map<String, dynamic> game) {
    final roomId = ref.read(currentRoomIdProvider);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameDetailPage(
          game: game,
          gameId: game['gameId'],
          roomId: roomId,
          isFromRoom: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final roomId = userState.roomId ?? '';

    // ★ デバッグ用：currentGameサブコレクションの直接確認 ★
    if (roomId.isNotEmpty && kDebugMode) {
      // currentGameサブコレクションを直接監視（デバッグ用）
      final currentGameStream = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('currentGame')
          .snapshots();

      // StreamBuilderでデバッグ情報を表示
      StreamBuilder<QuerySnapshot>(
        stream: currentGameStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            Logger.log(
                '🔍 DEBUG: currentGame docs count: ${snapshot.data!.docs.length}');
            for (var doc in snapshot.data!.docs) {
              Logger.log('🔍 DEBUG: gameId=${doc.id}, data=${doc.data()}');
            }
          }
          return const SizedBox.shrink(); // 非表示ウィジェット
        },
      );
    }

    // ★修正: ゲーム状態監視とリスナーの設定 ★
    if (roomId.isNotEmpty) {
      final gameStateAsync = ref.watch(roomGameStateProvider(roomId));

      // デバッグ用：現在の状態をリアルタイム表示
      gameStateAsync.whenOrNull(
        data: (status) {
          Logger.log('🎮 現在のゲーム状態: $status');

          final isHost = ref.read(isHostProvider);
          Logger.log('🎮 プレイヤー種別: ${isHost ? "ホスト" : "子プレイヤー"}');
        },
        loading: () => Logger.log('🔄 ゲーム状態読み込み中...'),
        error: (error, _) => Logger.log('❌ ゲーム状態エラー: $error'),
      );

      // ★修正: リスナーで適切な状態変化のみ処理 ★
      ref.listen(roomGameStateProvider(roomId), (previous, next) {
        // previousがnullの場合（初回読み込み）はスキップ
        if (previous == null) {
          Logger.log('🎮 初回読み込みのためリスナーをスキップ');
          return;
        }

        next.whenOrNull(
          data: (status) {
            final nickname = userState.nickname ?? "Unknown";
            Logger.log('🎮 [$nickname] ゲーム状態変化: $previous → $status');

            // ★修正: 実際に状態が変化した場合のみ処理 ★
            final previousStatus = previous?.valueOrNull;
            if (previousStatus == status) {
              Logger.log('🎮 [$nickname] 同じ状態のため処理をスキップ: $status');
              return;
            }

            // playingになった場合のみGameTitlePageに遷移
            if (status == GameStatus.playing) {
              Logger.log('🎮 [$nickname] GameTitlePageに遷移します！');
              // NavigationServiceで自動遷移される
            } else if (status == GameStatus.waiting &&
                previousStatus != GameStatus.waiting) {
              Logger.log(
                  '🎮 [$nickname] ゲーム終了を検知しましたが、既にSelectGamePageにいるためスキップ');
            }
          },
          error: (error, stackTrace) {
            Logger.log('❌ [${userState.nickname}] ゲーム状態監視エラー: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ゲーム状態の監視エラー: $error')),
            );
          },
        );
      });
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '部屋コード',
                style: AppTextStyles.caption,
              ),
              Text(
                roomId,
                style: AppTextStyles.title,
              ),
            ],
          ),
          leadingWidth: 105,
          leading: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _showExitDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.logout,
                  color: AppTheme.primaryColor,
                  size: AppIconSizes.xSmall,
                ),
                const SizedBox(width: AppSpacing.small),
                const Text(
                  '退出する',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: AppTextStyles.subtitle2FontSize,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large, vertical: AppSpacing.medium),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _copyRoomUrl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link,
                    color: Colors.white,
                    size: AppIconSizes.medium,
                  ),
                  SizedBox(
                    width: AppSpacing.small,
                  ),
                  const Text(
                    'URL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTextStyles.subtitle2FontSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 戻る処理、リロードに関する不具合アラート
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium, horizontal: AppSpacing.large),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.errorBackgroundColor,
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.error1Color,
                      ),
                      SizedBox(
                        width: AppSpacing.small,
                      ),
                      Expanded(child: Text('リロードや戻る操作をすると部屋を退出してしまう場合があります')),
                    ],
                  ),
                ),
              ),
            ),

            // 参加者エリア
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium, horizontal: AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '参加者',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  // playersProvider を使用して、プレイヤーリストを一貫した方法で取得する
                  Consumer(builder: (context, ref, _) {
                    // roomIdが空の場合は playersProvider を watch しない
                    if (roomId.isEmpty) {
                      return Text(
                        'ルームIDが見つかりません',
                        style: AppTextStyles.errorText,
                      );
                    }

                    final players = ref.watch(playersProvider(roomId));

                    if (players.isEmpty) {
                      return Text(
                        '参加者がいません',
                        style: AppTextStyles.body,
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: players.map((player) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.small),
                            child: PlayerBadge(
                              nickname: player.nickname,
                              isHost: player.isHost,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // タブバー
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium, horizontal: AppSpacing.large),
              child: CustomTabBar(
                controller: _tabController,
                tabs: _tabs,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium, horizontal: AppSpacing.large),
              child: Text(
                'ゲーム一覧',
                style: AppTextStyles.title,
              ),
            ),

            // ゲーム一覧（タブビュー）
            Expanded(
              child: _isGameLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const PageScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        children: [
                          GameListWidget(
                            games: _gameList,
                            onGameSelected: _onGameSelected,
                          ),
                          GameListWidget(
                            games: _gameList.where((game) {
                              if (game['genre'] is List) {
                                List<GameGenre> genres =
                                    List<GameGenre>.from(game['genre']);
                                return genres.contains(GameGenre.popular);
                              }
                              return game['genre'] == GameGenre.popular;
                            }).toList(),
                            onGameSelected: _onGameSelected,
                          ),
                          // GameListWidget(
                          //   games: _gameList.where((game) {
                          //     if (game['genre'] is List) {
                          //       List<GameGenre> genres =
                          //           List<GameGenre>.from(game['genre']);
                          //       return genres.contains(GameGenre.card);
                          //     }
                          //     return game['genre'] == GameGenre.card;
                          //   }).toList(),
                          //   onGameSelected: _onGameSelected,
                          // ),
                          // GameListWidget(
                          //   games: _gameList.where((game) {
                          //     if (game['genre'] is List) {
                          //       List<GameGenre> genres =
                          //           List<GameGenre>.from(game['genre']);
                          //       return genres.contains(GameGenre.cooperation);
                          //     }
                          //     return game['genre'] == GameGenre.cooperation;
                          //   }).toList(),
                          //   onGameSelected: _onGameSelected,
                          // ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
            child: Text(
              '部屋から退出しますか？',
              style: AppTextStyles.body,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'キャンセル',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                )),
            TextLoadingButton(
              text: '退出する',
              isLoading: false,
              onPressed: () {
                _leaveRoom();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _leaveRoom() async {
    try {
      final userState = ref.read(userProvider);
      if (userState.roomId == null || userState.uid == null) {
        Logger.log('🚪 退出エラー: roomId or uid is null');
        return;
      }

      Logger.log('🚪 退出開始: ${userState.nickname} が部屋 ${userState.roomId} から退出');

      // ApiServiceを使用して退出処理
      await ApiService.leaveRoom(
        context,
        userState.roomId!,
        userState.uid!,
      );

      Logger.log('🚪 API退出成功');

      // 状態クリアを先に実行
      ref.read(userProvider.notifier).leaveRoom();

      // ★ 修正: TopPageに直接遷移（全スタッククリア） ★
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const TopPage(),
        ),
        (route) => false, // 全ての前のルートを削除
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('部屋を退出しました')),
        );
      }
    } catch (e) {
      Logger.log('🚪 退出エラー: $e');
      // エラーダイアログはErrorHandlerで表示される
    }
  }
}
