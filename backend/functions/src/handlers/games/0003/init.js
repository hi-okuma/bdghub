const {db} = require("../../../config/firebase");

/**
 * 水平思考ゲームのcurrentGameデータを生成する
 * @param {Array<string>} players - プレイヤーのニックネーム配列
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  // puzzlesをドキュメントIDとして使用
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
  const randomPlayerIndex = Math.floor(Math.random() * players.length);
  const firstQuestioner = players[randomPlayerIndex];

  const playerData = players.map((nickname) => ({
    nickname: nickname,
    isReady: false,
    isEverQuestioner: nickname === firstQuestioner,
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
