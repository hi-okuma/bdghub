import 'package:bodogehub/utils/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/error_handler.dart';
import '../0000_HubMain/select_game_page.dart';
import '../../components/custom_widgets.dart';
import '../../components/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
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
    final nicknameValidation =
        ValidationUtils.validateNickname(_nicknameController.text);
    if (!nicknameValidation.isValid) {
      setState(() {
        _errorMessage = nicknameValidation.errorMessage;
      });
      return;
    }

    if (widget.isJoiningRoom) {
      final roomIdValidation =
          ValidationUtils.validateRoomId(_roomIdController.text);
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
      // 匿名認証でUIDを取得
      final uid = await AuthService.ensureAuthenticated();
      Logger.log('🔐 認証完了、UID: $uid');

      final Map<String, dynamic> responseData;

      if (widget.isJoiningRoom) {
        responseData = await ApiService.joinRoom(
          context,
          _nicknameController.text,
          _roomIdController.text,
          uid,
        );
      } else {
        responseData = await ApiService.createRoom(
          context,
          _nicknameController.text,
          uid,
        );
      }

      final String roomId = widget.isJoiningRoom
          ? _roomIdController.text
          : responseData['roomId'];

      // Riverpodにユーザー情報を保存
      if (widget.isJoiningRoom) {
        ref.read(userProvider.notifier).joinRoom(
              nickname: _nicknameController.text,
              roomId: roomId,
              uid: uid,
            );
      } else {
        ref.read(userProvider.notifier).createRoom(
              nickname: _nicknameController.text,
              roomId: roomId,
              uid: uid,
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
    } on FirebaseFunctionsException catch (e) {
      // ApiServiceのエラーはErrorHandlerで処理される
      // その他のエラー（認証、Provider更新など）のためにcatchは残す
      Logger.log('部屋の作成/参加プロセスでエラー: $e');
      setState(() {
        _errorMessage = e.message ?? '部屋の作成/参加中にエラーが発生しました';
        _isLoading = false;
      });
    } catch (e) {
      Logger.log('予期せぬエラー: $e');
      setState(() {
        _errorMessage = '予期せぬエラーが発生しました。';
        _isLoading = false;
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
              labelText: 'ニックネームを入力',
              hintText: '例：ボドゲハブ',
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

          // URLから遷移時（部屋参加時のみ）
          if (widget.isJoiningRoom &&
              widget.initialRoomId != null &&
              widget.initialRoomId!.isNotEmpty)
            const SizedBox.shrink()

          // 部屋コード入力（部屋参加時のみ）
          else if (widget.isJoiningRoom) ...[
            const SizedBox(height: AppSpacing.large),
            TextField(
              controller: _roomIdController,
              enabled:
                  widget.initialRoomId == null || widget.initialRoomId!.isEmpty,
              decoration: const InputDecoration(
                labelText: '部屋コードを入力',
                hintText: 'ABCD123456',
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xLarge),

          // ボタン群
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'キャンセル',
                  style: AppTextStyles.subtitle2
                      .copyWith(color: AppTheme.secondaryTextColor),
                ),
              ),
              TextLoadingButton(
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
