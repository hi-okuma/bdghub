import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/GameListWidget.dart';

class SelectGamePage extends StatefulWidget {
  final String roomId;

  const SelectGamePage({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  State<SelectGamePage> createState() => _SelectGamePageState();
}

class _SelectGamePageState extends State<SelectGamePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ダミーのプレイヤーリスト
  final List<Map<String, dynamic>> _players = [
    {'nickname': 'くま（ホスト）', 'isHost': true},
    {'nickname': 'まんだ', 'isHost': false},
    {'nickname': 'うつ', 'isHost': false},
    {'nickname': 'にわ', 'isHost': false},
  ];

  // ダミーのゲームリスト
  final List<Map<String, dynamic>> _gameList = [
    {
      'title': 'カタン',
      'category': '戦略',
      'time': '60-120分',
      'players': '2-4人',
      'description': '資源を集めて道や都市を建設していくゲーム。交渉や戦略が勝敗を分ける。',
    },
    {
      'title': 'ドミニオン',
      'category': 'カード',
      'time': '30分',
      'players': '2-4人',
      'description': '自分の領土（デッキ）を構築していくカードゲーム。自分のデッキを強化しながら勝利点を集める。',
    },
  ];

  // タブの定義
  final List<Tab> _tabs = const <Tab>[
    Tab(text: 'すべて'),
    Tab(text: '戦略'),
    Tab(text: 'カード'),
    Tab(text: '協力'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // URLをコピーする処理
  void _copyRoomUrl() {
    String shareUrl = 'https://bdghub.web.app/?roomId=${widget.roomId}';
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URLをコピーしました'),
          duration: Duration(milliseconds: 4000),
        ),
      );
    });
  }

  // 退出ダイアログを表示
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('部屋から退出しますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                _leaveRoom(); // 退出処理を実行
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('退出する'),
            ),
          ],
        );
      },
    );
  }

  // 退出処理
  void _leaveRoom() {
    // 実際の退出処理はここに実装
    Navigator.of(context).pop(); // TOP画面に戻る
  }

  // ゲーム選択時の処理
  void _onGameSelected(Map<String, dynamic> game) {
    // ゲーム詳細画面への遷移
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${game["title"]}が選択されました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('部屋: ${widget.roomId}'),
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            onPressed: _showExitDialog,
            child: const Text(
              '退出',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[200],
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              onPressed: _copyRoomUrl,
              child: const Text(
                'URLをコピー',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 参加者エリア
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '参加者',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _players.map((player) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                              color: player['isHost']
                                  ? Colors.amber[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4.0)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            child: Center(child: Text(player['nickname'])),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),

          // タブバー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: _tabs,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6.0),
                padding: const EdgeInsets.all(4.0),
              ),
            ),
          ),

          // ゲーム一覧（タブビュー）
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // カチッとしたスワイプ感のために物理特性を調整
              physics: const PageScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                // すべてのタブ
                GameListWidget(
                  games: _gameList,
                  onGameSelected: _onGameSelected,
                ),
                // 戦略タブ
                GameListWidget(
                  games: _gameList
                      .where((game) => game['category'] == '戦略')
                      .toList(),
                  onGameSelected: _onGameSelected,
                ),
                // カードタブ
                GameListWidget(
                  games: _gameList
                      .where((game) => game['category'] == 'カード')
                      .toList(),
                  onGameSelected: _onGameSelected,
                ),
                // 協力タブ
                GameListWidget(
                  games: _gameList
                      .where((game) => game['category'] == '協力')
                      .toList(),
                  onGameSelected: _onGameSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
