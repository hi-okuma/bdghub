import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

class ApiService {
  // リージョンが東京(asia-northeast1)の場合、指定が必要
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  // 共通のCloud Functions呼び出しメソッド
  static Future<Map<String, dynamic>> _callFunction(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(parameters);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // Firebase Functions特有のエラー
      throw Exception('Firebase Functions error (${e.code}): ${e.message}');
    } catch (e) {
      // その他の予期しないエラー
      throw Exception('Unexpected error: $e');
    }
  }

  // 各APIメソッドをシンプルに
  static Future<Map<String, dynamic>> createRoom(
    String nickname,
    String uid,
  ) async {
    return _callFunction('createRoom', {
      'nickname': nickname,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> joinRoom(
    String nickname,
    String roomId,
    String uid,
  ) async {
    return _callFunction('joinRoom', {
      'nickname': nickname,
      'roomId': roomId,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> startGame(
    String roomId,
    String gameId,
  ) async {
    return _callFunction('startGame', {
      'roomId': roomId,
      'gameId': gameId,
    });
  }

  static Future<Map<String, dynamic>> endGame(
    String roomId,
  ) async {
    return _callFunction('endGame', {
      'roomId': roomId,
    });
  }

  static Future<Map<String, dynamic>> setReady(
    String roomId,
    String uid,
    String gameId,
  ) async {
    return _callFunction('setReady', {
      'roomId': roomId,
      'uid': uid,
      'gameId': gameId,
    });
  }

  static Future<Map<String, dynamic>> leaveRoom(
    String roomId,
    String uid,
  ) async {
    return _callFunction('leaveRoom', {
      'roomId': roomId,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> declare0001(
    String roomId,
    String uid,
  ) async {
    return _callFunction('declare0001', {
      'roomId': roomId,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> submitHint0004(
    String roomId,
    String uid,
    String hint,
  ) async {
    return _callFunction('submitHint0004', {
      'roomId': roomId,
      'uid': uid,
      'hint': hint,
    });
  }

  static Future<Map<String, dynamic>> determineAnswer0004(
    String roomId,
    String uid,
    int imageIndex,
  ) async {
    return _callFunction('determineAnswer0004', {
      'roomId': roomId,
      'uid': uid,
      'imageIndex': imageIndex,
    });
  }

  static Future<Map<String, dynamic>> proceedToNext0004(
    String roomId,
    String uid,
    String? bestHintPlayerUid,
  ) async {
    return _callFunction('proceedToNext0004', {
      'roomId': roomId,
      'uid': uid,
      'bestHintPlayerUid': bestHintPlayerUid,
    });
  }
}
