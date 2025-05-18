const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * 偏見プロフィールゲームの画像選択リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function determineAnswer0004Handler(req, res) {
  const {roomId, nickname, imageIndex} = req.body;

  if (!roomId || !nickname || imageIndex === undefined || imageIndex < 0 || imageIndex > 4) {
    return sendError(
        res,
        "InvalidArgument",
        "不正なリクエストです。",
        400,
        {body: req.body},
    );
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "parentTurn") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      if (nickname !== currentGameData.currentParent) {
        throw new Error("OnlyParentCandetermineAnswer");
      }

      transaction.update(currentGameRef, {
        parentSelectedIndex: imageIndex,
        gameStatus: "result",
      });
    });

    logger.info(`画像選択成功: roomId=${roomId}, nickname=${nickname}, imageIndex=${imageIndex}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`画像選択エラー: ${error.message}`, {
      roomId,
      nickname,
      imageIndex,
      error: error.stack,
    });

    const errorMessage = error.message || "サーバーエラーが発生しました。";

    if (errorMessage.includes("GameNotFound")) {
      return sendError(res, "GameNotFound", "ゲームが見つかりません。", 404, {roomId});
    } else if (errorMessage.includes("InvalidGameStatus")) {
      const status = errorMessage.split(":")[1] || "unknown";
      return sendError(
          res,
          "InvalidGameStatus",
          "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
          400,
          {status},
      );
    } else if (errorMessage.includes("OnlyParentCandetermineAnswer")) {
      return sendError(
          res,
          "OnlyParentCandetermineAnswer",
          "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
          400,
      );
    }

    return sendError(
        res,
        "Internal",
        "サーバーエラーが発生しました。",
        500,
        {error: errorMessage},
    );
  }
}

module.exports = {
  determineAnswer0004Handler,
};
