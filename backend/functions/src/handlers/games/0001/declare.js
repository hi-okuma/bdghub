const {logger} = require("firebase-functions");
const {db, FieldValue} = require("../../../config/firebase");
const {assignNgWordsSync} = require("./init");
const {
  throwValidationError,
  throwGameStatusError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * NGワードゲームの申告リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function declare0001Handler(request) {
  const {roomId, uid} = request.data;

  if (!roomId || !uid) {
    throwValidationError("申告に失敗しました。");
  }

  try {
    // トランザクション外でNGワードリストを事前取得
    const ngWordsDoc = await db.collection("games").doc("0001")
        .collection("assets")
        .doc("ngWords")
        .get();

    if (!ngWordsDoc.exists) {
      throwNotFoundError("NGワードリスト", "ngWords");
    }

    const allWords = ngWordsDoc.data().words;

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0001");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", "0001");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throwGameStatusError("playing", currentGameData.gameStatus);
      }

      if (!currentGameData.players[uid]) {
        throwNotFoundError("プレイヤー", uid);
      }

      const updatedPlayers = {...currentGameData.players};
      updatedPlayers[uid] = {...updatedPlayers[uid], isAlive: false};
      const alivePlayersCount = Object.values(updatedPlayers).filter((player) => player.isAlive).length;

      const updateData = {
        players: updatedPlayers,
        version: FieldValue.increment(1),
      };

      if (alivePlayersCount === 1) {
        const winnerEntry = Object.entries(updatedPlayers).find(([uid, player]) => player.isAlive);

        if (!winnerEntry) {
          throwStructuredError("Internal", "勝者が見つかりません");
        }

        const winnerUid = winnerEntry[0];
        const playersWithUpdatedPoints = Object.fromEntries(
            Object.entries(updatedPlayers).map(([uid, player]) => [
              uid,
              uid === winnerUid ? {...player, point: (player.point || 0) + 1} : player,
            ]),
        );

        updateData.gameStatus = "waiting";

        const playerUids = Object.keys(playersWithUpdatedPoints);
        // allWordsを渡して内部でのFirestore読み取りを回避
        const newGameData = assignNgWordsSync(playerUids, allWords, {
          usedWords: currentGameData.usedWords || [],
          players: playersWithUpdatedPoints,
        });

        updateData.players = newGameData.players;
        updateData.usedWords = newGameData.usedWords;
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`申告成功: roomId=${roomId}, uid=${uid}`, {
      roomId,
      uid,
    });

    return {
      success: true,
      message: "申告しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("申告エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  declare0001Handler,
};
