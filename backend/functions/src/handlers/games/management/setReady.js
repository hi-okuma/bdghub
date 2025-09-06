const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {getReadyTransitionStatus} = require("./statusTransitions");

/**
 * ゲーム準備完了リクエストの共通ハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function setReadyHandler(request) {
  const {uid, roomId, gameId} = request.data;

  if (!uid || !roomId || !gameId) {
    throw new Error("準備完了設定に失敗しました。必要な情報が不足しています。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc(gameId);
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.data().players[uid]) {
        throw new Error("プレイヤーが見つかりません。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "waiting") {
        throw new Error("ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const updatedPlayers = {...currentGameData.players};
      if (updatedPlayers[uid]) {
        updatedPlayers[uid] = {...updatedPlayers[uid], isReady: true};
      }

      const allReady = Object.values(updatedPlayers).every((player) => player.isReady);

      const updateData = {
        players: updatedPlayers,
      };

      if (allReady) {
        updateData.gameStatus = getReadyTransitionStatus(gameId);
        updateData.players = Object.fromEntries(
            Object.entries(updatedPlayers).map(([uid, player]) => [
              uid,
              {...player, isReady: false},
            ]),
        );
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`準備完了設定成功: roomId=${roomId}, uid=${uid}, gameId=${gameId}`, {
      roomId,
      uid,
      gameId,
    });

    return {
      success: true,
      message: "準備完了を設定しました。",
    };
  } catch (error) {
    logger.error("準備完了設定エラー", {
      error: error.message,
      roomId,
      uid,
      gameId,
    });
    throw error;
  }
}

module.exports = {
  setReadyHandler,
};
