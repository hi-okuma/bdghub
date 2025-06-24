const {db} = require("../../../config/firebase");

/**
 * カタカナ禁止ゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
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
  const playerUids = Object.keys(players);
  const randomIndex = Math.floor(Math.random() * playerUids.length);
  const firstPresenter = playerUids[randomIndex];
  const firstTopic = shuffledTopics[0];
  const playersData = {};
  playerUids.forEach((uid) => {
    playersData[uid] = {
      isReady: false,
      isEverPresenter: uid === firstPresenter,
      point: 0,
    };
  });

  return {
    gameStatus: "waiting",
    players: playersData,
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
