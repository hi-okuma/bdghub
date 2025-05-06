const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * カタカナ禁止ゲームの成功/失敗リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function reportResult0002Handler(req, res) {
  const {roomId, result, answerer} = req.body;

  if (!roomId || result === undefined || (result === true && !answerer)) {
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
      const currentGameRef = roomRef.collection("currentGame").doc("0002");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      let updatedPlayers = [...currentGameData.players];
      if (result === true) {
        updatedPlayers = updatedPlayers.map((player) => {
          if (player.nickname === answerer || player.nickname === currentGameData.currentPresenter) {
            return {...player, point: (player.point || 0) + 1};
          }
          return player;
        });
      }

      const currentIndex = updatedPlayers.findIndex(
          (player) => player.nickname === currentGameData.currentPresenter,
      );
      const nextIndex = (currentIndex + 1) % updatedPlayers.length;
      const nextPresenter = updatedPlayers[nextIndex].nickname;
      const isOneRoundCompleted = updatedPlayers[nextIndex].isEverPresenter;

      const topicsDoc = await transaction.get(
          db.collection("games").doc("0002")
              .collection("assets")
              .doc("topics"),
      );

      if (!topicsDoc.exists) {
        throw new Error("お題リストが見つかりません");
      }
      const topicsList = topicsDoc.data().topics;
      let updateData = {};

      if (isOneRoundCompleted) {
        const unusedTopics = topicsList.filter(
            (topic) => !currentGameData.usedTopic.includes(topic),
        );

        let newTopic;
        if (unusedTopics.length > 0) {
          newTopic = unusedTopics[Math.floor(Math.random() * unusedTopics.length)];
        } else {
          newTopic = selectNewTopic(topicsList, currentGameData.currentTopic);
        }

        const firstPresenterIndex = (currentIndfex + 1) % updatedPlayers.length;
        const firstPresenter = updatedPlayers[firstPresenterIndex].nickname;

        updateData = {
          gameStatus: "waiting",
          currentTopic: newTopic,
          usedTopic: [...currentGameData.usedTopic, newTopic],
          currentPresenter: firstPresenter,
          players: updatedPlayers.map((player) => ({
            ...player,
            isReady: false,
            isEverPresenter: player.nickname === firstPresenter,
          })),
        };
      } else {
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
          players: updatedPlayers.map((player) => {
            if (player.nickname === nextPresenter) {
              return {...player, isEverPresenter: true};
            }
            return player;
          }),
          currentPresenter: nextPresenter,
          currentTopic: nextTopic,
          usedTopic: [...currentGameData.usedTopic, nextTopic],
        };
      }

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`結果報告成功: roomId=${roomId}, result=${result}`);
    return sendSuccess(res, {}, "");
  } catch (error) {
    logger.error(`結果報告エラー: ${error.message}`, {
      roomId,
      result,
      answerer,
      error: error.stack,
    });

    const errorMessage = error.message || "サーバーエラーが発生しました。";

    if (errorMessage.includes("GameNotFound")) {
      return sendError(res, "GameNotFound", "ゲームが見つかりません。", 404);
    } else if (errorMessage.includes("InvalidGameStatus")) {
      const status = errorMessage.split(":")[1] || "unknown";
      return sendError(
          res,
          "InvalidGameStatus",
          "ゲームが進行中ではありません。",
          400,
          {status},
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
