const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../utils/responseHandler");
const {generateRoomId} = require("../../utils/idGenerator");

/**
 * 部屋作成リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function createRoomHandler(req, res) {
  const {nickname} = req.body;

  if (!nickname) {
    return sendError(
        res,
        "InvalidArgument",
        "部屋作成にはニックネームが必要です。",
        400,
        {body: req.body},
    );
  }

  try {
    const roomId = await generateUniqueRoomId();
    if (!roomId) {
      return sendError(
          res,
          "ResourceExhausted",
          "部屋作成に失敗しました。",
          429,
      );
    }

    const roomData = createRoomData(nickname);

    await db.collection("rooms").doc(roomId).set(roomData);
    logger.info(`部屋作成成功: ${roomId}`, {nickname});

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
        {error: error.message},
    );
  }
}

/**
 * 重複しないユニークな部屋IDを生成する
 * @return {string|null} 生成された部屋ID、または生成に失敗した場合はnull
 */
async function generateUniqueRoomId() {
  let roomId = generateRoomId();
  let isUnique = false;
  let attempts = 0;
  const MAX_ATTEMPTS = 10;

  while (!isUnique && attempts < MAX_ATTEMPTS) {
    const roomDoc = await db.collection("rooms").doc(roomId).get();
    if (!roomDoc.exists) {
      isUnique = true;
    } else {
      roomId = generateRoomId();
      attempts++;
    }
  }

  return isUnique ? roomId : null;
}

/**
 * 部屋データオブジェクトを作成する
 * @param {string} nickname - プレイヤーのニックネーム
 * @return {object} 作成された部屋データオブジェクト
 */
function createRoomData(nickname) {
  return {
    status: "accepting",
    players: [nickname],
    hostPlayer: nickname,
    currentGame: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

module.exports = {
  createRoomHandler,
};
