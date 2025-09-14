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

    await updateRoomWithTransaction(roomRef, uid);

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

/**
 * トランザクションを使用して部屋データを更新する
 * @param {object} roomRef - 部屋のドキュメント参照
 * @param {object} uid - プレイヤーのUID
 * @return {Promise} トランザクション処理のPromise
 */
async function updateRoomWithTransaction(roomRef, uid) {
  return db.runTransaction(async (transaction) => {
    const latestRoomDoc = await transaction.get(roomRef);
    const latestRoomData = latestRoomDoc.data();

    const updatedPlayers = {...latestRoomData.players};
    delete updatedPlayers[uid];

    const updateData = prepareUpdateData(
        latestRoomData,
        updatedPlayers,
        uid,
    );

    transaction.update(roomRef, updateData);
  });
}

/**
 * 部屋の更新データを準備する
 * @param {object} roomData - 部屋データ
 * @param {Object} updatedPlayers - 更新後のプレイヤーオブジェクト
 * @param {string} removedUid - 削除されたプレイヤーのUID
 * @return {object} 更新データオブジェクト
 */
function prepareUpdateData(roomData, updatedPlayers, removedUid) {
  const updateData = {
    players: updatedPlayers,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const remainingPlayerUids = Object.keys(updatedPlayers);

  if (roomData.hostPlayer === removedUid && remainingPlayerUids.length > 0) {
    updateData.hostPlayer = remainingPlayerUids[0];
    logger.info(`新しいホストプレイヤーを設定: ${remainingPlayerUids[0]}`);
  }

  if (remainingPlayerUids.length === 0) {
    updateData.status = "closed";
    logger.info(`部屋を閉鎖します: ${roomData.id}`);
  } else if (roomData.status === "full") {
    updateData.status = "accepting";
  }

  return updateData;
}

module.exports = {
  leaveRoomHandler,
};
