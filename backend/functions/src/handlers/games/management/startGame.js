const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * ゲーム開始リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function startGameHandler(req, res) {
  const {roomId, gameId} = req.body;

  if (!roomId || !gameId) {
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
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throw new Error("RoomNotFound");
      }

      const roomData = roomDoc.data();

      if (roomData.status !== "accepting" && roomData.status !== "full") {
        throw new Error(`InvalidRoomStatus:${roomData.status}`);
      }

      const gameRef = db.collection("games").doc(gameId);
      const gameDoc = await transaction.get(gameRef);

      if (!gameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const gameData = gameDoc.data();

      if (!gameData.isPublished) {
        throw new Error("Unpublished");
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
          throw new Error(`NotReleased`);
        }
      }

      if (roomData.players.length < gameData.minPlayers) {
        throw new Error(`InsufficientPlayers:${gameData.minPlayers}:${roomData.players.length}`);
      }
      if (roomData.players.length > gameData.maxPlayers) {
        throw new Error(`TooManyPlayers:${gameData.maxPlayers}:${roomData.players.length}`);
      }

      let gameInitializer;
      try {
        gameInitializer = require(`../../games/${gameId}/init.js`);
      } catch (error) {
        throw new Error(`InitializerNotFound:${gameId}`);
      }

      const currentGameData = await gameInitializer.createCurrentGame(roomData.players, gameData);

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

    logger.info(`ゲーム開始成功: roomId=${roomId}, gameId=${gameId}`);

    updatePlayCount(gameId).catch((error) => {
      logger.warn(`プレイ回数更新エラー: ${error.message}`, {
        roomId,
        gameId,
        error: error.stack,
      });
    });

    return sendSuccess(res, {
      gameId: gameId,
    }, "");
  } catch (error) {
    logger.error(`ゲーム開始エラー: ${error.message}`, {
      roomId,
      gameId,
      error: error.stack,
    });

    const errorMessage = error.message || "サーバーエラーが発生しました。";

    if (errorMessage.includes("RoomNotFound")) {
      return sendError(res, "NotFound", "指定された部屋が見つかりません。", 404, {roomId});
    } else if (errorMessage.includes("GameNotFound")) {
      return sendError(res, "GameNotFound", "指定されたゲームが見つかりません。", 404, {gameId});
    } else if (errorMessage.includes("InitializerNotFound")) {
      return sendError(res, "InitializerNotFound", "ゲームを開始できませんでした。", 500, {gameId});
    } else if (errorMessage.includes("Unpublished")) {
      return sendError(res, "Unpublished", "このゲームは公開されていません。", 403, {gameId});
    } else if (errorMessage.includes("NotReleased")) {
      return sendError(res, "NotReleased", "このゲームは公開されていません。", 403, {gameId});
    } else if (errorMessage.includes("InsufficientPlayers")) {
      const parts = errorMessage.split(":");
      const required = parts[1] || "?";
      const current = parts[2] || "?";
      return sendError(
          res,
          "InsufficientPlayers",
          `このゲームには最低${required}人のプレイヤーが必要です。現在${current}人です。`,
          200,
          {required, current},
      );
    } else if (errorMessage.includes("TooManyPlayers")) {
      const parts = errorMessage.split(":");
      const maximum = parts[1] || "?";
      const current = parts[2] || "?";
      return sendError(
          res,
          "TooManyPlayers",
          `このゲームは最大${maximum}人までです。現在${current}人です。`,
          200,
          {maximum, current},
      );
    } else if (errorMessage.includes("InvalidRoomStatus")) {
      const status = errorMessage.split(":")[1] || "unknown";
      const statusErrors = {
        "inProgress": {
          error: "AlreadyInProgress",
          message: "この部屋ではすでにゲームが進行中です。",
          status: 200,
        },
        "closed": {
          error: "RoomClosed",
          message: "この部屋はすでに閉じられています。",
          status: 200,
        },
        "unknown": {
          error: "InvalidRoomStatus",
          message: "ゲームを開始できませんでした。",
          status: 200,
        },
      };

      const errorData = statusErrors[status] || statusErrors.unknown;
      return sendError(res, errorData.error, errorData.message, errorData.status);
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
