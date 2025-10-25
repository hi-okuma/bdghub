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
  }) async {
    final callable = _functions.httpsCallable(functionName);
    try {
      final result = await callable.call(parameters);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // handleErrorがtrueの場合のみスナックバーを表示
      if (handleError) {
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
}
