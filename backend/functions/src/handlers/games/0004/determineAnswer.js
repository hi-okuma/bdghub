const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwNotFoundError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 偏見プロフィールゲームの画像選択リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function determineAnswer0004Handler(request) {
  const {roomId, uid, imageIndex} = request.data;

  if (!roomId || !uid || imageIndex === undefined || imageIndex < 0 || imageIndex > 4) {
    throwValidationError("画像選択に失敗しました。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", "0004");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "parentTurn") {
        throwGameStatusError("parentTurn", currentGameData.gameStatus);
      }

      if (uid !== currentGameData.currentParent) {
        throwStructuredError(
            "OnlyParentCandetermineAnswer",
            "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
        );
      }

      transaction.update(currentGameRef, {
        parentSelectedIndex: imageIndex,
        gameStatus: "result",
      });
    });

    logger.info(`画像選択成功: roomId=${roomId}, uid=${uid}, imageIndex=${imageIndex}`, {
      roomId,
      uid,
      imageIndex,
    });

    return {
      success: true,
      message: "画像を選択しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("画像選択エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      imageIndex,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  determineAnswer0004Handler,
};
