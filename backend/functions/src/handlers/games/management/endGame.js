const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../../config/environment");

/**
 * ゲーム終了リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function endGameHandler(req, res) {
  const {roomId} = req.body;
  if (!roomId) {
    return sendError(
        res,
        "InvalidArgument",
        "不正なリクエストです。",
        400,
        {body: req.body},
    );
  }
  try {
    const maxRoomPlayers = await getMaxRoomPlayers();

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomDoc = await transaction.get(roomRef);
      if (!roomDoc.exists) {
        throw new Error("RoomNotFound");
      }
      const roomData = roomDoc.data();
      if (roomData.status !== "inProgress") {
        throw new Error(`InvalidRoomStatus:${roomData.status}`);
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

    logger.info(`ゲーム終了成功: roomId=${roomId}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`ゲーム終了エラー: ${error.message}`, {
      roomId,
      error: error.stack,
    });
    const errorMessage = error.message || "サーバーエラーが発生しました。";
    if (errorMessage.includes("RoomNotFound")) {
      return sendError(res, "RoomNotFound", "指定された部屋が見つかりません。", 404, {roomId});
    } else if (errorMessage.includes("InvalidRoomStatus")) {
      const status = errorMessage.split(":")[1] || "unknown";
      const statusErrors = {
        "accepting": {
          error: "NotInProgress",
          message: "この部屋ではゲームが進行中ではありません。",
          status: 200,
        },
        "full": {
          error: "NotInProgress",
          message: "この部屋ではゲームが進行中ではありません。",
          status: 200,
        },
        "closed": {
          error: "RoomClosed",
          message: "この部屋はすでに閉じられています。",
          status: 200,
        },
        "unknown": {
          error: "InvalidRoomStatus",
          message: "ゲームを終了できませんでした。",
          status: 200,
        },
      };
      const errorData = statusErrors[status] || statusErrors.unknown;
      return sendError(res, errorData.error, errorData.message, errorData.status);
    }
    return sendError(
        res,
        "Internal",
        "サーバーエラーが発生しました。",
        500,
        {error: errorMessage},
    );
  }
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
