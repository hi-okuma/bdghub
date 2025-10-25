const {db} = require("../../../config/firebase");

/**
 * NGワードゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);
  const gameData = await assignNgWords(playerUids);

  return {
    gameStatus: "waiting",
    players: gameData.players,
    usedWords: gameData.usedWords,
  };
}

/**
 * プレイヤーにNGワードを割り当てる
 * @param {Array<string>} playerUids - プレイヤーのuidの配列
 * @param {Object} existingGameData - 既存のゲームデータ（継続時）
 * @return {Promise<Object>} NGワード割り当て結果
 */
async function assignNgWords(playerUids, existingGameData = null) {
  const ngWordsDoc = await db.collection("games").doc("0001")
      .collection("assets")
      .doc("ngWords")
      .get();

  if (!ngWordsDoc.exists) {
    throw new Error("NGワードリストが見つかりません");
  }

  const allWords = ngWordsDoc.data().words;

  if (allWords.length < playerUids.length) {
    throw new Error("NGワードが不足しています");
  }

  let usedWords = existingGameData?.usedWords || [];
  const unusedWords = allWords.filter((word) => !usedWords.includes(word));
  let selectedWords;

  if (unusedWords.length >= playerUids.length) {
    const shuffled = shuffleArray(unusedWords);
    selectedWords = shuffled.slice(0, playerUids.length);
    usedWords = [...usedWords, ...selectedWords];
  } else {
    const shuffled = shuffleArray(allWords);
    selectedWords = shuffled.slice(0, playerUids.length);
    usedWords = [...selectedWords];
  }

  const playersData = {};
  playerUids.forEach((uid, index) => {
    playersData[uid] = {
      isReady: false,
      ngWord: [selectedWords[index]],
      isAlive: true,
      point: existingGameData?.players?.[uid]?.point || 0,
    };
  });

  return {
    players: playersData,
    usedWords: usedWords,
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
  assignNgWords,
};
