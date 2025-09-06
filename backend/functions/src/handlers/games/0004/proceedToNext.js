const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {initializeGameData} = require("./init");

/**
 * 偏見プロフィールゲームの結果確認リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function proceedToNext0004Handler(request) {
  const {roomId, uid, bestHintPlayerUid} = request.data;

  if (!roomId || !uid) {
    throw new Error("次に進む処理に失敗しました。必要な情報が不足しています。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0004");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが見つかりません。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "result") {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const isCorrect = currentGameData.parentSelectedIndex === currentGameData.answerImageIndex;
      const isParent = uid === currentGameData.currentParent;

      if (isParent && !bestHintPlayerUid) {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const updateData = {};
      let updatedPlayers = {...currentGameData.players};

      if (isParent && bestHintPlayerUid) {
        if (bestHintPlayerUid === currentGameData.currentParent) {
          throw new Error("親プレイヤーはベストヒントに選択できません。");
        }

        if (!currentGameData.hints[bestHintPlayerUid]) {
          throw new Error("選択されたプレイヤーが見つかりません。他のプレイヤーを選択するか、一度ゲームを終了してください。");
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
    logger.error("結果確認エラー", {
      error: error.message,
      roomId,
      uid,
      bestHintPlayerUid,
    });
    throw error;
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
