const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../utils/responseHandler");

/**
 * 部屋退出リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function leaveRoomHandler(req, res) {
  const {roomId, playerId} = req.body;

  if (!roomId || !playerId) {
    return sendError(
        res,
        "InvalidArgument",
        "部屋退出には部屋IDとプレイヤーIDが必要です。",
        400,
        {body: req.body},
    );
  }

  try {
    const roomRef = db.collection("rooms").doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      return sendError(
          res,
          "NotFound",
          "指定された部屋が見つかりません。",
          404,
          {roomId},
      );
    }

    const roomData = roomDoc.data();
    const playerIndex = roomData.players.findIndex(
        (player) => player.playerId === playerId,
    );

    if (playerIndex === -1) {
      return sendError(
          res,
          "PlayerNotFound",
          "指定されたプレイヤーが部屋内に存在しません。",
          404,
          {roomId, playerId},
      );
    }

    await updateRoomWithTransaction(roomRef, playerId);

    logger.info(`プレイヤー退出成功: ${playerId} from room ${roomId}`);
    return sendSuccess(res, {}, "部屋から退出しました。");
  } catch (error) {
    return sendError(
        res,
        "Internal",
        "サーバーエラーが発生しました。",
        500,
        {error: error.message, roomId, playerId},
    );
  }
}

/**
 * トランザクションを使用して部屋データを更新する
 * @param {object} roomRef - 部屋のドキュメント参照
 * @param {string} playerId - 退出するプレイヤーID
 * @return {Promise} トランザクション処理のPromise
 */
async function updateRoomWithTransaction(roomRef, playerId) {
  return db.runTransaction(async (transaction) => {
    const latestRoomDoc = await transaction.get(roomRef);
    const latestRoomData = latestRoomDoc.data();

    const updatedPlayers = latestRoomData.players.filter(
        (player) => player.playerId !== playerId,
    );

    const updateData = prepareUpdateData(latestRoomData, updatedPlayers, playerId);

    transaction.update(roomRef, updateData);
  });
}

/**
 * 部屋の更新データを準備する
 * @param {object} roomData - 部屋データ
 * @param {Array} updatedPlayers - 更新後のプレイヤーリスト
 * @param {string} removedPlayerId - 削除されたプレイヤーID
 * @return {object} 更新データオブジェクト
 */
function prepareUpdateData(roomData, updatedPlayers, removedPlayerId) {
  const updateData = {
    players: updatedPlayers,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (roomData.hostPlayer === removedPlayerId && updatedPlayers.length > 0) {
    updateData.hostPlayer = updatedPlayers[0].playerId;
    logger.info(`新しいホストプレイヤーを設定: ${updatedPlayers[0].playerId}`);
  }

  if (updatedPlayers.length === 0) {
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
