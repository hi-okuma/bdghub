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
  const {roomId, uid} = req.body;

  if (!roomId || !uid) {
    return sendError(
        res,
        "InvalidArgument",
        "退出に失敗しました。",
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

    if (!roomData.players[uid]) {
      return sendError(
          res,
          "PlayerNotFound",
          "指定されたプレイヤーが部屋内に存在しません。",
          404,
          {roomId, uid},
      );
    }

    await updateRoomWithTransaction(roomRef, uid);

    logger.info(`プレイヤー退出成功: uid=${uid} from room ${roomId}`);
    return sendSuccess(res, {});
  } catch (error) {
    return sendError(
        res,
        "Internal",
        "サーバーエラーが発生しました。",
        500,
        {error: error.message, roomId, uid},
    );
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
