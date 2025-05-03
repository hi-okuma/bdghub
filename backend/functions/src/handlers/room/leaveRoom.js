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
  const {roomId, nickname} = req.body;

  if (!roomId || !nickname) {
    return sendError(
        res,
        "InvalidArgument",
        "部屋退出には部屋IDとニックネームが必要です。",
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
    const playerIndex = roomData.players.indexOf(nickname);

    if (playerIndex === -1) {
      return sendError(
          res,
          "PlayerNotFound",
          "指定されたプレイヤーが部屋内に存在しません。",
          404,
          {roomId, nickname},
      );
    }

    await updateRoomWithTransaction(roomRef, nickname);

    logger.info(`プレイヤー退出成功: ${nickname} from room ${roomId}`);
    return sendSuccess(res, {});
  } catch (error) {
    return sendError(
        res,
        "Internal",
        "サーバーエラーが発生しました。",
        500,
        {error: error.message, roomId, nickname},
    );
  }
}

/**
 * トランザクションを使用して部屋データを更新する
 * @param {object} roomRef - 部屋のドキュメント参照
 * @param {string} nickname - 退出するプレイヤーのニックネーム
 * @return {Promise} トランザクション処理のPromise
 */
async function updateRoomWithTransaction(roomRef, nickname) {
  return db.runTransaction(async (transaction) => {
    const latestRoomDoc = await transaction.get(roomRef);
    const latestRoomData = latestRoomDoc.data();

    const updatedPlayers = latestRoomData.players.filter(
        (playerName) => playerName !== nickname,
    );

    const updateData = prepareUpdateData(
        latestRoomData,
        updatedPlayers,
        nickname,
    );

    transaction.update(roomRef, updateData);
  });
}

/**
 * 部屋の更新データを準備する
 * @param {object} roomData - 部屋データ
 * @param {Array} updatedPlayers - 更新後のプレイヤーリスト
 * @param {string} removedNickname - 削除されたプレイヤーのニックネーム
 * @return {object} 更新データオブジェクト
 */
function prepareUpdateData(roomData, updatedPlayers, removedNickname) {
  const updateData = {
    players: updatedPlayers,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (roomData.hostPlayer === removedNickname && updatedPlayers.length > 0) {
    // ホストが退出した場合は、配列の最初のプレイヤーを新しいホストに設定
    updateData.hostPlayer = updatedPlayers[0];
    logger.info(`新しいホストプレイヤーを設定: ${updatedPlayers[0]}`);
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
