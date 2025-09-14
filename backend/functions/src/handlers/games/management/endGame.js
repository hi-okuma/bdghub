const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../../config/environment");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * ゲーム終了リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function endGameHandler(request) {
  const {roomId} = request.data;

  if (!roomId) {
    throwValidationError("ゲーム終了に失敗しました。");
  }

  try {
    const maxRoomPlayers = await getMaxRoomPlayers();

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throwNotFoundError("部屋", roomId);
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
    if (error.code && error.details) {
      throw error;
    }

    logger.error("ゲーム終了エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * 無効な部屋ステータスに対するエラーを投げる
 * @param {string} status - 部屋のステータス
 */
function handleInvalidRoomStatus(status) {
  const statusErrorMap = {
    "accepting": {
      code: "InvalidRoomStatus",
      message: "この部屋ではゲームが進行中ではありません。",
    },
    "full": {
      code: "InvalidRoomStatus",
      message: "この部屋ではゲームが進行中ではありません。",
    },
    "closed": {
      code: "RoomClosed",
      message: "この部屋はすでに閉じられています。",
    },
  };

  const errorInfo = statusErrorMap[status] || {
    code: "InvalidRoomStatus",
    message: "ゲームを終了できませんでした。",
  };

  throwStructuredError(errorInfo.code, errorInfo.message);
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
