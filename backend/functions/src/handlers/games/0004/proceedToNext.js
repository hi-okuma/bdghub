const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");
const {initializeGameData} = require("./init");

/**
 * 偏見プロフィールゲームの結果確認リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function proceedToNext0004Handler(req, res) {
  const {roomId, nickname, bestHintPlayer} = req.body;

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
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "result") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      const isCorrect = currentGameData.parentSelectedIndex === currentGameData.answerImageIndex;
      const isParent = nickname === currentGameData.currentParent;

      if (isCorrect && isParent && !bestHintPlayer) {
        throw new Error("BestHintPlayerRequired");
      }

      const updateData = {};
      let updatedPlayers = [...currentGameData.players];

      if (isCorrect && isParent && bestHintPlayer) {
        if (bestHintPlayer === currentGameData.currentParent) {
          throw new Error("InvalidBestHintPlayer");
        }

        if (!currentGameData.hints[bestHintPlayer]) {
          throw new Error("PlayerDidNotSubmitHint");
        }

        updatedPlayers = updatedPlayers.map((player) => {
          if (player.nickname === bestHintPlayer) {
            return {...player, point: (player.point || 0) + 1};
          }
          if (player.nickname === currentGameData.currentParent) {
            return {...player, point: (player.point || 0) + 1, isReady: true};
          }
          return player;
        });

        updateData.bestHintPlayer = bestHintPlayer;
      } else {
        updatedPlayers = updatedPlayers.map((player) => {
          if (player.nickname === nickname) {
            return {...player, isReady: true};
          }
          return player;
        });
      }

      updateData.players = updatedPlayers;

      const allReady = updatedPlayers.every((player) => player.isReady);

      if (allReady) {
        await prepareNextTurn(transaction, currentGameRef, currentGameData, updatedPlayers);
      } else {
        transaction.update(currentGameRef, updateData);
      }
    });

    logger.info("結果確認成功: roomId=${roomId}, nickname=${nickname}${bestHintPlayer ? `, bestHintPlayer=${bestHintPlayer}` : ''}");
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`結果確認エラー: ${error.message}`, {
      roomId,
      nickname,
      bestHintPlayer,
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
    } else if (errorMessage.includes("BestHintPlayerRequired")) {
      return sendError(
          res,
          "BestHintPlayerRequired",
          "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
          400,
      );
    } else if (errorMessage.includes("InvalidBestHintPlayer")) {
      return sendError(
          res,
          "InvalidBestHintPlayer",
          "親プレイヤーはベストヒントに選択できません。",
          400,
      );
    } else if (errorMessage.includes("PlayerDidNotSubmitHint")) {
      return sendError(
          res,
          "PlayerDidNotSubmitHint",
          "選択されたプレイヤーが見つかりません。他のプレイヤーを選択するか、一度ゲームを終了してください。",
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

/**
 * 次のターンに進む準備をする
 * @param {Transaction} transaction - Firestoreトランザクション
 * @param {DocumentReference} currentGameRef - currentGameのリファレンス
 * @param {Object} currentGameData - 現在のゲームデータ
 * @param {Array} updatedPlayers - 更新されたプレイヤーデータ
 */
async function prepareNextTurn(transaction, currentGameRef, currentGameData, updatedPlayers) {
  const currentParentIndex = updatedPlayers.findIndex(
      (player) => player.nickname === currentGameData.currentParent,
  );
  const nextParentIndex = (currentParentIndex + 1) % updatedPlayers.length;
  const isOneRoundCompleted = updatedPlayers[nextParentIndex].isEverParent;
  const playerNicknames = updatedPlayers.map((player) => player.nickname);

  if (isOneRoundCompleted) {
    const gameDataForNewRound = {
      ...currentGameData,
      players: updatedPlayers,
    };
    const newGameData = await initializeGameData(playerNicknames, gameDataForNewRound, true);

    transaction.update(currentGameRef, {
      gameStatus: "waiting",
      players: newGameData.players,
      currentParent: newGameData.currentParent,
      currentImages: newGameData.currentImages,
      answerImageIndex: newGameData.answerImageIndex,
      topics: newGameData.topics,
      hints: {},
      parentSelectedIndex: null,
      bestHintPlayer: null,
      usedImages: newGameData.usedImages,
      usedTopics: newGameData.usedTopics,
    });
  } else {
    const nextTurnData = await initializeGameData(playerNicknames, currentGameData);

    transaction.update(currentGameRef, {
      gameStatus: "childTurn",
      currentParent: nextTurnData.currentParent,
      currentImages: nextTurnData.currentImages,
      answerImageIndex: nextTurnData.answerImageIndex,
      topics: nextTurnData.topics,
      hints: {},
      parentSelectedIndex: null,
      bestHintPlayer: null,
      usedImages: nextTurnData.usedImages,
      usedTopics: nextTurnData.usedTopics,
      players: updatedPlayers.map((player) => ({
        ...player,
        isReady: false,
        isEverParent: player.isEverParent || player.nickname === nextTurnData.currentParent,
      })),
    });
  }
}

module.exports = {
  proceedToNext0004Handler,
};
