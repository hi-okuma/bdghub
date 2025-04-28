const crypto = require("crypto");
const {ROOM_ID_LENGTH} = require("../config/environment");

/**
 * ランダムな英数字のルームIDを生成する
 * 紛らわしい文字は除外
 * @param {number} length - 生成するIDの長さ
 * @return {string} 生成されたランダムなルームID
 */
function generateRoomId(length = ROOM_ID_LENGTH) {
  const chars = "abcdefghijkmnpqrstuvwxyz23456789"; // 紛らわしい文字を除外
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * UUIDを使用してプレイヤーIDを生成する
 * @return {string} 生成されたプレイヤーID
 */
function generatePlayerId() {
  return crypto.randomUUID();
}

module.exports = {
  generateRoomId,
  generatePlayerId,
};
