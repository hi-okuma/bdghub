const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * 偏見プロフィールゲームのヒント入力リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function submitHint0004Handler(req, res) {
  const {roomId, nickname, hint} = req.body;

  if (!roomId || !nickname || !hint) {
    return sendError(
        res,
        "InvalidArgument",
        "不正なリクエストです。",
        400,
        {body: req.body},
    );
  }

  if (hint.length > 100) {
    return sendError(
        res,
        "InvalidArgument",
        "ヒントは100文字以内で入力してください。",
        400,
        {hint},
    );
  }

  const forbiddenChars = ["'", "\"", ";", "-", "=", "/", "*"];
  for (const char of forbiddenChars) {
    if (hint.includes(char)) {
      return sendError(
          res,
          "InvalidArgument",
          `ヒントに禁止文字「${char}」が含まれています。`,
          400,
          {hint},
      );
    }
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

      if (currentGameData.gameStatus !== "childTurn") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      if (nickname === currentGameData.currentParent) {
        throw new Error("ParentCannotsubmitHint");
      }

      const updatedHints = {...currentGameData.hints, [nickname]: hint};

      const childPlayers = currentGameData.players.filter(
          (player) => player.nickname !== currentGameData.currentParent,
      );
      const allChildrenSubmitted = childPlayers.every(
          (player) => updatedHints[player.nickname],
      );

      const updateData = {
        hints: updatedHints,
      };

      if (allChildrenSubmitted) {
        updateData.gameStatus = "parentTurn";
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`ヒント設定成功: roomId=${roomId}, nickname=${nickname}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`ヒント設定エラー: ${error.message}`, {
      roomId,
      nickname,
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
    } else if (errorMessage.includes("ParentCannotsubmitHint")) {
      return sendError(
          res,
          "ParentCannotsubmitHint",
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
  submitHint0004Handler,
};
