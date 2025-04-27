import 'package:flutter/material.dart';
import 'RegisterProfilePage.dart';

class TopPage extends StatefulWidget {
  const TopPage({super.key});

  @override
  State<TopPage> createState() => _TopPageState();
}

enum GameGenre { all, tactics, card, cooperation }

class _TopPageState extends State<TopPage> with SingleTickerProviderStateMixin {
  // TabControllerを追加
  late TabController _tabController;

  // 選択されているジャンル
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  // ダミーのゲームリスト
  final List<Map<String, dynamic>> _gameList = [
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'タクティカルバトル', 'genre': GameGenre.tactics, 'players': '2-4人'},
    {'title': 'カードマスター', 'genre': GameGenre.card, 'players': '2-6人'},
    {'title': 'コープアドベンチャー', 'genre': GameGenre.cooperation, 'players': '3-5人'},
    {'title': 'タクティカルカード', 'genre': GameGenre.tactics, 'players': '2人'},
    {'title': '協力型カードゲーム', 'genre': GameGenre.cooperation, 'players': '2-4人'},
  ];

  final List<Tab> tabs = const <Tab>[
    Tab(text: '全て'),
    Tab(text: '戦略'),
    Tab(text: 'カード'),
    Tab(text: '協力'),
  ];

  @override
  void initState() {
    super.initState();
    // TabControllerの初期化
    _tabController = TabController(length: tabs.length, vsync: this);

    // タブ切り替え時のリスナー
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedGenre = {GameGenre.all};
              break;
            case 1:
              _selectedGenre = {GameGenre.tactics};
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
  }

  @override
  void dispose() {
    // TabControllerの破棄
    _tabController.dispose();
    super.dispose();
  }

  // 表示するゲームのリスト
  List<Map<String, dynamic>> get _filteredGames {
    if (_selectedGenre.contains(GameGenre.all)) {
      return _gameList;
    } else {
      return _gameList
          .where((game) => _selectedGenre.contains(game['genre']))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ボードゲームハブ'),
        actions: [
          // 右上にベルアイコン（お知らせ）を追加
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('お知らせはありません')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 固定ヘッダー部分
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            // barrierDismissibleをfalseに設定して、ダイアログ外タップで閉じないようにする
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              // SingleChildScrollViewでラップして、キーボード表示時に自動スクロールするようにする
                              return Dialog(
                                // ダイアログを上部に表示するためのinsetPaddingを設定
                                insetPadding: const EdgeInsets.only(
                                    top: 80, left: 20, right: 20, bottom: 20),
                                child: const SingleChildScrollView(
                                  child: RegisterProfilePage(),
                                ),
                              );
                            },
                          );
                        },
                        child: const Text('部屋作成'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('部屋参加'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'ゲーム一覧',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // TabBarを実装
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: tabs,
                    //現段階ではゲームジャンルをダミーで４件のみ登録しているだけなので、以下コメントアウト
                    //絞り込み条件横スクロール設定
                    // isScrollable: true, // 画面幅より広い場合スクロール可能に
                    // tabAlignment: TabAlignment.start,
                    labelColor: Theme.of(context).primaryColor, // 選択中のタブテキスト色
                    unselectedLabelColor: Colors.grey, // 非選択のタブテキスト色
                    indicatorSize: TabBarIndicatorSize.tab, // インジケーターのサイズ
                    dividerColor: Colors.transparent, // 下部の線を非表示
                    indicator: BoxDecoration(
                      color: Colors.white, // 選択されたタブの背景色を白に
                      borderRadius: BorderRadius.circular(8.0), // 角丸に
                    ),
                    labelPadding: const EdgeInsets.symmetric(
                        horizontal: 6.0), // タブのパディングを調整
                    padding: const EdgeInsets.all(4.0), // TabBar全体のパディング
                  ),
                ),
              ],
            ),
          ),
          // TabBarViewでスワイプ可能なコンテンツ領域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // カチッとしたスワイプ感のために物理特性を調整
              physics: const PageScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                // 全てのゲーム
                _buildGameList(_gameList),
                // 戦略ゲーム
                _buildGameList(_gameList
                    .where((game) => game['genre'] == GameGenre.tactics)
                    .toList()),
                // カードゲーム
                _buildGameList(_gameList
                    .where((game) => game['genre'] == GameGenre.card)
                    .toList()),
                // 協力ゲーム
                _buildGameList(_gameList
                    .where((game) => game['genre'] == GameGenre.cooperation)
                    .toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ゲームリスト表示用のウィジェットを作成
  Widget _buildGameList(List<Map<String, dynamic>> games) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(game['title']),
            subtitle: Text('プレイ人数: ${game["players"]}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // ゲーム詳細画面への遷移（ダミー）
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${game["title"]}が選択されました')),
              );
            },
          ),
        );
      },
    );
  }
}
