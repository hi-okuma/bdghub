import 'RegisterProfilePage.dart';
import '../components/GameListWidget.dart';
import 'package:bodogehub/Util/Util.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopPage extends StatefulWidget {
  final String? roomId;

  const TopPage({super.key, this.roomId});

  @override
  State<TopPage> createState() => _TopPageState();
}

enum GameGenre { all, popular, card, cooperation }

class _TopPageState extends State<TopPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> games = [];
  bool isLoading = true;
  String selectedFilter = 'すべて';

  // TabControllerを追加
  late TabController _tabController;

  // 選択されているジャンル
  Set<GameGenre> _selectedGenre = {GameGenre.all};

  // ゲームリスト（Firestoreから取得）
  List<Map<String, dynamic>> _gameList = [];

  // データ読み込み中フラグ
  bool _isLoading = true;

  final List<Tab> tabs = const <Tab>[
    Tab(text: '全て'),
    Tab(text: '定番'),
    Tab(text: 'カード'),
    Tab(text: '協力'),
  ];

  // Firestoreからゲームデータを取得するメソッド
  Future<void> _fetchGamesFromFirestore() async {
    try {
      // gamesコレクションの全ドキュメントを取得
      final snapshot = await _firestore
          .collection('games')
          .where('isPublished', isEqualTo: true) // 公開されているゲームのみ取得
          .get();

      if (snapshot.docs.isNotEmpty) {
        final List<Map<String, dynamic>> parsedGames = [];
        final List<String> tagsList = [];

        // 各ドキュメントからデータを抽出
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final gameId = doc.id;

          // tagsからジャンル情報を取得（複数登録可能）
          List<GameGenre> genres = [GameGenre.all];
          List<String> genreNames = ['すべて'];

          if (data['tags'] != null && data['tags'] is List) {
            final tags = List<dynamic>.from(data['tags']);
            genres = []; // 初期値をリセット
            genreNames = []; // 初期値をリセット

            // tagsからジャンルを判定する（複数登録可能）
            // NOTE: タグIDとジャンルのマッピングは実際のデータに合わせて修正する
            if (tags.contains('定番')) {
              genres.add(GameGenre.popular);
              genreNames.add('定番');
            }
            if (tags.contains('カード')) {
              genres.add(GameGenre.card);
              genreNames.add('カード');
            }
            if (tags.contains('協力')) {
              genres.add(GameGenre.cooperation);
              genreNames.add('協力');
            }

            // ジャンルが一つも登録されていない場合はデフォルト値を設定
            if (genres.isEmpty) {
              genres.add(GameGenre.all);
              genreNames.add('すべて');
            }
          }

          // ゲーム情報をリストに追加
          parsedGames.add({
            'id': gameId, // ソート用にIDを追加
            'title': data['title'] ?? '',
            'genre': genres, // 複数ジャンルをリストとして保存
            'genreName': genreNames, // ジャンル名をリストとして保存
            'players':
                '${data['minPlayers'] ?? ''}-${data['maxPlayers'] ?? ''}人',
            'time': '${data['duration'] ?? ''}分',
            'overview': data['overview'] ?? '',
            'description': data['description'] ?? '',
            'playCnt': data['playCnt'] ?? 0, // ソート用に追加
          });
        }

        // playCnt → gameIdの順にdescendingでソート
        parsedGames.sort((a, b) {
          final int playCntA = a['playCnt'] ?? 0;
          final int playCntB = b['playCnt'] ?? 0;

          // まずはplayCntで比較
          final int playCntComparison = playCntB.compareTo(playCntA); // 降順

          // playCntが同じならgameId(ドキュメントID)で比較
          if (playCntComparison == 0) {
            return (b['id'] ?? '').compareTo(a['id'] ?? ''); // 降順
          }

          return playCntComparison;
        });

        setState(() {
          _gameList = parsedGames;
          _isLoading = false;
        });
      } else {
        // ドキュメントが存在しない場合はダミーデータを使用
        setState(() {
          _gameList = _getDummyGames();
          _isLoading = false;
        });
        print('Firestoreにデータが存在しないため、ダミーデータを使用します');
      }
    } catch (e) {
      print('Firestoreからのデータ取得エラー: $e');
      // エラー時はダミーデータを使用
      setState(() {
        _gameList = _getDummyGames();
        _isLoading = false;
      });
    }
  }

// ダミーデータを返す（Firestore取得失敗時のフォールバック用）
  List<Map<String, dynamic>> _getDummyGames() {
    return [
      {
        'title': 'タクティカルバトル',
        'genre': [GameGenre.popular],
        'genreName': ['定番'],
        'category': '戦略',
        'players': '2-4人',
        'time': '30-60分',
        'description': '資源を集めて拠点を建築し、対戦相手を打ち負かす戦略ゲーム',
        'overview': '資源を集めて拠点を建築し、対戦相手を打ち負かす戦略ゲーム',
      },
      {
        'title': 'カードマスター',
        'genre': [GameGenre.card],
        'genreName': ['カード'],
        'category': 'カード',
        'players': '2-6人',
        'time': '20-40分',
        'description': '手札を駆使して相手よりも多くのポイントを獲得するカードゲーム',
        'overview': '手札を駆使して相手よりも多くのポイントを獲得するカードゲーム',
      },
      {
        'title': 'コープアドベンチャー',
        'genre': [GameGenre.cooperation],
        'genreName': ['協力'],
        'category': '協力',
        'players': '3-5人',
        'time': '45-90分',
        'description': 'プレイヤー全員で協力して、迫り来る危機から脱出を目指す',
        'overview': 'プレイヤー全員で協力して、迫り来る危機から脱出を目指す',
      },
      {
        'title': 'タクティカルカード',
        'genre': [GameGenre.popular, GameGenre.card],
        'genreName': ['定番', 'カード'],
        'category': '戦略',
        'players': '2人',
        'time': '15-30分',
        'description': '2人で対戦する戦略的なカードゲーム。シンプルなルールで奥深い戦略性',
        'overview': '2人で対戦する戦略的なカードゲーム',
      },
      {
        'title': '協力型カードゲーム',
        'genre': [GameGenre.cooperation, GameGenre.card],
        'genreName': ['協力', 'カード'],
        'category': '協力',
        'players': '2-4人',
        'time': '30-45分',
        'description': 'チームで協力してミッションをクリアするカードゲーム',
        'overview': 'チームで協力してミッションをクリアするカードゲーム',
      },
    ];
  }

  @override
  void initState() {
    super.initState();

    // URLパラメータに部屋IDがある場合は自動的に部屋参加モードを開く
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.roomId != null && widget.roomId!.isNotEmpty) {
        _showJoinRoomDialog(widget.roomId!);
      }
    });

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

    // Firestoreからゲームデータを取得
    _fetchGamesFromFirestore();
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

  @override
  void dispose() {
    // TabControllerの破棄
    _tabController.dispose();
    super.dispose();
  }

  // 表示するゲームのリスト（複数ジャンル対応）
  List<Map<String, dynamic>> get _filteredGames {
    if (_selectedGenre.contains(GameGenre.all)) {
      return _gameList;
    } else {
      return _gameList.where((game) {
        // 'genre'が配列として格納されているため、いずれかの要素が選択ジャンルに含まれているか確認
        if (game['genre'] is List) {
          List<GameGenre> genres = List<GameGenre>.from(game['genre']);
          // どれか1つでも選択ジャンルに含まれていればtrue
          return genres.any((genre) => _selectedGenre.contains(genre));
        }
        // 互換性のため、従来の単一値のgenreにも対応
        return _selectedGenre.contains(game['genre']);
      }).toList();
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : TabBarView(
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
                      // 定番ゲーム
                      GameListWidget(
                        games: _gameList.where((game) {
                          // 複数ジャンル対応
                          if (game['genre'] is List) {
                            List<GameGenre> genres =
                                List<GameGenre>.from(game['genre']);
                            return genres.contains(GameGenre.popular);
                          }
                          // 互換性維持のため
                          return game['genre'] == GameGenre.popular;
                        }).toList(),
                        onGameSelected: _onGameSelected,
                      ),
                      // カードゲーム
                      GameListWidget(
                        games: _gameList.where((game) {
                          // 複数ジャンル対応
                          if (game['genre'] is List) {
                            List<GameGenre> genres =
                                List<GameGenre>.from(game['genre']);
                            return genres.contains(GameGenre.card);
                          }
                          // 互換性維持のため
                          return game['genre'] == GameGenre.card;
                        }).toList(),
                        onGameSelected: _onGameSelected,
                      ),
                      // 協力ゲーム
                      GameListWidget(
                        games: _gameList.where((game) {
                          // 複数ジャンル対応
                          if (game['genre'] is List) {
                            List<GameGenre> genres =
                                List<GameGenre>.from(game['genre']);
                            return genres.contains(GameGenre.cooperation);
                          }
                          // 互換性維持のため
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
}
