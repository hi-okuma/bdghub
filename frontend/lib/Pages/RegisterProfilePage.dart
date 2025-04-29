import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'SelectGamePage.dart';

class RegisterProfilePage extends StatefulWidget {
  final bool isJoiningRoom;
  
  const RegisterProfilePage({
    super.key, 
    this.isJoiningRoom = false
  });

  @override
  State<RegisterProfilePage> createState() => _RegisterProfilePageState();
}

class _RegisterProfilePageState extends State<RegisterProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // 入力値のバリデーション
  bool _validateNickname(String value) {
    // 空チェック
    if (value.isEmpty) {
      setState(() {
        _errorMessage = 'ニックネームを入力してください';
      });
      return false;
    }

    // 文字数チェック（2〜10文字）
    if (value.length < 2) {
      setState(() {
        _errorMessage = 'ニックネームは2文字以上入力してください';
      });
      return false;
    }

    // 文字数チェック（10文字以内）
    if (value.length > 10) {
      setState(() {
        _errorMessage = 'ニックネームは10文字以内で入力してください';
      });
      return false;
    }

    // 禁止文字チェック
    if (value.contains('/') || value.contains('.')) {
      setState(() {
        _errorMessage = '「/」や「.」は使用できません';
      });
      return false;
    }

    return true;
  }

  Future<void> _createRoom() async {
    // 入力値のバリデーション
    if (!_validateNickname(_nicknameController.text)) {
      return;
    }

    // 部屋参加モードの場合は部屋コードの入力チェック
    if (widget.isJoiningRoom && _roomIdController.text.isEmpty) {
      setState(() {
        _errorMessage = '部屋コードを入力してください';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Uri apiUrl;
      final Map<String, dynamic> requestBody;
      
      if (widget.isJoiningRoom) {
        // 部屋参加モードの場合
        apiUrl = Uri.parse(
            'https://asia-northeast1-bdghub-dev.cloudfunctions.net/joinRoom');
        requestBody = {
          'nickname': _nicknameController.text,
          'roomId': _roomIdController.text
        };
      } else {
        // 部屋作成モードの場合
        apiUrl = Uri.parse(
            'https://asia-northeast1-bdghub-dev.cloudfunctions.net/createRoom');
        requestBody = {'nickname': _nicknameController.text};
      }

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
        final String roomId = widget.isJoiningRoom 
            ? _roomIdController.text 
            : responseData['roomId'];

        if (!mounted) return;

        // ダイアログを閉じる
        Navigator.of(context).pop();

        // ゲーム選択画面に遷移する
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SelectGamePage(
              roomId: roomId,
            ),
          ),
        );

        // 成功メッセージを表示
        final String successMessage = widget.isJoiningRoom 
            ? '部屋に参加しました' 
            : '部屋が作成されました';
        
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
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // キーボードの高さを取得
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      width: 400, // ダイアログの幅
      padding: EdgeInsets.fromLTRB(
          20.0, 20.0, 20.0, bottomInset > 0 ? 20.0 + bottomInset * 0.5 : 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ダイアログのサイズを最小限にする
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'ニックネームを入力（2〜10文字）',
              hintText: '例：ボドゲハブ',
              helperText: '※「/」と「.」は使用できません',
            ),
            // 入力時のリアルタイムバリデーション
            onChanged: (value) {
              // 文字入力のたびにエラーメッセージをクリア
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }

              // 文字数チェック（リアルタイム）
              if (value.length > 10) {
                setState(() {
                  _errorMessage = 'ニックネームは10文字以内で入力してください';
                });
              }

              // 禁止文字のリアルタイムチェック
              else if (value.contains('/') || value.contains('.')) {
                setState(() {
                  _errorMessage = '「/」や「.」は使用できません';
                });
              }
            },
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 10),
          if (widget.isJoiningRoom)
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '部屋コードを入力',
                hintText: 'abcdefg1234',
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('キャンセル'),
              ),
              // 作成または参加ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isJoiningRoom ? '部屋に参加する' : '部屋を作成する'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
