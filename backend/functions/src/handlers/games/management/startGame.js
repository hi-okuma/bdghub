const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

/**
 * ゲーム開始リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function startGameHandler(request) {
  const {roomId, gameId} = request.data;

  if (!roomId || !gameId) {
    throw new Error("ゲーム開始に失敗しました。必要な情報が不足しています。");
  }

  try {
    let gameData;

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throw new Error("指定された部屋が見つかりません。");
      }

      const roomData = roomDoc.data();

      if (roomData.status !== "accepting" && roomData.status !== "full") {
        handleInvalidRoomStatus(roomData.status);
      }

      const gameRef = db.collection("games").doc(gameId);
      const gameDoc = await transaction.get(gameRef);

      if (!gameDoc.exists) {
        throw new Error("指定されたゲームが見つかりません。");
      }

      gameData = gameDoc.data();

      if (!gameData.isPublished) {
        throw new Error("このゲームは公開されていません。");
      }

      if (gameData.releaseDate) {
        const now = new Date();
        let releaseDate;

        if (gameData.releaseDate instanceof Timestamp) {
          releaseDate = gameData.releaseDate.toDate();
        } else if (gameData.releaseDate instanceof Date) {
          releaseDate = gameData.releaseDate;
        } else {
          throw new Error("InvalidReleaseDateFormat");
        }

        if (releaseDate > now) {
          throw new Error("このゲームは公開されていません。");
        }
      }

      const currentPlayerCount = Object.keys(roomData.players).length;

      if (currentPlayerCount < gameData.minPlayers) {
        throw new Error(`このゲームには最低${gameData.minPlayers}人のプレイヤーが必要です。現在${currentPlayerCount}人です。`);
      }
      if (currentPlayerCount > gameData.maxPlayers) {
        throw new Error(`このゲームは最大${gameData.maxPlayers}人までです。現在${currentPlayerCount}人です。`);
      }

      let gameInitializer;
      try {
        gameInitializer = require(`../../games/${gameId}/init.js`);
      } catch (error) {
        throw new Error("ゲームを開始できませんでした。");
      }

      const currentGameData = await gameInitializer.createCurrentGame(roomData.players);

      const gameInfo = {
        title: gameData.title,
        startedAt: FieldValue.serverTimestamp(),
        ...currentGameData,
      };

      transaction.update(roomRef, {
        status: "inProgress",
        updatedAt: FieldValue.serverTimestamp(),
      });

      const currentGameRef = roomRef.collection("currentGame").doc(gameId);
      transaction.set(currentGameRef, gameInfo);
    });

    logger.info(`ゲーム開始成功: roomId=${roomId}, gameId=${gameId}`, {
      roomId,
      gameId,
    });

    // プレイ回数更新（非同期・分離処理）
    updatePlayCount(gameId).catch((error) => {
      logger.warn(`プレイ回数更新エラー: ${error.message}`, {
        roomId,
        gameId,
        error: error.stack,
      });
    });

    return {
      gameId: gameId,
      gameTitle: gameData.title,
    };
  } catch (error) {
    logger.error("ゲーム開始エラー", {
      error: error.message,
      roomId,
      gameId,
    });
    throw error;
  }
}

/**
 * 無効な部屋ステータスに対するエラーを投げる
 * @param {string} status - 部屋のステータス
 */
function handleInvalidRoomStatus(status) {
  const statusErrors = {
    "inProgress": "この部屋ではすでにゲームが進行中です。",
    "closed": "この部屋はすでに閉じられています。",
    "unknown": "ゲームを開始できませんでした。",
  };

  const errorMessage = statusErrors[status] || statusErrors.unknown;
  throw new Error(errorMessage);
}

/**
 * ゲームのプレイ回数をインクリメントする（非同期・分離処理）
 * @param {string} gameId - ゲームID
 * @return {Promise} 更新処理のPromise
 */
async function updatePlayCount(gameId) {
  const gameRef = db.collection("games").doc(gameId);
  return gameRef.update({
    playCnt: FieldValue.increment(1),
  });
}

module.exports = {
  startGameHandler,
};
