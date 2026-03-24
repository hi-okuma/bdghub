const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {getReadyTransitionStatus} = require("./statusTransitions");
const {
  throwValidationError,
  throwNotFoundError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

const CPU_UID = "cpu";

/**
 * ゲーム準備完了リクエストの共通ハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function setReadyHandler(request) {
  const {uid, roomId, gameId} = request.data;

  if (!uid || !roomId || !gameId) {
    throwValidationError("準備完了設定に失敗しました。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc(gameId);
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", gameId);
      }

      // CPUプレイヤーはroom.playersに存在しないため、
      // currentGame.playersで存在チェックを行う
      if (uid !== CPU_UID) {
        const roomDoc = await transaction.get(roomRef);

        if (!roomDoc.data().players[uid]) {
          throwNotFoundError("プレイヤー", uid);
        }
      }

      const currentGameData = currentGameDoc.data();

      // CPUがcurrentGame.playersに存在するか確認
      if (!currentGameData.players[uid]) {
        throwNotFoundError("プレイヤー", uid);
      }

      if (currentGameData.gameStatus !== "waiting") {
        throwGameStatusError("waiting", currentGameData.gameStatus);
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
              {
                ...player,
                isReady: false,
                ...(player.isBurst !== undefined && {isBurst: false}),
              },
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
    if (error.code && error.details) {
      throw error;
    }

    logger.error("準備完了設定エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      gameId,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  setReadyHandler,
};
