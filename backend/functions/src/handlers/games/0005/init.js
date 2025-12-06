const {db} = require("../../../config/firebase");

/**
 * 1人で偏見プロフィールゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const {logger} = require("firebase-functions");

  try {
    logger.info("0005 createCurrentGame開始", {players});
    const gameData = await initializeGameData();
    logger.info("0005 initializeGameData完了", {gameData});

    return {
      currentQuestionNumber: gameData.currentQuestionNumber,
      currentImages: gameData.currentImages,
      answerImageIndex: gameData.answerImageIndex,
      topicsAndHints: gameData.topicsAndHints,
      selectedIndex: null,
      usedCharacters: gameData.usedCharacters,
      point: 0,
    };
  } catch (error) {
    logger.error("0005 createCurrentGameエラー", {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

/**
 * ゲームデータを初期化する
 * @param {Object} existingGameData - 既存のゲームデータ（次ゲーム時）
 * @return {Promise<Object>} 初期化されたゲームデータ
 */
async function initializeGameData(existingGameData = null) {
  const assetsDoc = await db.collection("games").doc("0005")
      .collection("assets")
      .doc("data")
      .get();

  if (!assetsDoc.exists) {
    throw new Error("アセットが見つかりません");
  }

  const assets = assetsDoc.data();
  const allCharacters = assets.characters || [];

  if (allCharacters.length < 5) {
    throw new Error("キャラクターが不足しています（最低5人必要）");
  }

  // 使用済みキャラクターを管理
  let usedCharacters = existingGameData?.usedCharacters || [];
  const unusedCharacters = allCharacters.filter(
      (char) => !usedCharacters.includes(char.imageUrl),
  );

  // 正解のキャラクターを選択
  let answerCharacter;
  if (unusedCharacters.length > 0) {
    answerCharacter = unusedCharacters[Math.floor(Math.random() * unusedCharacters.length)];
  } else {
    // 全キャラクター使用済みの場合はリセットして選び直し
    answerCharacter = allCharacters[Math.floor(Math.random() * allCharacters.length)];
    usedCharacters = [];
  }

  // 正解キャラクターのprofilesから3つのトピックをランダムに選択
  const profiles = answerCharacter.profiles || {};
  const allTopics = Object.keys(profiles);

  if (allTopics.length < 3) {
    throw new Error(`キャラクター ${answerCharacter.imageUrl} のトピックが不足しています（最低3つ必要）`);
  }

  const selectedTopics = shuffleArray(allTopics).slice(0, 3);

  // 各トピックから1つのヒントをランダムに選択
  const topicsAndHints = {};
  selectedTopics.forEach((topic) => {
    const hints = profiles[topic];
    if (hints && hints.length > 0) {
      const randomHintIndex = Math.floor(Math.random() * hints.length);
      topicsAndHints[topic] = hints[randomHintIndex];
    }
  });

  // 5枚の画像を用意（正解1枚 + 他4枚）
  const otherCharacters = allCharacters.filter((char) => char.imageUrl !== answerCharacter.imageUrl);
  if (otherCharacters.length < 4) {
    throw new Error("選択肢用のキャラクターが不足しています（正解以外に最低4人必要）");
  }

  const shuffledOthers = shuffleArray(otherCharacters);
  const selectedOthers = shuffledOthers.slice(0, 4);

  // 5枚の画像をシャッフル
  const allImages = [answerCharacter.imageUrl, ...selectedOthers.map((char) => char.imageUrl)];
  const shuffledImages = shuffleArray(allImages);

  // 正解画像のインデックスを取得
  const answerImageIndex = shuffledImages.indexOf(answerCharacter.imageUrl);

  // 使用済みキャラクターに追加
  usedCharacters = [...usedCharacters, answerCharacter.imageUrl];

  return {
    currentQuestionNumber: 1,
    currentImages: shuffledImages,
    answerImageIndex: answerImageIndex,
    topicsAndHints: topicsAndHints,
    usedCharacters: usedCharacters,
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
  initializeGameData,
};
