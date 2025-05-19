import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../components/GameListWidget.dart';
import '../components/custom_widgets.dart';
import '../components/app_theme.dart';
import 'package:bodogehub/Pages/GameDetailPage.dart';
import 'package:bodogehub/Util/Util.dart';

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
  List<Map<String, dynamic>> _players = [];
  StreamSubscription? _playersSubscription;
  bool _isLoading = true;
  String? _errorMessage;

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

    _subscribeToPlayers();
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
          _players = List.generate(playersData.length, (index) {
            if (playersData[index] is String) {
              return {
                'nickname': playersData[index],
                'isHost': index == 0,
              };
            }
            return {
              'nickname': playersData[index].toString(),
              'isHost': index == 0,
            };
          });
        });
      } else {
        setState(() {
          _isLoading = false;
          _players = [];
        });
      }
    }, onError: (error) {
      final String errorMsg = 'データの取得中にエラーが発生しました';
      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
      print('Firestoreエラー: $error');
    });
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _copyRoomUrl() {
    String shareUrl = 'https://bdghub.web.app/?roomId=${widget.roomId}';
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('URLをコピーしました'),
          duration: AppAnimations.snackBarDuration,
        ),
      );
    });
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
    setState(() {
      _isLoading = true;
    });

    try {
      final Uri apiUrl = Uri.parse(
          'https://asia-northeast1-bdghub-dev.cloudfunctions.net/leaveRoom');
      final Map<String, dynamic> requestBody = {
        'nickname': widget.myNickname,
        'roomId': widget.roomId,
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
          _handleApiError(responseData);
          return;
        }

        if (!mounted) return;

        String successMessage = '部屋: ${widget.roomId} を退出しました';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );

        Navigator.of(context).pop();
      } else {
        _handleHttpError(response);
      }
    } catch (e) {
      _handleException(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleApiError(Map<String, dynamic> responseData) {
    final String errorMsg = responseData.containsKey('message')
        ? responseData['message']
        : '退出に失敗しました';

    setState(() {
      _errorMessage = errorMsg;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMsg)),
    );
  }

  void _handleHttpError(http.Response response) {
    try {
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      final String errorMsg = errorData.containsKey('message')
          ? '${errorData['message']}'
          : 'エラー: ${response.statusCode}';

      setState(() {
        _errorMessage = errorMsg;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      final String errorMsg = '応答の解析に失敗しました: ${response.body}';
      setState(() {
        _errorMessage = errorMsg;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  void _handleException(dynamic e) {
    final String errorMsg = '通信エラー: $e';
    setState(() {
      _errorMessage = errorMsg;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMsg)),
    );
  }

  void _onGameSelected(Map<String, dynamic> game) {
    bool isUserHost = _players.any((player) =>
        player['nickname'] == widget.myNickname && player['isHost'] == true);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameDetailPage(
          game: game,
          gameId: game['gameId'],
          roomId: widget.roomId,
          isFromRoom: true,
          isHost: isUserHost,
        ),
      ),
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
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.errorText,
                  )
                else if (_players.isEmpty)
                  Text(
                    '参加者がいません',
                    style: AppTextStyles.body,
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _players.map((player) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.small),
                          child: PlayerBadge(
                            nickname: player['nickname'],
                            isHost: player['isHost'],
                          ),
                        );
                      }).toList(),
                    ),
                  )
              ],
            ),
          ),

          // タブバー - カスタムウィジェットを使用
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
      ),
    );
  }
}
