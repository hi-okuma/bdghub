import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../components/custom_widgets.dart';
import '../components/app_theme.dart';

class GameDetailPage extends StatefulWidget {
  final Map<String, dynamic> game;
  final bool isFromRoom;
  final bool isHost;
  final String? roomId;
  final String gameId;

  const GameDetailPage({
    Key? key,
    required this.game,
    this.isFromRoom = false,
    this.isHost = false,
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Uri apiUrl = Uri.parse(
          'https://asia-northeast1-bdghub-dev.cloudfunctions.net/startGame');
      final Map<String, dynamic> requestBody = {
        'roomId': widget.roomId,
        'gameId': widget.gameId,
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
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ゲームを開始します')),
          );
        }
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
    if (!mounted) return;

    final String errorMsg = responseData.containsKey('message')
        ? responseData['message']
        : 'ゲーム開始に失敗しました';

    setState(() {
      _errorMessage = errorMsg;
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game['title']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ゲームカード - カスタムウィジェットを使用
            _buildGameCard(),

            // 「このゲームで遊ぶ」ボタン（部屋から来た場合かつホストユーザーのみ表示）
            if (widget.isFromRoom && widget.isHost) ...[
              const SizedBox(height: AppSpacing.xxLarge),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  text: 'このゲームで遊ぶ',
                  isLoading: _isLoading,
                  onPressed: _startGame,
                ),
              ),
            ],

            // エラー表示
            ErrorDisplay(
              errorMessage: _errorMessage,
              onRetry: widget.isFromRoom && widget.isHost ? _startGame : null,
            ),

            // ゲーム詳細説明
            const SizedBox(height: AppSpacing.xxLarge),
            Text(
              'ゲーム詳細',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              widget.game['description'] ?? '説明がありません',
              style: AppTextStyles.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.small),
            // 区切り線
            const Divider(height: AppSpacing.xxLarge),
            // 作成者情報と購入リンク
            _buildGameFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル - カスタムウィジェットを使用（詳細画面用サイズ）
            GameThumbnail(
              thumbnailUrl: widget.game['thumbnailUrl'],
              size: AppIconSizes.gameDetailThumbnail,
            ),
            const SizedBox(width: AppSpacing.medium),

            // ゲーム情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.game['title'],
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  // ジャンルチップ - カスタムウィジェットを使用
                  _buildGenreChips(widget.game),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    '所要時間: ${widget.game['time']} / ${widget.game['players']}',
                    style: AppTextStyles.gameCardTime,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),

                  Text(
                    widget.game['overview'] ?? '',
                    style: AppTextStyles.body,
                    maxLines: AppLayout.maxGameDescriptionLines,
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

  Widget _buildGenreChips(Map<String, dynamic> game) {
    List<String> genreNames = [];

    if (game['genreName'] is List) {
      genreNames = List<String>.from(game['genreName']);
    } else {
      String genreName = (game['genreName'] ?? 'すべて').toString();
      genreNames = [genreName];
    }

    if (genreNames.isEmpty) {
      genreNames = ['すべて'];
    }

    return Wrap(
      spacing: AppSpacing.xSmall,
      runSpacing: AppSpacing.xSmall,
      children: genreNames.map((name) => GenreChip(label: name)).toList(),
    );
  }

  Widget _buildGameFooter() {
    return Row(
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
    );
  }
}
