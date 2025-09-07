const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");

/**
 * 偏見プロフィールゲームの画像選択リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function determineAnswer0004Handler(request) {
  const {roomId, uid, imageIndex} = request.data;

  if (!roomId || !uid || imageIndex === undefined || imageIndex < 0 || imageIndex > 4) {
    throw new Error("画像選択に失敗しました。必要な情報が不足しているか、無効な選択です。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが見つかりません。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "parentTurn") {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
      }

      if (uid !== currentGameData.currentParent) {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
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
    logger.error("画像選択エラー", {
      error: error.message,
      roomId,
      uid,
      imageIndex,
    });
    throw error;
  }
}

module.exports = {
  determineAnswer0004Handler,
};
