const {db} = require("../../../config/firebase");

/**
 * 偏見プロフィールゲームのcurrentGameデータを生成する
 * @param {Array<string>} players - プレイヤーのニックネーム配列
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const gameData = await initializeGameData(players);

  return {
    gameStatus: "waiting",
    players: gameData.players,
    currentParent: gameData.currentParent,
    currentImages: gameData.currentImages,
    answerImageIndex: gameData.answerImageIndex,
    topics: gameData.topics,
    hints: {},
    parentSelectedIndex: null,
    bestHintPlayer: null,
    usedImages: gameData.usedImages,
    usedTopics: gameData.usedTopics,
  };
}

/**
 * ゲームデータを初期化する共通関数
 * @param {Array<string>} playerNicknames - プレイヤーのニックネーム配列
 * @param {Object} existingGameData - 既存のゲームデータ（継続時）
 * @param {boolean} isNewRound - 新しいラウンドかどうか（一巡後）
 * @return {Promise<Object>} 初期化されたゲームデータ
 */
async function initializeGameData(playerNicknames, existingGameData = null, isNewRound = false) {
  const assetsDoc = await db.collection("games").doc("0004")
      .collection("assets")
      .doc("data")
      .get();

  if (!assetsDoc.exists) {
    throw new Error("アセットが見つかりません");
  }

  const assets = assetsDoc.data();
  const allImages = assets.images || [];
  const allTopics = assets.topics || [];

  if (allImages.length < 5 || allTopics.length < playerNicknames.length - 1) {
    throw new Error("アセットが不足しています");
  }

  if (!existingGameData) {
    const shuffledImages = shuffleArray(allImages);
    const currentImages = shuffledImages.slice(0, 5);
    const answerImageIndex = Math.floor(Math.random() * 5);
    const randomIndex = Math.floor(Math.random() * playerNicknames.length);
    const parentPlayer = playerNicknames[randomIndex];

    const players = playerNicknames.map((nickname) => ({
      nickname: nickname,
      isReady: false,
      isEverParent: nickname === parentPlayer,
      point: 0,
    }));

    const shuffledTopics = shuffleArray(allTopics);
    const topics = {};
    let topicIndex = 0;

    playerNicknames.forEach((nickname) => {
      if (nickname !== parentPlayer) {
        topics[nickname] = shuffledTopics[topicIndex++];
      }
    });

    return {
      players: players,
      currentParent: parentPlayer,
      currentImages: currentImages,
      answerImageIndex: answerImageIndex,
      topics: topics,
      usedImages: [...currentImages],
      usedTopics: Object.values(topics),
    };
  }

  if (isNewRound) {
    const randomIndex = Math.floor(Math.random() * playerNicknames.length);
    const parentPlayer = playerNicknames[randomIndex];

    const players = existingGameData.players.map((player) => ({
      nickname: player.nickname,
      isReady: false,
      isEverParent: player.nickname === parentPlayer,
      point: player.point || 0,
    }));

    let usedImages = [...existingGameData.usedImages];
    let usedTopics = [...existingGameData.usedTopics];
    const unusedImages = allImages.filter((img) => !usedImages.includes(img));
    let currentImages;
    if (unusedImages.length >= 5) {
      const shuffled = shuffleArray(unusedImages);
      currentImages = shuffled.slice(0, 5);
    } else {
      const shuffled = shuffleArray(allImages);
      currentImages = shuffled.slice(0, 5);
    }

    const answerImageIndex = Math.floor(Math.random() * 5);
    const topics = {};
    const childPlayers = playerNicknames.filter((nickname) => nickname !== parentPlayer);
    const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
    const topicSource = unusedTopics.length >= childPlayers.length ? unusedTopics : allTopics;
    const shuffledTopics = shuffleArray(topicSource);

    childPlayers.forEach((nickname, index) => {
      topics[nickname] = shuffledTopics[index % shuffledTopics.length];
    });

    usedImages = [...usedImages, ...currentImages];
    usedTopics = [...usedTopics, ...Object.values(topics)];

    return {
      players: players,
      currentParent: parentPlayer,
      currentImages: currentImages,
      answerImageIndex: answerImageIndex,
      topics: topics,
      usedImages: usedImages,
      usedTopics: usedTopics,
    };
  }

  const currentParentIndex = existingGameData.players.findIndex(
      (player) => player.nickname === existingGameData.currentParent,
  );
  const nextParentIndex = (currentParentIndex + 1) % existingGameData.players.length;
  const nextParent = existingGameData.players[nextParentIndex].nickname;
  let usedImages = [...existingGameData.usedImages];
  let usedTopics = [...existingGameData.usedTopics];
  const unusedImages = allImages.filter((img) => !usedImages.includes(img));
  let currentImages;
  if (unusedImages.length >= 5) {
    const shuffled = shuffleArray(unusedImages);
    currentImages = shuffled.slice(0, 5);
  } else {
    const shuffled = shuffleArray(allImages);
    currentImages = shuffled.slice(0, 5);
  }

  const answerImageIndex = Math.floor(Math.random() * 5);
  const topics = {};
  const childPlayers = playerNicknames.filter((nickname) => nickname !== nextParent);
  const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
  const topicSource = unusedTopics.length >= childPlayers.length ? unusedTopics : allTopics;
  const shuffledTopics = shuffleArray(topicSource);

  childPlayers.forEach((nickname, index) => {
    topics[nickname] = shuffledTopics[index % shuffledTopics.length];
  });

  usedImages = [...usedImages, ...currentImages];
  usedTopics = [...usedTopics, ...Object.values(topics)];

  return {
    currentParent: nextParent,
    currentImages: currentImages,
    answerImageIndex: answerImageIndex,
    topics: topics,
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
