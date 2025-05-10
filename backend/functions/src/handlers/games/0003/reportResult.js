const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {sendSuccess, sendError} = require("../../../utils/responseHandler");

/**
 * 水平思考ゲームの成功/失敗リクエストを処理するハンドラー
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 */
async function reportResult0003Handler(req, res) {
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
      const currentGameRef = roomRef.collection("currentGame").doc("0003");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("GameNotFound");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throw new Error(`InvalidGameStatus:${currentGameData.gameStatus}`);
      }

      const updatedPlayers = updatePlayerPoints(currentGameData.players, result, answerer);
      const {nextQuestioner, isOneRoundCompleted} = determineNextQuestioner(updatedPlayers, currentGameData.questioner);
      const questionsList = await getQuestionsList(transaction);
      const nextQuestionData = selectNextQuestion(questionsList, currentGameData);

      const updateData = createUpdateData(
          updatedPlayers,
          nextQuestioner,
          nextQuestionData,
          isOneRoundCompleted,
          currentGameData,
      );

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

    return handleError(res, error);
  }
}

/**
 * プレイヤーのポイントを更新する
 * @param {Array} players - プレイヤーデータの配列
 * @param {boolean} result - 正解かどうか
 * @param {string} answerer - 回答者のニックネーム
 * @return {Array} 更新されたプレイヤーデータ
 */
function updatePlayerPoints(players, result, answerer) {
  if (!result) return [...players];

  return players.map((player) => {
    if (player.nickname === answerer) {
      return {...player, point: (player.point || 0) + 1};
    }
    return player;
  });
}

/**
 * 次の出題者を決定し、一巡したかどうかを返す
 * @param {Array} players - プレイヤーデータの配列
 * @param {string} currentQuestioner - 現在の出題者
 * @return {Object} 次の出題者と一巡したかどうか
 */
function determineNextQuestioner(players, currentQuestioner) {
  const currentIndex = players.findIndex((player) => player.nickname === currentQuestioner);
  const nextIndex = (currentIndex + 1) % players.length;
  const nextQuestioner = players[nextIndex].nickname;
  const isOneRoundCompleted = players[nextIndex].isEverQuestioner;

  return {nextQuestioner, isOneRoundCompleted};
}

/**
 * 問題リストを取得する
 * @param {Transaction} transaction - Firestoreトランザクション
 * @return {Promise<Array>} 問題リスト
 */
async function getQuestionsList(transaction) {
  const questionsDoc = await transaction.get(
      db.collection("games").doc("0003")
          .collection("assets")
          .doc("puzzles"),
  );

  if (!questionsDoc.exists) {
    throw new Error("問題リストが見つかりません");
  }

  return questionsDoc.data().questions;
}

/**
 * 次の問題を選択する
 * @param {Array} questionsList - 問題リスト
 * @param {Object} currentGameData - 現在のゲームデータ
 * @return {Object} 次の問題データ
 */
function selectNextQuestion(questionsList, currentGameData) {
  const unusedIndices = [];
  for (let i = 0; i < questionsList.length; i++) {
    if (!currentGameData.usedQuestionIndex.includes(i.toString())) {
      unusedIndices.push(i);
    }
  }

  let questionIndex;

  if (unusedIndices.length > 0) {
    questionIndex = unusedIndices[Math.floor(Math.random() * unusedIndices.length)];
  } else {
    const availableIndices = [];
    for (let i = 0; i < questionsList.length; i++) {
      if (questionsList[i].question !== currentGameData.question) {
        availableIndices.push(i);
      }
    }
    questionIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)];
  }

  const question = questionsList[questionIndex].question;
  const answer = questionsList[questionIndex].answer;

  return {questionIndex, question, answer};
}

/**
 * 更新データを作成する
 * @param {Array} players - 更新されたプレイヤーデータ
 * @param {string} nextQuestioner - 次の出題者
 * @param {Object} questionData - 次の問題データ
 * @param {boolean} isOneRoundCompleted - 一巡したかどうか
 * @param {Object} currentGameData - 現在のゲームデータ
 * @return {Object} 更新データ
 */
function createUpdateData(players, nextQuestioner, questionData, isOneRoundCompleted, currentGameData) {
  const usedQuestionIndex = [...currentGameData.usedQuestionIndex, questionData.questionIndex.toString()];

  if (isOneRoundCompleted) {
    const randomPlayerIndex = Math.floor(Math.random() * players.length);
    const firstQuestioner = players[randomPlayerIndex].nickname;

    return {
      gameStatus: "waiting",
      questioner: firstQuestioner,
      question: questionData.question,
      answer: questionData.answer,
      usedQuestionIndex: usedQuestionIndex,
      players: players.map((player) => ({
        ...player,
        isReady: false,
        isEverQuestioner: player.nickname === firstQuestioner,
      })),
    };
  } else {
    return {
      players: players.map((player) => {
        if (player.nickname === nextQuestioner) {
          return {...player, isEverQuestioner: true};
        }
        return player;
      }),
      questioner: nextQuestioner,
      question: questionData.question,
      answer: questionData.answer,
      usedQuestionIndex: usedQuestionIndex,
    };
  }
}

/**
 * エラーハンドリング
 * @param {object} res - レスポンスオブジェクト
 * @param {Error} error - エラーオブジェクト
 * @return {object} エラーレスポンス
 */
function handleError(res, error) {
  const errorMessage = error.message || "サーバーエラーが発生しました。";

  if (errorMessage.includes("GameNotFound")) {
    return sendError(res, "GameNotFound", "ゲームが見つかりません。ホストプレイヤーより一度ゲームを終了してください。", 404);
  } else if (errorMessage.includes("InvalidGameStatus")) {
    const status = errorMessage.split(":")[1] || "unknown";
    return sendError(
        res,
        "InvalidGameStatus",
        "不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。",
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

module.exports = {
  reportResult0003Handler,
};
