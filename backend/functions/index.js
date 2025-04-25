// const {logger} = require("firebase-functions");
const {defineString} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();

const region = defineString("MY_FUNCTION_REGION", {default: "asia-northeast1"});

exports.createRoom = onRequest({region: region}, async (req, res) => {
  // CORSヘッダー設定とプリフライトリクエスト処理
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  try {
    const {nickname} = req.body;
    if (!nickname) {
      res.status(400).send({
        success: false,
        error: "invalid-argument",
        message: "不正なリクエストです。",
      });
      return;
    }

    // 部屋IDの作成＆重複チェック
    let roomId = generateRoomId();
    let isUnique = false;
    let attempts = 0;
    while (!isUnique && attempts < 10) {
      const roomDoc = await db.collection("rooms").doc(roomId).get();
      if (!roomDoc.exists) {
        isUnique = true;
      } else {
        roomId = generateRoomId();
        attempts++;
      }
    }
    if (!isUnique) {
      res.status(429).send({
        success: false,
        error: "resource-exhausted",
        message: "部屋作成に失敗しました。",
      });
      return;
    }

    const playerId = generatePlayerId();

    const roomData = {
      status: "accepting",
      players: [
        {
          player_id: playerId,
          nickname: nickname,
        },
      ],
      host_player: playerId,
      current_game: null,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    };

    await db.collection("rooms").doc(roomId).set(roomData);
    res.status(200).send({
      success: true,
      room_id: roomId,
      player_id: playerId,
    });
  } catch (error) {
    console.error("Error creating room:", error);
    res.status(500).send({
      success: false,
      error: "internal",
      message: "サーバーエラーが発生しました。",
    });
  }
});


exports.joinRoom = onRequest({region: region}, async (req, res) => {
  // CORSヘッダー設定とプリフライトリクエスト処理
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  const {nickname, roomId} = req.body;
  if (!nickname || !roomId) {
    res.status(400).send({
      success: false,
      error: "invalid-argument",
      message: "不正なリクエストです。",
    });
    return;
  }

  try {
    // 部屋の存在チェック
    const roomDoc = await db.collection("rooms").doc(roomId).get();
    if (!roomDoc.exists) {
      res.status(404).send({
        success: false,
        error: "not-found",
        message: "指定された部屋が見つかりません。",
      });
      return;
    }

    const roomData = roomDoc.data();

    // 部屋のステータスチェック
    if (roomData.status !== "accepting") {
      if (roomData.status === "in_progress") {
        res.status(200).send({
          success: false,
          error: "in_progress",
          message: "この部屋はすでにゲームが開始されています。",
        });
      } else if (roomData.status === "closed") {
        res.status(200).send({
          success: false,
          error: "closed",
          message: "この部屋はすでに閉じられています。",
        });
      } else if (roomData.status === "full") {
        res.status(200).send({
          success: false,
          error: "room_full",
          message: "部屋が満員です。",
        });
      } else {
        res.status(503).send({
          success: false,
          error: "unavailable",
          message: "この部屋は現在参加できません。",
        });
      }
      return;
    }

    // ニックネームの重複チェック
    const isDuplicateNickname = roomData.players.some(
        (player) => player.nickname === nickname,
    );

    if (isDuplicateNickname) {
      res.status(200).send({
        success: false,
        error: "duplicate_nickname",
        message: "このニックネームは既に使われています。",
      });
      return;
    }

    // 部屋の最大参加人数（将来的には別コレクション/ドキュメントで管理）
    const MAX_ROOM_PLAYERS = 4;

    const willBeFull = roomData.players.length + 1 >= MAX_ROOM_PLAYERS;

    // プレイヤーID生成
    const playerId = generatePlayerId();

    // プレイヤー追加
    const playerData = {
      player_id: playerId,
      nickname: nickname,
    };

    await db.collection("rooms").doc(roomId).update({
      players: FieldValue.arrayUnion(playerData),
      status: willBeFull ? "full" : "accepting",
      updated_at: FieldValue.serverTimestamp(),
    });

    res.status(200).send({
      success: true,
      room_id: roomId,
      player_id: playerId,
    });
  } catch (error) {
    console.error("Error joining room:", error);
    res.status(500).send({
      success: false,
      error: "internal",
      message: "サーバーエラーが発生しました。",
    });
  }
});

/**
 * 8文字のランダムな英数字 (特定の紛らわしい文字を除く) のルームIDを生成する。
 * @return {string} 生成されたランダムなルームID。
 */
function generateRoomId() {
  const chars = "abcdefghijkmnpqrstuvwxyz23456789"; // 紛らわしい文字を除外
  let result = "";
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * プレイヤーID(UUID)を生成する。
 * @return {string} プレイヤーID。
 */
function generatePlayerId() {
  return crypto.randomUUID();
}
