const {db} = require("../../../config/firebase");

/**
 * 水平思考ゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const questionsDoc = await db.collection("games").doc("0003")
      .collection("assets")
      .doc("puzzles")
      .get();

  if (!questionsDoc.exists) {
    throw new Error("問題リストが見つかりません");
  }

  const questionsList = questionsDoc.data().questions;
  const randomIndex = Math.floor(Math.random() * questionsList.length);
  const firstQuestion = questionsList[randomIndex].question;
  const firstAnswer = questionsList[randomIndex].answer;
  const playerUids = Object.keys(players);
  const randomPlayerIndex = Math.floor(Math.random() * playerUids.length);
  const firstQuestioner = playerUids[randomPlayerIndex];

  const playerData = playerUids.map((uid) => ({
    uid: uid,
    isReady: false,
    isEverQuestioner: uid === firstQuestioner,
    point: 0,
  }));

  return {
    gameStatus: "waiting",
    players: playerData,
    questioner: firstQuestioner,
    question: firstQuestion,
    answer: firstAnswer,
    usedQuestionIndex: [randomIndex.toString()],
  };
}

module.exports = {
  createCurrentGame,
};
