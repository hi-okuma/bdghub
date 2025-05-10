const {db} = require("../../../config/firebase");

/**
 * カタカナ禁止ゲームのcurrentGameデータを生成する
 * @param {Array<string>} players - プレイヤーのニックネーム配列
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const topicsDoc = await db.collection("games").doc("0002")
      .collection("assets")
      .doc("topics")
      .get();

  if (!topicsDoc.exists) {
    throw new Error("お題リストが見つかりません");
  }

  const topicsList = topicsDoc.data().topics;
  const shuffledTopics = shuffleArray(topicsList);
  const randomIndex = Math.floor(Math.random() * players.length);
  const firstPresenter = players[randomIndex];
  const firstTopic = shuffledTopics[0];

  const playerData = players.map((nickname) => ({
    nickname: nickname,
    isReady: false,
    isEverPresenter: nickname === firstPresenter,
    point: 0,
  }));

  return {
    gameStatus: "waiting",
    players: playerData,
    currentPresenter: firstPresenter,
    currentTopic: firstTopic,
    usedTopic: [firstTopic],
  };
}

/**
 * 配列をシャッフルする
 * @param {Array<any>} array - シャッフルする配列
 * @return {Array<any>} シャッフルされた配列
 */
function shuffleArray(array) {
  const newArray = [...array];
  for (let i = newArray.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [newArray[i], newArray[j]] = [newArray[j], newArray[i]];
  }
  return newArray;
}

module.exports = {
  createCurrentGame,
};
