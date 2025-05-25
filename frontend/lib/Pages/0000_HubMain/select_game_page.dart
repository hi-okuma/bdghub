import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/components/game_list_widget.dart';
import '/components/custom_widgets.dart';
import '/components/app_theme.dart';
import '/Pages/0000_HubMain/game_detail_page.dart';
import '/utils/game_service.dart';
import '/providers/user_provider.dart';
import '/providers/room_provider.dart';
import 'package:bodogehub/models/user_state.dart';

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

  final List<Tab> _tabs = const <Tab>[
    Tab(text: '全て'),
    Tab(text: '定番'),
    Tab(text: 'カード'),
    Tab(text: '協力'),
  ];

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
            case 2:
              _selectedGenre = {GameGenre.card};
              break;
            case 3:
              _selectedGenre = {GameGenre.cooperation};
              break;
          }
        });
      }
    });

    _fetchGames();
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
      print('ゲームデータの取得エラー: $e');
      setState(() {
        _gameList = getDummyGames();
        _isGameLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyRoomUrl() {
    final roomId = ref.read(currentRoomIdProvider);
    if (roomId == null) return;

    String shareUrl = 'https://bdghub.web.app/?roomId=$roomId';
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
    final playersAsync =
        ref.watch(roomStreamProvider(roomId)); // AsyncValue<DocumentSnapshot>

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('部屋: $roomId'),
        leading: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.small, horizontal: AppSpacing.xSmall),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
            ),
            onPressed: _showExitDialog,
            child: const Text(
              '退出',
              style: TextStyle(
                color: Colors.black,
                fontSize: AppTextStyles.captionFontSize,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.small, horizontal: AppSpacing.xSmall),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[200],
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                ),
              ),
              onPressed: _copyRoomUrl,
              child: const Text(
                'URLをコピー',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: AppTextStyles.captionFontSize,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.small),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 参加者エリア
          Container(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '参加者',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                // ★ ここを修正 ★
                playersAsync.when(
                  data: (snapshot) {
                    if (!snapshot.exists) {
                      return Text(
                        '部屋が見つかりません',
                        style: AppTextStyles.errorText,
                      );
                    }

                    final data = snapshot.data() as Map<String, dynamic>?;
                    final playersData =
                        data?['players'] as List<dynamic>? ?? [];

                    if (playersData.isEmpty) {
                      return Text(
                        '参加者がいません',
                        style: AppTextStyles.body,
                      );
                    }

                    final players = playersData.asMap().entries.map((entry) {
                      return Player(
                        nickname: entry.value.toString(),
                        isHost: entry.key == 0,
                      );
                    }).toList();
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
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    'データの取得中にエラーが発生しました',
                    style: AppTextStyles.errorText,
                  ),
                ),
              ],
            ),
          ),

          // タブバー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
            child: CustomTabBar(
              controller: _tabController,
              tabs: _tabs,
            ),
          ),

          // ゲーム一覧（タブビュー）
          Expanded(
            child: _isGameLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : TabBarView(
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
                      GameListWidget(
                        games: _gameList.where((game) {
                          if (game['genre'] is List) {
                            List<GameGenre> genres =
                                List<GameGenre>.from(game['genre']);
                            return genres.contains(GameGenre.card);
                          }
                          return game['genre'] == GameGenre.card;
                        }).toList(),
                        onGameSelected: _onGameSelected,
                      ),
                      GameListWidget(
                        games: _gameList.where((game) {
                          if (game['genre'] is List) {
                            List<GameGenre> genres =
                                List<GameGenre>.from(game['genre']);
                            return genres.contains(GameGenre.cooperation);
                          }
                          return game['genre'] == GameGenre.cooperation;
                        }).toList(),
                        onGameSelected: _onGameSelected,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('部屋から退出しますか？'),
          actions: [
            LoadingButton(
              text: 'キャンセル',
              isLoading: false,
              isElevated: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
            LoadingButton(
              text: '退出する',
              isLoading: false,
              onPressed: () {
                Navigator.of(context).pop();
                _leaveRoom();
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

      print('🚪 退出開始: ${userState.nickname} が部屋 ${userState.roomId} から退出');

      // API呼び出しで退出処理
      final Uri apiUrl = Uri.parse(
          'https://asia-northeast1-bdghub-dev.cloudfunctions.net/leaveRoom');
      final Map<String, dynamic> requestBody = {
        'nickname': userState.nickname,
        'roomId': userState.roomId,
      };

      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('success') &&
            responseData['success'] == false) {
          // エラーハンドリング
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'エラーが発生しました')),
          );
          return;
        }

        print('🚪 API退出成功');

        // 画面遷移を先に実行
        if (!mounted) return;
        Navigator.of(context).pop();

        // Firestoreの更新完了を待つ方法（オプション）
        await ref.read(roomStreamProvider(userState.roomId!).future);

        // ★ 状態クリアは最後に実行 ★
        ref.read(userProvider.notifier).leaveRoom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('部屋を退出しました')),
          );
        }
      } else {
        print('🚪 API退出失敗: ${response.statusCode}');
        // HTTPエラーハンドリング
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出に失敗しました: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('🚪 退出エラー: $e');
      // 通信エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通信エラー: $e')),
      );
    }
  }
}
