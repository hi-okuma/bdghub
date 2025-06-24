const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * NGワードゲームの申告リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function declare0001Handler(req, res) {
  const {roomId, uid} = req.body;

  if (!roomId || !uid) {
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

      const updatedPlayers = {...currentGameData.players};
      updatedPlayers[uid] = {...updatedPlayers[uid], isAlive: false};
      const alivePlayersCount = Object.values(updatedPlayers).filter((player) => player.isAlive).length;

      const updateData = {
        players: updatedPlayers,
      };

      if (alivePlayersCount === 1) {
        const winnerUid = Object.entries(updatedPlayers).find(([uid, player]) => player.isAlive)[0];
        updateData.players = Object.fromEntries(
          Object.entries(updatedPlayers).map(([uid, player]) => [
            uid,
            uid === winnerUid
              ? {...player, point: (player.point || 0) + 1}
              : player
          ])
        );

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

        updateData.players = Object.fromEntries(
          Object.keys(updatedPlayers).map((uid, index) => [
            uid,
            {
              isReady: false,
              ngWord: [shuffledWords[index % shuffledWords.length]],
              isAlive: true,
              point: updatedPlayers[uid].point || 0,
            }
          ])
        );
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`申告成功: roomId=${roomId}, uid=${uid}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`申告エラー: ${error.message}`, {
      roomId,
      uid,
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
  declare0001Handler,
};
