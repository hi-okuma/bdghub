import 'RegisterProfilePage.dart';
import '../components/GameListWidget.dart';
import '../components/custom_widgets.dart';
import '../components/app_theme.dart';
import 'package:bodogehub/Util/Util.dart';
import 'package:flutter/material.dart';
import 'package:bodogehub/Pages/GameDetailPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopPage extends StatefulWidget {
  final String? roomId;

  const TopPage({super.key, this.roomId});

  @override
  State<TopPage> createState() => _TopPageState();
}

class _TopPageState extends State<TopPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> games = [];
  String selectedFilter = 'すべて';

  late TabController _tabController;
  List<Map<String, dynamic>> _gameList = [];
  bool _isGameLoading = true;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMaintenance = false;
  String _maintenanceMessage = '';
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  final List<Tab> tabs = const <Tab>[
    Tab(text: '全て'),
    Tab(text: '定番'),
    Tab(text: 'カード'),
    Tab(text: '協力'),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.roomId != null && widget.roomId!.isNotEmpty) {
        _showJoinRoomDialog(widget.roomId!);
      }
    });

    _tabController = TabController(length: tabs.length, vsync: this);

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
    _fetchGlobalConfig();
  }

  void _showJoinRoomDialog(String roomId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.only(
              top: 80,
              left: AppSpacing.large,
              right: AppSpacing.large,
              bottom: AppSpacing.large),
          child: SingleChildScrollView(
            child: RegisterProfilePage(
              isJoiningRoom: true,
              initialRoomId: roomId,
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchGlobalConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('serviceConfig')
          .doc('global')
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('maintenance')) {
          Map<String, dynamic> globalConfig = data['maintenance'];
          setState(() {
            _isMaintenance = globalConfig['isMaintenance'] ?? false;
            _maintenanceMessage = globalConfig['maintenanceMessage'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isMaintenance = false;
            _maintenanceMessage = '';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isMaintenance = false;
          _maintenanceMessage = '';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'データの取得中にエラーが発生しました';
        print('Firestoreエラー: $error');
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredGames {
    if (_selectedGenre.contains(GameGenre.all)) {
      return _gameList;
    } else {
      return _gameList.where((game) {
        if (game['genre'] is List) {
          List<GameGenre> genres = List<GameGenre>.from(game['genre']);
          return genres.any((genre) => _selectedGenre.contains(genre));
        }
        return _selectedGenre.contains(game['genre']);
      }).toList();
    }
  }

  void _onGameSelected(Map<String, dynamic> game) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameDetailPage(
          game: game,
          gameId: game['gameId'],
          isFromRoom: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = ErrorDisplay(
        errorMessage: _errorMessage,
        onRetry: _fetchGlobalConfig,
      );
    } else if (_isMaintenance) {
      // カスタムウィジェットを使用
      bodyContent = MaintenanceScreen(message: _maintenanceMessage);
    } else {
      // 通常のUI表示
      bodyContent = Column(
        children: [
          // 固定ヘッダー部分
          Container(
            padding: const EdgeInsets.all(AppSpacing.large),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LoadingButton(
                        text: '部屋作成',
                        isLoading: false,
                        onPressed: () => _showCreateRoomDialog(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.large),
                    Expanded(
                      child: LoadingButton(
                        text: '部屋参加',
                        isLoading: false,
                        onPressed: () =>
                            _showJoinRoomDialog(widget.roomId ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xLarge),
                Text(
                  'ゲーム一覧',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.medium),
                // カスタムタブバーを使用
                CustomTabBar(
                  controller: _tabController,
                  tabs: tabs,
                ),
              ],
            ),
          ),
          // TabBarViewでスワイプ可能なコンテンツ領域
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
                      // 全てのゲーム
                      GameListWidget(
                        games: _gameList,
                        onGameSelected: _onGameSelected,
                      ),
                      // 定番ゲーム
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
                      // カードゲーム
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
                      // 協力ゲーム
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ボードゲームハブ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotifications(),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.only(
              top: 80,
              left: AppSpacing.large,
              right: AppSpacing.large,
              bottom: AppSpacing.large),
          child: const SingleChildScrollView(
            child: RegisterProfilePage(isJoiningRoom: false),
          ),
        );
      },
    );
  }

  void _showNotifications() {
    if (!_isMaintenance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お知らせはありません')),
      );
    }
  }
}
