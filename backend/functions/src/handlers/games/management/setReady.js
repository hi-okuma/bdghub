const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * ゲーム準備完了リクエストの共通ハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function setReadyHandler(req, res) {
  const {roomId, nickname, gameId} = req.body;

  if (!roomId || !nickname || !gameId) {
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
      const currentGameRef = roomRef.collection("currentGame").doc(gameId);
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "waiting") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      const updatedPlayers = currentGameData.players.map((player) => {
        if (player.nickname === nickname) {
          return {...player, isReady: true};
        }
        return player;
      });

      const allReady = updatedPlayers.every((player) => player.isReady);

      const updateData = {
        players: updatedPlayers,
      };

      if (allReady) {
        updateData.gameStatus = "playing";
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`準備完了設定成功: roomId=${roomId}, nickname=${nickname}, gameId=${gameId}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`準備完了設定エラー: ${error.message}`, {
      roomId,
      nickname,
      gameId,
      error: error.stack,
    });

    const errorMessage = error.message || "サーバーエラーが発生しました。";

    if (errorMessage.includes("GameNotFound")) {
      return sendError(res, "GameNotFound", "ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。", 404, {roomId});
    } else if (errorMessage.includes("InvalidGameStatus")) {
      const status = errorMessage.split(":")[1] || "unknown";
      return sendError(
          res,
          "InvalidGameStatus",
          "ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。",
          400,
          {status},
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
  setReadyHandler,
};
