import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://asia-northeast1-bdghub-dev.cloudfunctions.net';

  static Future<Map<String, dynamic>> createRoom(
      String nickname, String uid) async {
    return _postRequest('/createRoom', {
      'nickname': nickname,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> joinRoom(
      String nickname, String roomId, String uid) async {
    return _postRequest('/joinRoom', {
      'nickname': nickname,
      'roomId': roomId,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> startGame(
      String roomId, String gameId) async {
    return _postRequest('/startGame', {
      'roomId': roomId,
      'gameId': gameId,
    });
  }

  static Future<Map<String, dynamic>> endGame(
    String roomId,
  ) async {
    return _postRequest('/endGame', {
      'roomId': roomId,
    });
  }

  static Future<Map<String, dynamic>> setReady(
    String roomId,
    String uid,
    String gameId,
  ) async {
    return _postRequest('/setReady', {
      'roomId': roomId,
      'uid': uid,
      'gameId': gameId,
    });
  }

  static Future<Map<String, dynamic>> leaveRoom(
      String nickname, String roomId, String uid) async {
    return _postRequest('/leaveRoom', {
      'nickname': nickname,
      'roomId': roomId,
      'uid': uid,
    });
  }

  // NGワード申告処理
  static Future<Map<String, dynamic>> declare0001(
    String roomId,
    String uid,
  ) async {
    return _postRequest('/declare0001', {
      'roomId': roomId,
      'uid': uid,
    });
  }

  static Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw http.Response(response.body, response.statusCode);
    }
  }
}
