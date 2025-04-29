const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../utils/responseHandler");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../config/environment");

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
    let maxRoomPlayers = DEFAULT_MAX_ROOM_PLAYERS;
    try {
      const serviceConfigDoc = await db.collection("serviceConfig").doc("global").get();
      if (serviceConfigDoc.exists) {
        maxRoomPlayers = serviceConfigDoc.data().maxPlayersPerRoom || DEFAULT_MAX_ROOM_PLAYERS;
      }
    } catch (configError) {
      logger.warn("serviceConfig取得エラー、デフォルト値を使用します", {error: configError.message});
    }

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
    const roomRef = db.collection("rooms").doc(roomId);

    if (roomData.status === "full" && roomData.players.length < maxRoomPlayers) {
      logger.info(`部屋ID=${roomId} はfullですが、最大人数が引き上げられたためacceptingに戻します。`);
      await roomRef.update({
        status: "accepting",
        updatedAt: FieldValue.serverTimestamp(),
      });
      roomData.status = "accepting";
    }

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

    if (roomData.players.length >= maxRoomPlayers) {
      if (roomData.status === "accepting") {
        try {
          await roomRef.update({
            status: "full",
            updatedAt: FieldValue.serverTimestamp(),
          });
          logger.info(`部屋が満員になったためステータスを更新: roomId=${roomId}`);
        } catch (updateError) {
          logger.error(`満員時のステータス更新に失敗: roomId=${roomId}`, {error: updateError});
        }
      }

      return sendError(
          res,
          "RoomFull",
          "部屋が満員です。",
          200,
          {roomId},
      );
    }

    const willBeFull = roomData.players.length + 1 >= maxRoomPlayers;
    await addPlayerToRoom(roomId, nickname, willBeFull);

    logger.info(`プレイヤー参加成功: ${nickname} to room ${roomId}`, {
      nickname,
      willBeFull,
    });

    return sendSuccess(res, {
      roomId: roomId,
      nickname: nickname,
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
  return roomData.players.includes(nickname);
}

/**
 * プレイヤーを部屋に追加する
 * @param {string} roomId - 部屋ID
 * @param {string} nickname - ニックネーム
 * @param {boolean} willBeFull - 部屋が満員になるかどうか
 * @return {Promise} 更新処理のPromise
 */
async function addPlayerToRoom(roomId, nickname, willBeFull) {
  return db.collection("rooms").doc(roomId).update({
    players: FieldValue.arrayUnion(nickname), // 文字列をそのまま追加
    status: willBeFull ? "full" : "accepting",
    updatedAt: FieldValue.serverTimestamp(),
  });
}

module.exports = {
  joinRoomHandler,
};
