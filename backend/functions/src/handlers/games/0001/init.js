const {db} = require("../../../config/firebase");
const {
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * NGワードゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);

  // NGワードリストを取得
  const ngWordsDoc = await db.collection("games").doc("0001")
      .collection("assets")
      .doc("ngWords")
      .get();

  if (!ngWordsDoc.exists) {
    throwNotFoundError("NGワードリスト", "ngWords");
  }

  const allWords = ngWordsDoc.data().words;
  const gameData = assignNgWordsSync(playerUids, allWords);

  return {
    gameStatus: "waiting",
    players: gameData.players,
    usedWords: gameData.usedWords,
    version: 0,
  };
}

/**
 * プレイヤーにNGワードを割り当てる（同期版）
 * @param {Array<string>} playerUids - プレイヤーのuidの配列
 * @param {Array<string>} allWords - 全NGワードのリスト
 * @param {Object} existingGameData - 既存のゲームデータ（継続時）
 * @return {Object} NGワード割り当て結果
 */
function assignNgWordsSync(playerUids, allWords, existingGameData = null) {
  if (allWords.length < playerUids.length) {
    throwStructuredError("InsufficientResources", "NGワードが不足しています");
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
  assignNgWordsSync,
};
