const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");

/**
 * NGワードゲームの申告リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function declare0001Handler(request) {
  const {roomId, uid} = request.data;

  if (!roomId || !uid) {
    throw new Error("申告に失敗しました。必要な情報が不足しています。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0001");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが見つかりません。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throw new Error("ゲームが進行中ではありません。");
      }

      const updatedPlayers = {...currentGameData.players};
      updatedPlayers[uid] = {...updatedPlayers[uid], isAlive: false};
      const alivePlayersCount = Object.values(updatedPlayers).filter((player) => player.isAlive).length;

      const updateData = {
        players: updatedPlayers,
      };

      if (alivePlayersCount === 1) {
        const winnerEntry = Object.entries(updatedPlayers).find(([uid, player]) => player.isAlive);

        if (!winnerEntry) {
          throw new Error("勝者が見つかりません");
        }

        const winnerUid = winnerEntry[0];
        const playersWithUpdatedPoints = Object.fromEntries(
            Object.entries(updatedPlayers).map(([uid, player]) => [
              uid,
              uid === winnerUid ? {...player, point: (player.point || 0) + 1} : {...player, point: player.point || 0},
            ]),
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

        const finalPlayers = Object.fromEntries(
            Object.keys(playersWithUpdatedPoints).map((uid, index) => [
              uid,
              {
                isReady: false,
                ngWord: [shuffledWords[index % shuffledWords.length]],
                isAlive: true,
                point: playersWithUpdatedPoints[uid].point || 0,
              },
            ]),
        );

        updateData.players = finalPlayers;
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
    logger.error("申告エラー", {
      error: error.message,
      roomId,
      uid,
    });
    throw error;
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
