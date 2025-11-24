const {db} = require("../../../config/firebase");

/**
 * 1人で偏見プロフィールゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const gameData = await initializeGameData();

  return {
    currentQuestionNumber: gameData.currentQuestionNumber,
    currentImages: gameData.currentImages,
    answerImageIndex: gameData.answerImageIndex,
    topicsAndHints: gameData.topicsAndHints,
    selectedIndex: null,
    usedImages: gameData.usedImages,
    usedTopics: gameData.usedTopics,
    point: 0,
  };
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
  const allImages = assets.images || [];
  const allTopicsAndHints = assets.topicsAndHints || {};

  const allTopics = Object.keys(allTopicsAndHints);

  if (allImages.length < 5) {
    throw new Error("画像が不足しています");
  }

  if (allTopics.length < 3) {
    throw new Error("トピックが不足しています");
  }

  let usedImages = existingGameData?.usedImages || [];
  const unusedImages = allImages.filter((img) => !usedImages.includes(img));
  let currentImages;

  if (unusedImages.length >= 5) {
    const shuffled = shuffleArray(unusedImages);
    currentImages = shuffled.slice(0, 5);
    usedImages = [...usedImages, ...currentImages];
  } else {
    const shuffled = shuffleArray(allImages);
    currentImages = shuffled.slice(0, 5);
    usedImages = [...currentImages];
  }

  const answerImageIndex = Math.floor(Math.random() * 5);

  let usedTopics = existingGameData?.usedTopics || [];
  const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
  let selectedTopics;

  if (unusedTopics.length >= 3) {
    selectedTopics = shuffleArray(unusedTopics).slice(0, 3);
    usedTopics = [...usedTopics, ...selectedTopics];
  } else {
    selectedTopics = shuffleArray(allTopics).slice(0, 3);
    usedTopics = [...selectedTopics];
  }

  const topicsAndHints = {};
  selectedTopics.forEach((topic) => {
    const hints = allTopicsAndHints[topic];
    if (hints && hints.length > 0) {
      const randomHintIndex = Math.floor(Math.random() * hints.length);
      topicsAndHints[topic] = hints[randomHintIndex];
    }
  });

  return {
    currentQuestionNumber: 1,
    currentImages: currentImages,
    answerImageIndex: answerImageIndex,
    topicsAndHints: topicsAndHints,
    usedImages: usedImages,
    usedTopics: usedTopics,
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
