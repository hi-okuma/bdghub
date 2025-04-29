import 'package:flutter/material.dart';
import 'RegisterProfilePage.dart';
import '../components/GameListWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopPage extends StatefulWidget {
  final String? roomId;

  const TopPage({super.key, this.roomId});

  @override
  State<TopPage> createState() => _TopPageState();
}

enum GameGenre { all, tactics, card, cooperation }

class _TopPageState extends State<TopPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // プレイヤーデータのローディング状態
  bool _isLoading = true;
  // エラーメッセージ
  String? _errorMessage;
  // メンテナンス状態
  bool _isMaintenance = false;
  // メンテナンスメッセージ
  String _maintenanceMessage = '';

  // 選択されているジャンル
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  // ダミーのゲームリスト
  final List<Map<String, dynamic>> _gameList = [
    {
      'title': 'タクティカルバトル',
      'genre': GameGenre.tactics,
      'category': '戦略',
      'players': '2-4人',
      'time': '30-60分',
      'description': '資源を集めて拠点を建築し、対戦相手を打ち負かす戦略ゲーム',
    },
    {
      'title': 'カードマスター',
      'genre': GameGenre.card,
      'category': 'カード',
      'players': '2-6人',
      'time': '20-40分',
      'description': '手札を駆使して相手よりも多くのポイントを獲得するカードゲーム',
    },
    {
      'title': 'コープアドベンチャー',
      'genre': GameGenre.cooperation,
      'category': '協力',
      'players': '3-5人',
      'time': '45-90分',
      'description': 'プレイヤー全員で協力して、迫り来る危機から脱出を目指す',
    },
    {
      'title': 'タクティカルカード',
      'genre': GameGenre.tactics,
      'category': '戦略',
      'players': '2人',
      'time': '15-30分',
      'description': '2人で対戦する戦略的なカードゲーム。シンプルなルールで奥深い戦略性',
    },
    {
      'title': '協力型カードゲーム',
      'genre': GameGenre.cooperation,
      'category': '協力',
      'players': '2-4人',
      'time': '30-45分',
      'description': 'チームで協力してミッションをクリアするカードゲーム',
    },
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
    // Firestoreからメンテナンス情報を一度だけ取得
    _fetchGlobalConfig();
  }

  // 部屋参加用のダイアログを表示
  void _showJoinRoomDialog(String roomId) {
    showDialog(
      context: context,
      // barrierDismissibleをfalseに設定して、ダイアログ外タップで閉じないようにする
      barrierDismissible: false,
      builder: (BuildContext context) {
        // SingleChildScrollViewでラップして、キーボード表示時に自動スクロールするようにする
        return Dialog(
          // ダイアログを上部に表示するためのinsetPaddingを設定
          insetPadding:
              const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 20),
          child: SingleChildScrollView(
            // 部屋参加モード（isJoiningRoom = true）、URLから部屋IDを渡す
            child: RegisterProfilePage(
              isJoiningRoom: true,
              initialRoomId: roomId,
            ),
          ),
        );
      },
    );
  }

  // Firestoreからグローバル設定（メンテナンス情報など）を一度だけ取得するメソッド
  Future<void> _fetchGlobalConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('serviceConfig')
          .doc('global')
          .get(); // ここを .get() に変更

      if (snapshot.exists && snapshot.data() != null) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('maintenance')) {
          Map<String, dynamic> globalConfig = data['maintenance'];
          setState(() {
            // isMaintenanceとmaintenanceMessageを取得。nullの場合も考慮
            _isMaintenance = globalConfig['isMaintenance'] ?? false;
            _maintenanceMessage = globalConfig['maintenanceMessage'] ?? '';
            _isLoading = false; // データ取得完了
          });
        } else {
          // 'maintenance'フィールドがない場合
          setState(() {
            _isMaintenance = false;
            _maintenanceMessage = '';
            _isLoading = false; // データ取得完了
          });
        }
      } else {
        // ドキュメントが存在しない場合
        setState(() {
          _isMaintenance = false;
          _maintenanceMessage = '';
          _isLoading = false; // データ取得完了
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

  // ゲーム選択時の処理
  void _onGameSelected(Map<String, dynamic> game) {
    // ゲーム詳細画面への遷移（ダミー）
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${game["title"]}が選択されました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      // ローディング中の表示
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      // エラー発生時の表示
      bodyContent = Center(child: Text('エラー: $_errorMessage'));
    } else if (_isMaintenance) {
      // メンテナンス中の表示
      // 画面全体を覆うメンテナンスメッセージ表示
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'メンテナンス中です',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _maintenanceMessage.isNotEmpty
                    ? _maintenanceMessage
                    : '現在、システムメンテナンスのためサービスを一時停止しております。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              // 必要に応じて、メンテナンス終了予定時刻などを追加
              // const SizedBox(height: 20),
              // const Text('終了予定時刻: 2024年XX月YY日 ZZ時', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    } else {
      // 通常のUI表示
      bodyContent = Column(
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
                              return const Dialog(
                                // ダイアログを上部に表示するためのinsetPaddingを設定
                                insetPadding: EdgeInsets.only(
                                    top: 80, left: 20, right: 20, bottom: 20),
                                child: SingleChildScrollView(
                                  // 部屋作成モード（isJoiningRoom = false）
                                  child:
                                      RegisterProfilePage(isJoiningRoom: false),
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
                        onPressed: () =>
                            _showJoinRoomDialog(widget.roomId ?? ''),
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
                GameListWidget(
                  games: _gameList,
                  onGameSelected: _onGameSelected,
                ),
                // 戦略ゲーム
                GameListWidget(
                  games: _gameList
                      .where((game) => game['genre'] == GameGenre.tactics)
                      .toList(),
                  onGameSelected: _onGameSelected,
                ),
                // カードゲーム
                GameListWidget(
                  games: _gameList
                      .where((game) => game['genre'] == GameGenre.card)
                      .toList(),
                  onGameSelected: _onGameSelected,
                ),
                // 協力ゲーム
                GameListWidget(
                  games: _gameList
                      .where((game) => game['genre'] == GameGenre.cooperation)
                      .toList(),
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
          // 右上にベルアイコン（お知らせ）を追加
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // メンテナンス中は通知を表示しないなどの制御を追加することも可能
              if (!_isMaintenance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('お知らせはありません')),
                );
              }
            },
          ),
        ],
      ),
      body: bodyContent, // ここで表示するコンテンツを切り替え
    );
  }
}
