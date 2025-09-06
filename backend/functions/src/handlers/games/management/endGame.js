const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../../config/environment");

/**
 * ゲーム終了リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function endGameHandler(request) {
  const {roomId} = request.data;

  if (!roomId) {
    throw new Error("ゲーム終了に失敗しました。必要な情報が不足しています。");
  }

  try {
    const maxRoomPlayers = await getMaxRoomPlayers();

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throw new Error("指定された部屋が見つかりません。");
      }

      const roomData = roomDoc.data();

      if (roomData.status !== "inProgress") {
        handleInvalidRoomStatus(roomData.status);
      }

      const currentGameSnap = await transaction.get(roomRef.collection("currentGame"));

      currentGameSnap.docs.forEach((doc) => {
        transaction.delete(doc.ref);
      });

      transaction.update(roomRef, {
        status: roomData.players.length >= maxRoomPlayers ? "full" : "accepting",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info(`ゲーム終了成功: roomId=${roomId}`, {
      roomId,
    });

    return {
      success: true,
      message: "ゲームを終了しました。",
    };
  } catch (error) {
    logger.error("ゲーム終了エラー", {
      error: error.message,
      roomId,
    });
    throw error;
  }
}

/**
 * 無効な部屋ステータスに対するエラーを投げる
 * @param {string} status - 部屋のステータス
 */
function handleInvalidRoomStatus(status) {
  const statusErrors = {
    "accepting": "この部屋ではゲームが進行中ではありません。",
    "full": "この部屋ではゲームが進行中ではありません。",
    "closed": "この部屋はすでに閉じられています。",
    "unknown": "ゲームを終了できませんでした。",
  };

  const errorMessage = statusErrors[status] || statusErrors.unknown;
  throw new Error(errorMessage);
}

/**
 * サービス設定から最大プレイヤー数を取得する
 * @return {Promise<number>} 最大プレイヤー数
 */
async function getMaxRoomPlayers() {
  try {
    const serviceConfigDoc = await db.collection("serviceConfig").doc("global").get();
    if (serviceConfigDoc.exists) {
      return serviceConfigDoc.data().maxPlayersPerRoom || DEFAULT_MAX_ROOM_PLAYERS;
    }
  } catch (error) {
    logger.warn("serviceConfig取得エラー、デフォルト値を使用します", {error: error.message});
  }
  return DEFAULT_MAX_ROOM_PLAYERS;
}

module.exports = {
  endGameHandler,
};
