const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwNotFoundError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * カタカナ禁止ゲームの成功/失敗リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function reportResult0002Handler(request) {
  const {roomId, result, answererUid} = request.data;

  if (!roomId || result === undefined || (result === true && !answererUid)) {
    throwValidationError("結果報告に失敗しました。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0002");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError("ゲーム", "0002");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throwGameStatusError("playing", currentGameData.gameStatus);
      }

      const updatedPlayers = {...currentGameData.players};
      if (result === true) {
        if (updatedPlayers[answererUid]) {
          updatedPlayers[answererUid] = {...updatedPlayers[answererUid], point: (updatedPlayers[answererUid].point || 0) + 1};
        }
        if (updatedPlayers[currentGameData.currentPresenter]) {
          updatedPlayers[currentGameData.currentPresenter] = {...updatedPlayers[currentGameData.currentPresenter], point: (updatedPlayers[currentGameData.currentPresenter].point || 0) + 1};
        }
      }

      const playerUids = Object.keys(updatedPlayers);
      const currentIndex = playerUids.findIndex((uid) => uid === currentGameData.currentPresenter);

      // 次の出題者を探す（isEverPresenterがfalseの人を優先）
      let nextPresenter = null;
      for (let i = 1; i <= playerUids.length; i++) {
        const nextIndex = (currentIndex + i) % playerUids.length;
        const candidateUid = playerUids[nextIndex];
        if (!updatedPlayers[candidateUid].isEverPresenter) {
          nextPresenter = candidateUid;
          break;
        }
      }

      // 全プレイヤーがisEverPresenter=trueかチェック
      const isOneRoundCompleted = nextPresenter === null;

      let updateData = {};

      if (isOneRoundCompleted) {
        // 全プレイヤーが出題者になったらゲーム終了
        updateData = {
          gameStatus: "waiting",
          players: updatedPlayers,
        };
      } else {
        // 次の出題者に移行
        const topicsDoc = await transaction.get(
            db.collection("games").doc("0002")
                .collection("assets")
                .doc("topics"),
        );

        if (!topicsDoc.exists) {
          throwStructuredError("Internal", "お題リストが見つかりません");
        }
        const topicsList = topicsDoc.data().topics;

        const unusedTopics = topicsList.filter(
            (topic) => !currentGameData.usedTopic.includes(topic),
        );

        let nextTopic;
        if (unusedTopics.length > 0) {
          nextTopic = unusedTopics[Math.floor(Math.random() * unusedTopics.length)];
        } else {
          nextTopic = selectNewTopic(topicsList, currentGameData.currentTopic);
        }

        updateData = {
          players: Object.fromEntries(
              Object.entries(updatedPlayers).map(([uid, player]) => [
                uid,
                uid === nextPresenter ? {...player, isEverPresenter: true} : player,
              ]),
          ),
          currentPresenter: nextPresenter,
          currentTopic: nextTopic,
          usedTopic: [...currentGameData.usedTopic, nextTopic],
        };
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`結果報告成功: roomId=${roomId}, result=${result}`, {
      roomId,
      result,
      answererUid,
    });

    return {
      success: true,
      message: "結果を報告しました。",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("結果報告エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      result,
      answererUid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * 現在のお題と異なる新しいお題を選択する
 * @param {Array<string>} topics - お題のリスト
 * @param {string} currentTopic - 現在のお題
 * @return {string} 新しいお題
 */
function selectNewTopic(topics, currentTopic) {
  const availableTopics = topics.filter((topic) => topic !== currentTopic);

  if (availableTopics.length === 0) {
    return currentTopic;
  }

  return availableTopics[Math.floor(Math.random() * availableTopics.length)];
}

module.exports = {
  reportResult0002Handler,
};
