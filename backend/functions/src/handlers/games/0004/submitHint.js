const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sanitizeUserInput} = require("../../../utils/sanitization");
const {
  throwValidationError,
  throwNotFoundError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 偏見プロフィールゲームのヒント入力リクエストを処理するハンドラー
 * @param {object} request リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function submitHint0004Handler(request) {
  const {roomId, uid, hint} = request.data;

  if (!roomId || !uid || !hint) {
    throwValidationError("ヒント送信に失敗しました。");
  }

  try {
    const sanitizedHint = sanitizeUserInput(hint, {
      maxLength: 100,
      forbiddenChars: ["'", "\"", ";", "-", "=", "/", "*"],
      allowLineBreaks: true,
      fieldName: "ヒント",
    });

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", "0004");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "childTurn") {
        throwGameStatusError("childTurn", currentGameData.gameStatus);
      }

      if (uid === currentGameData.currentParent) {
        throwStructuredError(
            "ParentCannotsubmitHint",
            "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
        );
      }

      const updatedHints = {...currentGameData.hints, [uid]: sanitizedHint};

      const childPlayers = Object.entries(currentGameData.players).filter(
          ([uid, player]) => uid !== currentGameData.currentParent,
      );
      const allChildrenSubmitted = childPlayers.every(
          ([uid, player]) => updatedHints[uid],
      );

      const updateData = {
        hints: updatedHints,
      };

      if (allChildrenSubmitted) {
        updateData.gameStatus = "parentTurn";
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`ヒント設定成功: roomId=${roomId}, uid=${uid}`, {
      roomId,
      uid,
    });

    return {
      success: true,
      message: "ヒントを送信しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    if (error.message.includes("ヒント")) {
      throwValidationError(error.message);
    }

    logger.error("ヒント設定エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  submitHint0004Handler,
};
