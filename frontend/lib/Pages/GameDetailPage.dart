import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GameDetailPage extends StatefulWidget {
  final Map<String, dynamic> game;
  final bool isFromRoom; // 部屋から来たかどうかのフラグ
  final bool isHost; // ホストユーザーかどうかのフラグ
  final String? roomId;
  final String gameId;

  const GameDetailPage({
    Key? key,
    required this.game,
    this.isFromRoom = false, // デフォルトはTOP画面からの遷移（ボタン非表示）
    this.isHost = false, //デフォルトはホストユーザーではない（ボタン非表示）
    this.roomId,
    required this.gameId,
  }) : super(key: key);

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _startGame() async {
    // 処理開始前にローディング状態をtrueに設定
    setState(() {
      _isLoading = true;
      _errorMessage = null; // エラーメッセージをリセット
    });

    try {
      final Uri apiUrl = Uri.parse(
          'https://asia-northeast1-bdghub-dev.cloudfunctions.net/startGame');
      final Map<String, dynamic> requestBody = {
        'roomId': widget.roomId,
        'gameId': widget.gameId,
      };

      // APIリクエスト
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // レスポンスの処理
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // success=falseの場合のエラーハンドリングを追加
        if (responseData.containsKey('success') &&
            responseData['success'] == false) {
          if (!mounted) return;

          // エラーメッセージを設定
          final String errorMsg = responseData.containsKey('message')
              ? responseData['message']
              : 'ゲーム開始に失敗しました';

          setState(() {
            _errorMessage = errorMsg;
          });

          // ユーザーにエラーを通知
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        } else {
          if (!mounted) return;

          // 成功メッセージを表示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ゲームを開始します')),
          );
        }
      } else {
        // エラー時の処理
        try {
          // レスポンスボディをJSONとしてパース
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          // messageキーの値があれば表示、なければ全体のレスポンスを表示
          final String errorMsg = errorData.containsKey('message')
              ? '${errorData['message']}'
              : 'エラー: ${response.statusCode}';

          setState(() {
            _errorMessage = errorMsg;
          });

          if (!mounted) return;

          // ユーザーにエラーを通知
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        } catch (e) {
          // JSONパースに失敗した場合
          final String errorMsg = '応答の解析に失敗しました: ${response.body}';

          setState(() {
            _errorMessage = errorMsg;
          });

          if (!mounted) return;

          // ユーザーにエラーを通知
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e) {
      // 例外発生時の処理
      final String errorMsg = '通信エラー: $e';

      setState(() {
        _errorMessage = errorMsg;
      });

      if (!mounted) return;

      // ユーザーにエラーを通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game['title']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ゲームカード（GameListWidgetからUIを流用）
            _buildGameCard(context),

            // 「このゲームで遊ぶ」ボタン（部屋から来た場合かつホストユーザーのみ表示）
            if (widget.isFromRoom && widget.isHost) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startGame, // ローディング中は無効化
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'このゲームで遊ぶ',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],

            // ゲーム詳細説明
            const SizedBox(height: 24),
            const Text(
              'ゲーム詳細',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.game['description'] ?? '説明がありません',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('作成者：${widget.game['creatorName']}'),
                ElevatedButton(
                    onPressed: () {
                      // ECサイトへ移動する処理
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.game["title"]}の購入サイトへ移動します'),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 18.0,
                        ),
                        Text('購入サイトへ'),
                      ],
                    ))
              ],
            )
          ],
        ),
      ),
    );
  }

  // GameListWidgetのカードデザインを流用したゲームカードウィジェット
  Widget _buildGameCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル
            Container(
              width: 100,
              height: 100,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: (widget.game['thumbnailUrl'] != null &&
                      widget.game['thumbnailUrl'].isNotEmpty)
                  ? Image.network(
                      widget.game['thumbnailUrl'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        );
                      },
                    )
                  : const Icon(
                      Icons.casino,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 12),

            // ゲーム情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.game['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ジャンル名をChipとして表示
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _buildGenreChips(widget.game),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    '所要時間: ${widget.game['time']} / ${widget.game['players']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    widget.game['overview'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // GameListWidgetからコピーしたジャンルチップ生成メソッド
  List<Widget> _buildGenreChips(Map<String, dynamic> game) {
    if (game['genreName'] is List) {
      List<String> genreNames = List<String>.from(game['genreName']);

      if (genreNames.isEmpty) {
        return [_buildSingleChip('すべて')];
      }

      return genreNames.map((name) => _buildSingleChip(name)).toList();
    }

    String genreName = (game['genreName'] ?? 'すべて').toString();
    return [_buildSingleChip(genreName)];
  }

  // GameListWidgetからコピーした単一チップ生成メソッド
  Widget _buildSingleChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[800],
        ),
      ),
    );
  }
}
