const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../utils/responseHandler");
const {generatePlayerId} = require("../../utils/idGenerator");
const {MAX_ROOM_PLAYERS} = require("../../config/environment");

/**
 * 部屋参加リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function joinRoomHandler(req, res) {
  const {nickname, roomId} = req.body;

  if (!nickname || !roomId) {
    return sendError(
        res,
        "InvalidArgument",
        "部屋参加にはニックネームと部屋IDが必要です。",
        400,
        {body: req.body},
    );
  }

  try {
    const roomDoc = await db.collection("rooms").doc(roomId).get();
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

    if (roomData.status !== "accepting") {
      return handleInvalidRoomStatus(res, roomData.status);
    }

    if (isNicknameDuplicate(roomData, nickname)) {
      return sendError(
          res,
          "DuplicateNickname",
          "このニックネームは既に使われています。",
          200,
          {roomId, nickname},
      );
    }

    const willBeFull = roomData.players.length + 1 >= MAX_ROOM_PLAYERS;

    const playerId = generatePlayerId();
    await addPlayerToRoom(roomId, playerId, nickname, willBeFull);

    logger.info(`プレイヤー参加成功: ${playerId} to room ${roomId}`, {
      nickname,
      willBeFull,
    });

    return sendSuccess(res, {
      roomId: roomId,
      playerId: playerId,
    });
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
 * 無効な部屋ステータスに対するエラーレスポンスを処理する
 * @param {object} res - レスポンスオブジェクト
 * @param {string} status - 部屋のステータス
 * @return {object} エラーレスポンス
 */
function handleInvalidRoomStatus(res, status) {
  const statusErrors = {
    inProgress: {
      error: "InProgress",
      message: "この部屋はすでにゲームが開始されています。",
      status: 200,
    },
    closed: {
      error: "Closed",
      message: "この部屋はすでに閉じられています。",
      status: 200,
    },
    full: {
      error: "RoomFull",
      message: "部屋が満員です。",
      status: 200,
    },
    default: {
      error: "Unavailable",
      message: "この部屋は現在参加できません。",
      status: 503,
    },
  };

  const errorData = statusErrors[status] || statusErrors.default;
  return sendError(res, errorData.error, errorData.message, errorData.status);
}

/**
 * ニックネームが部屋内で重複しているかをチェックする
 * @param {object} roomData - 部屋データ
 * @param {string} nickname - チェックするニックネーム
 * @return {boolean} 重複している場合はtrue、そうでない場合はfalse
 */
function isNicknameDuplicate(roomData, nickname) {
  return roomData.players.some((player) => player.nickname === nickname);
}

/**
 * プレイヤーを部屋に追加する
 * @param {string} roomId - 部屋ID
 * @param {string} playerId - プレイヤーID
 * @param {string} nickname - ニックネーム
 * @param {boolean} willBeFull - 部屋が満員になるかどうか
 * @return {Promise} 更新処理のPromise
 */
async function addPlayerToRoom(roomId, playerId, nickname, willBeFull) {
  const playerData = {
    playerId: playerId,
    nickname: nickname,
  };

  return db.collection("rooms").doc(roomId).update({
    players: FieldValue.arrayUnion(playerData),
    status: willBeFull ? "full" : "accepting",
    updatedAt: FieldValue.serverTimestamp(),
  });
}

module.exports = {
  joinRoomHandler,
};
