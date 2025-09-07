const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");

/**
 * 水平思考ゲームの成功/失敗リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function reportResult0003Handler(request) {
  const {roomId, result, answererUid} = request.data;

  if (!roomId || result === undefined || (result === true && !answererUid)) {
    throw new Error("結果報告に失敗しました。必要な情報が不足しています。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0003");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throw new Error("ゲームが見つかりません。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throw new Error("不正なリクエストです。ホストプレイヤーより一度ゲームを終了してください。");
      }

      const updatedPlayers = updatePlayerPoints(currentGameData.players, result, answererUid);
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
    logger.error("結果報告エラー", {
      error: error.message,
      roomId,
      result,
      answererUid,
    });
    throw error;
  }
}

/**
 * プレイヤーのポイントを更新する
 * @param {Array} players - プレイヤーデータの配列
 * @param {boolean} result - 正解かどうか
 * @param {string} answererUid - 回答者のUID
 * @return {Array} 更新されたプレイヤーデータ
 */
function updatePlayerPoints(players, result, answererUid) {
  if (!result) return {...players};
  const updatedPlayers = {...players};
  if (updatedPlayers[answererUid]) {
    updatedPlayers[answererUid] = {
      ...updatedPlayers[answererUid],
      point: (updatedPlayers[answererUid].point || 0) + 1,
    };
  }
  return updatedPlayers;
}

/**
 * 次の出題者を決定し、一巡したかどうかを返す
 * @param {Array} players - プレイヤーデータの配列
 * @param {string} currentQuestioner - 現在の出題者
 * @return {Object} 次の出題者と一巡したかどうか
 */
function determineNextQuestioner(players, currentQuestioner) {
  const playerUids = Object.keys(players);
  const currentIndex = playerUids.findIndex((uid) => uid === currentQuestioner);
  const nextIndex = (currentIndex + 1) % playerUids.length;
  const nextQuestioner = playerUids[nextIndex];
  const isOneRoundCompleted = players[nextQuestioner].isEverQuestioner;

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
    const playerUids = Object.keys(players);
    const randomPlayerIndex = Math.floor(Math.random() * playerUids.length);
    const firstQuestioner = playerUids[randomPlayerIndex];

    return {
      gameStatus: "waiting",
      questioner: firstQuestioner,
      question: questionData.question,
      answer: questionData.answer,
      usedQuestionIndex: usedQuestionIndex,
      players: Object.fromEntries(
          Object.entries(players).map(([uid, player]) => [
            uid,
            {
              ...player,
              isReady: false,
              isEverQuestioner: uid === firstQuestioner,
            },
          ]),
      ),
    };
  } else {
    return {
      players: Object.fromEntries(
          Object.entries(players).map(([uid, player]) => [
            uid,
            uid === nextQuestioner ? {...player, isEverQuestioner: true} : player,
          ]),
      ),
      questioner: nextQuestioner,
      question: questionData.question,
      answer: questionData.answer,
      usedQuestionIndex: usedQuestionIndex,
    };
  }
}

module.exports = {
  reportResult0003Handler,
};
