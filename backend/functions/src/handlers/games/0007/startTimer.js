const {logger} = require("firebase-functions");
const {Timestamp} = require("firebase-admin/firestore");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

const ROUND_DURATION_MS = 120 * 1000;

/**
 * サンタ苦労ス（0007）のタイマー開始リクエストを処理するハンドラー
 * おじさんが「お題をめくってスタート」を押下した際に呼び出される。
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function startTimer0007Handler(request) {
  const {roomId, uid} = request.data;

  if (!roomId || !uid) {
    throwValidationError("不正なリクエストです。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0007");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwStructuredError("GameNotFound", "エラーが発生しました。リロードし、再度部屋を作り直してください。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throwGameStatusError("playing", currentGameData.gameStatus);
      }

      if (uid !== currentGameData.currentPresenter) {
        throwStructuredError("NotPresenter", "出題者ではありません。");
      }

      if (currentGameData.endsAt !== null && currentGameData.endsAt !== undefined) {
        throwStructuredError("AlreadyStarted", "既にタイマーが起動しています。");
      }

      const endsAt = Timestamp.fromMillis(Date.now() + ROUND_DURATION_MS);

      transaction.update(currentGameRef, {
        endsAt: endsAt,
      });
    });

    logger.info(`タイマー開始成功: roomId=${roomId}, uid=${uid}`, {
      roomId,
      uid,
    });

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("タイマー開始エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  startTimer0007Handler,
};
