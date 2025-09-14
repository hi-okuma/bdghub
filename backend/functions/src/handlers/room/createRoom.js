const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {generateRoomId} = require("../../utils/idGenerator");
const {sanitizeUserInput} = require("../../utils/sanitization");
const {
  throwValidationError,
  throwStructuredError,
} = require("../../utils/errorHandler");

/**
 * 部屋作成リクエストを処理するハンドラー
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function createRoomHandler(request) {
  const {nickname, uid} = request.data;

  if (!nickname || !uid) {
    throwValidationError("部屋作成に失敗しました。");
  }

  try {
    const sanitizedNickname = sanitizeUserInput(nickname, {
      maxLength: 10,
      forbiddenChars: ["/", "."],
      fieldName: "ニックネーム",
    });

    const roomId = await generateUniqueRoomId();
    if (!roomId) {
      throwStructuredError(
          "ResourceExhausted",
          "部屋作成に失敗しました。しばらく時間をおいて再度お試しください。",
      );
    }

    const roomData = createRoomData(sanitizedNickname, uid);

    await db.collection("rooms").doc(roomId).set(roomData);

    logger.info(`部屋作成成功: ${roomId}`, {
      nickname: sanitizedNickname,
      uid,
    });

    return {
      roomId: roomId,
      nickname: sanitizedNickname,
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    if (error.message.includes("ニックネーム")) {
      throwValidationError(error.message);
    }

    logger.error("部屋作成エラー", {
      error: error.message,
      stack: error.stack,
      nickname,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
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
  const MAX_ATTEMPTS = 3;

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
 * @param {string} nickname - プレイヤーのニックネーム（サニタイズ済み）
 * @param {string} uid - プレイヤーのUID
 * @return {object} 作成された部屋データオブジェクト
 */
function createRoomData(nickname, uid) {
  return {
    status: "accepting",
    players: {
      [uid]: {nickname: nickname},
    },
    hostPlayer: uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

module.exports = {
  createRoomHandler,
};
