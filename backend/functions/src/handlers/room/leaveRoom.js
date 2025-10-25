const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../utils/errorHandler");

/**
 * 部屋退出リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function leaveRoomHandler(request) {
  const {roomId, uid} = request.data;

  if (!roomId || !uid) {
    throwValidationError("退出に失敗しました。");
  }

  try {
    const roomRef = db.collection("rooms").doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      throwNotFoundError("部屋", roomId);
    }

    const roomData = roomDoc.data();

    if (!roomData.players[uid]) {
      throwNotFoundError("プレイヤー", uid);
    }

    const updateData = {
      [`players.${uid}`]: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    const remainingPlayerUids = Object.keys(roomData.players).filter(
        (playerUid) => playerUid !== uid,
    );

    if (roomData.hostPlayer === uid && remainingPlayerUids.length > 0) {
      updateData.hostPlayer = remainingPlayerUids[0];
      logger.info(`新しいホストプレイヤーを設定: ${remainingPlayerUids[0]}`);
    }

    if (remainingPlayerUids.length === 0) {
      updateData.status = "closed";
      logger.info(`部屋を閉鎖します: ${roomId}`);
    } else if (roomData.status === "full") {
      updateData.status = "accepting";
    }

    await roomRef.update(updateData);

    logger.info(`プレイヤー退出成功: uid=${uid} from room ${roomId}`, {
      roomId,
      uid,
    });

    return {
      success: true,
      message: "部屋から退出しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("部屋退出エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  leaveRoomHandler,
};
