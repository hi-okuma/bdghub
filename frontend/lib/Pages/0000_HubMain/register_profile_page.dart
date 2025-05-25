import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../0000_HubMain/select_game_page.dart';
import '../../components/custom_widgets.dart';
import '../../components/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/validation_utils.dart';
import '/providers/user_provider.dart';

class RegisterProfilePage extends ConsumerStatefulWidget {
  final bool isJoiningRoom;
  final String? initialRoomId;

  const RegisterProfilePage({
    super.key,
    this.isJoiningRoom = false,
    this.initialRoomId,
  });

  @override
  ConsumerState<RegisterProfilePage> createState() =>
      _RegisterProfilePageState();
}

class _RegisterProfilePageState extends ConsumerState<RegisterProfilePage> {
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

  Future<void> _createRoom() async {
    // バリデーション
    final nicknameValidation = ValidationUtils.validateNickname(_nicknameController.text);
    if (!nicknameValidation.isValid) {
      setState(() {
        _errorMessage = nicknameValidation.errorMessage;
      });
      return;
    }

    if (widget.isJoiningRoom) {
      final roomIdValidation = ValidationUtils.validateRoomId(_roomIdController.text);
      if (!roomIdValidation.isValid) {
        setState(() {
          _errorMessage = roomIdValidation.errorMessage;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> responseData;

      if (widget.isJoiningRoom) {
        responseData = await ApiService.joinRoom(
          _nicknameController.text,
          _roomIdController.text,
        );
      } else {
        responseData = await ApiService.createRoom(_nicknameController.text);
      }

      // APIエラーレスポンスのチェック
      if (responseData.containsKey('success') && responseData['success'] == false) {
        ApiErrorHandler.handleApiError(context, responseData, (error) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        });
        return;
      }

      final String roomId = widget.isJoiningRoom
          ? _roomIdController.text
          : responseData['roomId'];

      // Riverpodにユーザー情報を保存
      if (widget.isJoiningRoom) {
        ref.read(userProvider.notifier).joinRoom(
              nickname: _nicknameController.text,
              roomId: roomId,
            );
      } else {
        ref.read(userProvider.notifier).createRoom(
              nickname: _nicknameController.text,
              roomId: roomId,
            );
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SelectGamePage(),
        ),
      );

      final String successMessage =
          widget.isJoiningRoom ? '部屋に参加しました' : '部屋が作成されました';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      ApiErrorHandler.handleException(context, e, (error) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      });
    }
  }

  void _onNicknameChanged(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    final validation = ValidationUtils.validateNickname(value);
    if (!validation.isValid && value.isNotEmpty) {
      setState(() {
        _errorMessage = validation.errorMessage;
      });
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
            onChanged: _onNicknameChanged,
          ),

          // エラー表示
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
