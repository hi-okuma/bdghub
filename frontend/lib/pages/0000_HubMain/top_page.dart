import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/widgets.dart';
import '../0000_HubMain/register_profile_page.dart';
import '../../components/game_list_widget.dart';
import '../../components/custom_widgets.dart';
import '../../components/app_theme.dart';
import 'package:bodogehub/utils/game_service.dart';
import 'package:flutter/material.dart';
import 'package:bodogehub/pages/0000_HubMain/game_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analytics_provider.dart';

class TopPage extends ConsumerStatefulWidget {
  final String? roomId;

  const TopPage({super.key, this.roomId});

  @override
  ConsumerState<TopPage> createState() => _TopPageState();
}

class _TopPageState extends ConsumerState<TopPage>
    with SingleTickerProviderStateMixin, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  Uri termsOfServiceUrl = Uri.parse(dotenv.env['TERMS_OF_SERVICE_URL'] ?? '');
  Uri privacyPolicyUrl = Uri.parse(dotenv.env['PRIVACY_POLICY_URL'] ?? '');
  Uri formUrl = Uri.parse(dotenv.env['FORM_URL'] ?? '');
  List<Map<String, dynamic>> games = [];
  String selectedFilter = 'すべて';

  late TabController _tabController;
  List<Map<String, dynamic>> _gameList = [];
  bool _isGameLoading = true;
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  final List<CustomTab> tabs = <CustomTab>[
    const CustomTab(label: '全て'),
    const CustomTab(label: '定番'),
    // CustomTab(label: 'カード'),
    // CustomTab(label: '協力'),
  ];

  final pageTitle = '/top_page';

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
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
              ref.read(analyticsServiceProvider).logClick(
                  button: 'category_filter',
                  additionalParams: {'category': '全て'});
              _selectedGenre = {GameGenre.all};
              break;
            case 1:
              ref.read(analyticsServiceProvider).logClick(
                  button: 'category_filter',
                  additionalParams: {'category': '定番'});
              _selectedGenre = {GameGenre.popular};
              break;
            // case 2:
            //   ref.read(analyticsServiceProvider).logClick(
            //       button: 'category_filter',
            //       additionalParams: {'category': 'カード'});
            //   _selectedGenre = {GameGenre.card};
            //   break;
            // case 3:
            //   ref.read(analyticsServiceProvider).logClick(
            //       button: 'category_filter',
            //       additionalParams: {'category': '協力'});
            //   _selectedGenre = {GameGenre.popular};
            //   _selectedGenre = {GameGenre.cooperation};
            //   break;
          }
        });
      }
    });

    _fetchGames();
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
    _tabController.dispose();
    super.dispose();
  }

  /// 他のページから戻ってきた時
  @override
  void didPopNext() {
    super.didPopNext();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  /// このページが新しく表示された時
  @override
  void didPush() {
    super.didPush();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
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

  void _showCreateRoomDialog() {
    ref.read(analyticsServiceProvider).logClick(button: 'room_create');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          insetPadding: EdgeInsets.all(AppSpacing.large),
          child: SingleChildScrollView(
            child: RegisterProfilePage(isJoiningRoom: false),
          ),
        );
      },
    );
  }

  void _showJoinRoomDialog(String roomId) {
    ref.read(analyticsServiceProvider).logClick(button: 'room_join');
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

    // 通常のUI表示（メンテナンス確認はmain.dartで実施済み）
    bodyContent = Column(
        children: [
          // 固定ヘッダー部分
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large, vertical: AppSpacing.medium),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  child: ElevatedLoadingButton(
                    text: '部屋作成',
                    isLoading: false,
                    onPressed: () => _showCreateRoomDialog(),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Container(
                  width: double.infinity,
                  child: OutlinedLoadingButton(
                    text: '部屋参加',
                    isLoading: false,
                    onPressed: () => _showJoinRoomDialog(widget.roomId ?? ''),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                const Text(
                  'ゲーム一覧',
                  style: AppTextStyles.title,
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
                : Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large),
                    child: TabBarView(
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
                        // 協力ゲーム
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
      );

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'ボドゲハブ',
          style: AppTextStyles.bdghubHeaderStyle,
        ),
      ),
      // Drawerウィジェット内を以下のように修正
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              title: const Text('利用規約'),
              onTap: () {
                launchUrl(termsOfServiceUrl);
              },
            ),
            ListTile(
                title: const Text('プライバシーポリシー'),
                onTap: () {
                  launchUrl(privacyPolicyUrl);
                }),
            ListTile(
              title: const Text('ご意見箱'),
              onTap: () {
                launchUrl(formUrl);
              },
            ),
          ],
        ),
      ),
      body: bodyContent,
    );
  }
}
