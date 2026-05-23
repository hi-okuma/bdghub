import 'package:bodogehub/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ApiService {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  static Future<dynamic> _callFunction(
    String functionName,
    BuildContext context,
    Map<String, dynamic> parameters, {
    bool handleError = true,
    // 特定のエラーコード時にスナックバーを表示させないためのオプションを追加
    List<String> ignoredErrorCodes = const [],
  }) async {
    final callable = _functions.httpsCallable(functionName);
    try {
      final result = await callable.call(parameters);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // 1. handleError が true である
      // 2. かつ、今回の例外コードが ignoredErrorCodes に含まれていない
      // この条件を満たす場合のみ共通エラーハンドラ（スナックバー表示等）を実行する
      if (handleError && !ignoredErrorCodes.contains(e.code)) {
        ErrorHandler.handleFirebaseFunctionsException(context, e);
      }
      rethrow;
    } catch (e) {
      if (handleError) {
        ErrorHandler.handleGenericError(context, e);
      }
      rethrow;
    }
  }

  static Future<dynamic> createRoom(
    BuildContext context,
    String nickname,
    String uid, {
    bool handleError = false,
  }) async {
    return _callFunction(
      'createRoom',
      context,
      {
        'nickname': nickname,
        'uid': uid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> joinRoom(
    BuildContext context,
    String nickname,
    String roomId,
    String uid, {
    bool handleError = false,
  }) async {
    return _callFunction(
      'joinRoom',
      context,
      {
        'nickname': nickname,
        'roomId': roomId,
        'uid': uid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> startGame(
    BuildContext context,
    String roomId,
    String gameId, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'startGame',
      context,
      {
        'roomId': roomId,
        'gameId': gameId,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> endGame(
    BuildContext context,
    String roomId, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'endGame',
      context,
      {
        'roomId': roomId,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> setReady(
    BuildContext context,
    String roomId,
    String uid,
    String gameId, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'setReady',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'gameId': gameId,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> leaveRoom(
    BuildContext context,
    String roomId,
    String uid, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'leaveRoom',
      context,
      {
        'roomId': roomId,
        'uid': uid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> declare0001(
    BuildContext context,
    String roomId,
    String uid, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'declare0001',
      context,
      {
        'roomId': roomId,
        'uid': uid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> reportResult0002(
    BuildContext context,
    String roomId,
    bool result,
    String answererUid, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'reportResult0002',
      context,
      {
        'roomId': roomId,
        'result': result,
        'answererUid': answererUid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> submitHint0004(
    BuildContext context,
    String roomId,
    String uid,
    String hint, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'submitHint0004',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'hint': hint,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> determineAnswer0004(
    BuildContext context,
    String roomId,
    String uid,
    int imageIndex, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'determineAnswer0004',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'imageIndex': imageIndex,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> proceedToNext0004(
    BuildContext context,
    String roomId,
    String uid,
    String? bestHintPlayerUid, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'proceedToNext0004',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'bestHintPlayerUid': bestHintPlayerUid,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> proceedToNext0005(
    BuildContext context,
    String roomId,
    bool isCorrect, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'proceedToNext0005',
      context,
      {
        'roomId': roomId,
        'isCorrect': isCorrect,
      },
      handleError: handleError,
    );
  }

  static Future<dynamic> confirmCard0006(
    BuildContext context,
    String roomId,
    String uid,
    String cardId, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'confirmCard0006',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'cardId': cardId,
      },
      handleError: handleError,
      ignoredErrorCodes: ['InvalidArgument'],
    );
  }

  static Future<dynamic> adoptValue0006(
    BuildContext context,
    String roomId,
    String uid,
    String valueType, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'adoptValue0006',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'valueType': valueType,
      },
      handleError: handleError,
      ignoredErrorCodes: ['InvalidArgument'],
    );
  }

  static Future<dynamic> startTimer0007(
    BuildContext context,
    String roomId,
    String uid, {
    bool handleError = true,
  }) async {
    return _callFunction(
      'startTimer0007',
      context,
      {
        'roomId': roomId,
        'uid': uid,
      },
      handleError: handleError,
      ignoredErrorCodes: ['AlreadyStarted'],
    );
  }

  static Future<dynamic> reportResult0007(
    BuildContext context,
    String roomId,
    String uid,
    bool result, {
    String? answererUid,
    bool bonus = false,
    bool handleError = true,
  }) async {
    return _callFunction(
      'reportResult0007',
      context,
      {
        'roomId': roomId,
        'uid': uid,
        'result': result,
        'answererUid': answererUid,
        'bonus': bonus,
      },
      handleError: handleError,
    );
  }
}
