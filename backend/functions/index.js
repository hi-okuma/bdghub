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
  const {nickname} = req.body;
  const roomId = generateRoomId();
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
