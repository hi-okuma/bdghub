// backend/functions/src/handlers/games/0001/declare.js
const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * NGワードゲームの申告リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function declareHandler(req, res) {
  const {roomId, nickname} = req.body;

  if (!roomId || !nickname) {
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
      const currentGameRef = roomRef.collection("currentGame").doc("0001");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      const updatedPlayers = currentGameData.players.map((player) => {
        if (player.nickname === nickname) {
          return {...player, isAlive: false};
        }
        return player;
      });

      const alivePlayersCount = updatedPlayers.filter((player) => player.isAlive).length;

      const updateData = {
        players: updatedPlayers,
      };

      if (alivePlayersCount === 1) {
        const winner = updatedPlayers.find((player) => player.isAlive);
        updateData.players = updatedPlayers.map((player) => {
          if (player.nickname === winner.nickname) {
            return {
              ...player,
              point: (player.point || 0) + 1,
            };
          }
          return player;
        });

        updateData.gameStatus = "waiting";

        const ngWordsDoc = await transaction.get(
            db.collection("games").doc("0001")
                .collection("assets")
                .doc("ngWords"),
        );

        if (!ngWordsDoc.exists) {
          throw new Error("NGワードリストが見つかりません");
        }

        const ngWordsList = ngWordsDoc.data().words;
        const shuffledWords = shuffleArray(ngWordsList);

        updateData.players = updateData.players.map((player, index) => ({
          nickname: player.nickname,
          isReady: false,
          ngWord: [shuffledWords[index % shuffledWords.length]],
          isAlive: true,
          point: player.point || 0,
        }));
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`申告成功: roomId=${roomId}, nickname=${nickname}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`申告エラー: ${error.message}`, {
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
          "ゲームが進行中ではありません。",
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

/**
 * NGワードをシャッフルする
 * @param {Array<string>} array - 文字列が格納された配列
 * @return {Array<string>} ランダムに並び替えられた配列
 */
function shuffleArray(array) {
  const newArray = [...array];
  for (let i = newArray.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [newArray[i], newArray[j]] = [newArray[j], newArray[i]];
  }
  return newArray;
}

module.exports = {
  declareHandler,
};
