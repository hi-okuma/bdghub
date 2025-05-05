const {db} = require("../../../config/firebase");

/**
 * NGワードゲームのcurrentGameデータを生成する
 * @param {Array<string>} players - プレイヤーのニックネーム配列
 * @param {Object} gameData - ゲーム情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players, gameData) {
  const ngWordsDoc = await db.collection("games").doc("0001")
      .collection("assets")
      .doc("ngWords")
      .get();

  if (!ngWordsDoc.exists) {
    throw new Error("NGワードリストが見つかりません");
  }

  const ngWordsList = ngWordsDoc.data().words;
  const shuffledWords = shuffleArray(ngWordsList);
  const playerData = players.map((nickname, index) => ({
    nickname: nickname,
    isReady: false,
    ngWord: [shuffledWords[index % shuffledWords.length]],
    isAlive: true,
    point: 0,
  }));

  return {
    gameStatus: "waiting",
    players: playerData,
  };
}

/**
 * NGワードをシャッフルする
 * @param {Array<string>} array - 文字列が格納された配列
 * @return {Array<string>} ランダムに並び替えられた配列
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
