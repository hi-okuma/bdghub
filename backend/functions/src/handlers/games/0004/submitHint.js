const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sanitizeUserInput} = require("../../../utils/sanitization");

/**
 * 偏見プロフィールゲームのヒント入力リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function submitHint0004Handler(request) {
  const {roomId, uid, hint} = request.data;

  if (!roomId || !uid || !hint) {
    throw new Error("ヒント送信に失敗しました。必要な情報が不足しています。");
  }

  try {
    const sanitizedHint = sanitizeUserInput(hint, {
      maxLength: 100,
      forbiddenChars: ["'", "\"", ";", "-", "=", "/", "*"],
      fieldName: "ヒント",
    });

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが見つかりません。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "childTurn") {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
      }

      if (uid === currentGameData.currentParent) {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
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
    logger.error("ヒント設定エラー", {
      error: error.message,
      roomId,
      uid,
    });
    throw error;
  }
}

module.exports = {
  submitHint0004Handler,
};
