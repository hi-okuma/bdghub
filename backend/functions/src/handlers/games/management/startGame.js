const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * ゲーム開始リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function startGameHandler(request) {
  const {roomId, gameId} = request.data;

  if (!roomId || !gameId) {
    throwValidationError("ゲーム開始に失敗しました。");
  }

  try {
    let gameData;

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throwNotFoundError("部屋", roomId);
      }

      const roomData = roomDoc.data();

      if (roomData.status !== "accepting" && roomData.status !== "full") {
        handleInvalidRoomStatus(roomData.status);
      }

      const gameRef = db.collection("games").doc(gameId);
      const gameDoc = await transaction.get(gameRef);

      if (!gameDoc.exists) {
        throwNotFoundError("ゲーム", gameId);
      }

      gameData = gameDoc.data();

      if (!gameData.isPublished) {
        throwStructuredError("Unpublished", "このゲームは公開されていません。");
      }

      if (gameData.releaseDate) {
        const now = new Date();
        let releaseDate;

        if (gameData.releaseDate instanceof Timestamp) {
          releaseDate = gameData.releaseDate.toDate();
        } else if (gameData.releaseDate instanceof Date) {
          releaseDate = gameData.releaseDate;
        } else {
          throwStructuredError("Internal", "InvalidReleaseDateFormat");
        }

        if (releaseDate > now) {
          throwStructuredError("NotReleased", "このゲームは公開されていません。");
        }
      }

      const currentPlayerCount = Object.keys(roomData.players).length;

      if (currentPlayerCount < gameData.minPlayers) {
        throwStructuredError(
            "InsufficientPlayers",
            `このゲームには最低${gameData.minPlayers}人のプレイヤーが必要です。現在${currentPlayerCount}人です。`,
        );
      }
      if (currentPlayerCount > gameData.maxPlayers) {
        throwStructuredError(
            "TooManyPlayers",
            `このゲームは最大${gameData.maxPlayers}人までです。現在${currentPlayerCount}人です。`,
        );
      }

      let gameInitializer;
      try {
        gameInitializer = require(`../../games/${gameId}/init.js`);
      } catch (error) {
        throwStructuredError("InitializerNotFound", "ゲームを開始できませんでした。");
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
    if (error.code && error.details) {
      throw error;
    }

    logger.error("ゲーム開始エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      gameId,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * 無効な部屋ステータスに対するエラーを投げる
 * @param {string} status - 部屋のステータス
 */
function handleInvalidRoomStatus(status) {
  const statusErrorMap = {
    "inProgress": {
      code: "AlreadyInProgress",
      message: "この部屋ではすでにゲームが進行中です。",
    },
    "closed": {
      code: "RoomClosed",
      message: "この部屋はすでに閉じられています。",
    },
  };

  const errorInfo = statusErrorMap[status] || {
    code: "InvalidRoomStatus",
    message: "ゲームを開始できませんでした。",
  };

  throwStructuredError(errorInfo.code, errorInfo.message);
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
