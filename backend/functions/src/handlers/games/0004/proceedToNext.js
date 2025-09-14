const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {initializeGameData} = require("./init");
const {
  throwValidationError,
  throwNotFoundError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 偏見プロフィールゲームの結果確認リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function proceedToNext0004Handler(request) {
  const {roomId, uid, bestHintPlayerUid} = request.data;

  if (!roomId || !uid) {
    throwValidationError("次に進む処理に失敗しました。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", "0004");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "result") {
        throwGameStatusError("result", currentGameData.gameStatus);
      }

      const isCorrect = currentGameData.parentSelectedIndex === currentGameData.answerImageIndex;
      const isParent = uid === currentGameData.currentParent;

      if (isParent && !bestHintPlayerUid) {
        throwStructuredError(
            "BestHintPlayerRequired",
            "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
        );
      }

      const updateData = {};
      let updatedPlayers = {...currentGameData.players};

      if (isParent && bestHintPlayerUid) {
        if (bestHintPlayerUid === currentGameData.currentParent) {
          throwStructuredError("InvalidBestHintPlayer", "親プレイヤーはベストヒントに選択できません。");
        }

        if (!currentGameData.hints[bestHintPlayerUid]) {
          throwStructuredError(
              "PlayerDidNotSubmitHint",
              "選択されたプレイヤーが見つかりません。他のプレイヤーを選択するか、一度ゲームを終了してください。",
          );
        }

        updatedPlayers = Object.fromEntries(
            Object.entries(updatedPlayers).map(([playerUid, player]) => {
              if (playerUid === bestHintPlayerUid) {
                return [playerUid, {...player, point: (player.point || 0) + 1}];
              }
              if (playerUid === currentGameData.currentParent) {
                const parentPoint = isCorrect ? (player.point || 0) + 1 : (player.point || 0);
                return [playerUid, {...player, point: parentPoint, isReady: true}];
              }
              return [playerUid, player];
            }),
        );

        updateData.bestHintPlayer = bestHintPlayerUid;
      } else {
        updatedPlayers = Object.fromEntries(
            Object.entries(updatedPlayers).map(([playerUid, player]) => {
              if (playerUid === uid) {
                return [playerUid, {...player, isReady: true}];
              }
              return [playerUid, player];
            }),
        );
      }

      updateData.players = updatedPlayers;

      const allReady = Object.values(updatedPlayers).every((player) => player.isReady);

      if (allReady) {
        await prepareNextTurn(transaction, currentGameRef, currentGameData, updatedPlayers);
      } else {
        transaction.update(currentGameRef, updateData);
      }
    });

    logger.info(`結果確認成功: roomId=${roomId}, uid=${uid}${bestHintPlayerUid ? ", bestHintPlayerUid=" + bestHintPlayerUid : ""}`, {
      roomId,
      uid,
      bestHintPlayerUid,
    });

    return {
      success: true,
      message: "結果を確認しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("結果確認エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      bestHintPlayerUid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
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
  const playerUids = Object.keys(updatedPlayers);
  const currentParentIndex = playerUids.findIndex(
      (uid) => uid === currentGameData.currentParent,
  );
  const nextParentIndex = (currentParentIndex + 1) % playerUids.length;
  const isOneRoundCompleted = updatedPlayers[playerUids[nextParentIndex]].isEverParent;

  if (isOneRoundCompleted) {
    const gameDataForNewRound = {
      ...currentGameData,
      players: updatedPlayers,
    };
    const newGameData = await initializeGameData(playerUids, gameDataForNewRound, true);

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
    const nextTurnData = await initializeGameData(playerUids, currentGameData);

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
      players: Object.fromEntries(
          Object.entries(updatedPlayers).map(([uid, player]) => [
            uid,
            {
              ...player,
              isReady: false,
              isEverParent: player.isEverParent || uid === nextTurnData.currentParent,
            },
          ]),
      ),
    });
  }
}

module.exports = {
  proceedToNext0004Handler,
};
