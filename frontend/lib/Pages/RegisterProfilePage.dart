import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'SelectGamePage.dart';
import '../components/custom_widgets.dart';
import '../components/app_theme.dart';

class RegisterProfilePage extends StatefulWidget {
  final bool isJoiningRoom;
  final String? initialRoomId;

  const RegisterProfilePage(
      {super.key, this.isJoiningRoom = false, this.initialRoomId});

  @override
  State<RegisterProfilePage> createState() => _RegisterProfilePageState();
}

class _RegisterProfilePageState extends State<RegisterProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoomId != null && widget.initialRoomId!.isNotEmpty) {
      _roomIdController.text = widget.initialRoomId!;
    }
  }

  bool _validateNickname(String value) {
    if (value.isEmpty) {
      setState(() {
        _errorMessage = 'ニックネームを入力してください';
      });
      return false;
    }

    if (value.length < AppLayout.minNicknameLength) {
      setState(() {
        _errorMessage = 'ニックネームは${AppLayout.minNicknameLength}文字以上入力してください';
      });
      return false;
    }

    if (value.length > AppLayout.maxNicknameLength) {
      setState(() {
        _errorMessage = 'ニックネームは${AppLayout.maxNicknameLength}文字以内で入力してください';
      });
      return false;
    }

    if (value.contains('/') || value.contains('.')) {
      setState(() {
        _errorMessage = '「/」や「.」は使用できません';
      });
      return false;
    }

    return true;
  }

  Future<void> _createRoom() async {
    if (!_validateNickname(_nicknameController.text)) {
      return;
    }

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
        apiUrl = Uri.parse(
            'https://asia-northeast1-bdghub-dev.cloudfunctions.net/joinRoom');
        requestBody = {
          'nickname': _nicknameController.text,
          'roomId': _roomIdController.text
        };
      } else {
        apiUrl = Uri.parse(
            'https://asia-northeast1-bdghub-dev.cloudfunctions.net/createRoom');
        requestBody = {'nickname': _nicknameController.text};
      }

      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('success') &&
            responseData['success'] == false) {
          final String errorMsg = responseData.containsKey('message')
              ? responseData['message']
              : '操作に失敗しました';

          setState(() {
            _errorMessage = errorMsg;
            _isLoading = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
          return;
        }

        final String roomId = widget.isJoiningRoom
            ? _roomIdController.text
            : responseData['roomId'];

        if (!mounted) return;

        Navigator.of(context).pop();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SelectGamePage(
              roomId: roomId,
              myNickname: _nicknameController.text,
            ),
          ),
        );

        final String successMessage =
            widget.isJoiningRoom ? '部屋に参加しました' : '部屋が作成されました';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleException(e);
    }
  }

  void _handleApiError(http.Response response) {
    try {
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      final String errorMsg = errorData.containsKey('message')
          ? '${errorData['message']}'
          : 'エラー: ${response.statusCode}';

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      final String errorMsg = '応答の解析に失敗しました: ${response.body}';
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
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
      _isLoading = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMsg)),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      width: AppLayout.dialogWidth,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.large,
          AppSpacing.large,
          AppSpacing.large,
          bottomInset > 0
              ? AppSpacing.large + bottomInset * 0.5
              : AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ニックネーム入力
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              labelText:
                  'ニックネームを入力（${AppLayout.minNicknameLength}〜${AppLayout.maxNicknameLength}文字）',
              hintText: '例：ボドゲハブ',
              helperText: '※「/」と「.」は使用できません',
            ),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }

              if (value.length > AppLayout.maxNicknameLength) {
                setState(() {
                  _errorMessage =
                      'ニックネームは${AppLayout.maxNicknameLength}文字以内で入力してください';
                });
              } else if (value.contains('/') || value.contains('.')) {
                setState(() {
                  _errorMessage = '「/」や「.」は使用できません';
                });
              }
            },
          ),

          // エラー表示 - カスタムウィジェットを使用
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Text(
                _errorMessage!,
                style: AppTextStyles.errorText,
              ),
            ),

          const SizedBox(height: AppSpacing.medium),

          // 部屋コード入力（部屋参加時のみ）
          if (widget.isJoiningRoom)
            TextField(
              controller: _roomIdController,
              enabled:
                  widget.initialRoomId == null || widget.initialRoomId!.isEmpty,
              decoration: const InputDecoration(
                labelText: '部屋コードを入力',
                hintText: 'abcdefg1234',
              ),
            ),

          const SizedBox(height: AppSpacing.xLarge),

          // ボタン群
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              LoadingButton(
                text: 'キャンセル',
                isLoading: false,
                isElevated: false,
                onPressed: () => Navigator.of(context).pop(),
              ),
              LoadingButton(
                text: widget.isJoiningRoom ? '部屋に参加する' : '部屋を作成する',
                isLoading: _isLoading,
                onPressed: _createRoom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
