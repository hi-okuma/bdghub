import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../components/GameListWidget.dart';

class SelectGamePage extends StatefulWidget {
  final String roomId;
  final String myNickname;

  const SelectGamePage({
    Key? key,
    required this.roomId,
    required this.myNickname,
  }) : super(key: key);

  @override
  State<SelectGamePage> createState() => _SelectGamePageState();
}

class _SelectGamePageState extends State<SelectGamePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // プレイヤーリスト
  List<Map<String, dynamic>> _players = [];
  // Firestoreリスナー用
  StreamSubscription? _playersSubscription;
  // プレイヤーデータのローディング状態
  bool _isLoading = true;
  // エラーメッセージ
  String? _errorMessage;

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
    // Firestoreからプレイヤーデータを取得
    _subscribeToPlayers();
  }

  // Firestoreからプレイヤーデータを取得するメソッド
  void _subscribeToPlayers() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _playersSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('players')) {
        List<dynamic> playersData = snapshot.get('players');

        setState(() {
          _isLoading = false;
          // プレイヤーデータをマッピング
          _players = List.generate(playersData.length, (index) {
            // プレイヤーデータが文字列の場合
            if (playersData[index] is String) {
              return {
                'nickname': playersData[index],
                'isHost': index == 0, // インデックス0がホスト
              };
            }
            // そのほかの場合（念のため）
            return {
              'nickname': playersData[index].toString(),
              'isHost': index == 0,
            };
          });
        });
      } else {
        setState(() {
          _isLoading = false;
          _players = []; // データがない場合は空リスト
        });
      }
    }, onError: (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'データの取得中にエラーが発生しました';
        print('Firestoreエラー: $error');
      });
    });
  }

  @override
  void dispose() {
    // リスナーを解除
    _playersSubscription?.cancel();
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
  void _leaveRoom() async {
    try {
      final Uri apiUrl;
      final Map<String, dynamic> requestBody;

      apiUrl = Uri.parse(
          'https://asia-northeast1-bdghub-dev.cloudfunctions.net/leaveRoom');
      requestBody = {
        'nickname': widget.myNickname,
        'roomId': widget.roomId,
      };

      // APIリクエスト
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // レスポンスの処理
      if (response.statusCode == 200) {
        // 成功時の処理
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (!mounted) return;

        // 成功メッセージを表示
        String successMessage = '部屋: ${widget.roomId} を退出しました';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        // エラー時の処理
        try {
          // レスポンスボディをJSONとしてパース
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          // messageキーの値があれば表示、なければ全体のレスポンスを表示
          setState(() {
            _errorMessage = errorData.containsKey('message')
                ? '${errorData['message']}'
                : response.body;
          });
        } catch (e) {
          // JSONパースに失敗した場合は元のレスポンスボディをそのまま表示
          setState(() {
            _errorMessage = response.body;
          });
        }
      }
    } catch (e) {
      // 例外発生時の処理
      setState(() {
        _errorMessage = '通信エラー: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

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
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  )
                else if (_players.isEmpty)
                  const Text('参加者がいません')
                else
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
                              child: Center(
                                  child: player['isHost']
                                      ? Text('${player['nickname']}（ホスト）')
                                      : Text(player['nickname'])),
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
