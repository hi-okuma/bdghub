const {db} = require("../../../config/firebase");

/**
 * 偏見プロフィールゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);
  const gameData = await initializeGameData(playerUids);

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
 * @param {Array<string>} playerUids - プレイヤーのuidの配列
 * @param {Object} existingGameData - 既存のゲームデータ（継続時）
 * @param {boolean} isNewRound - 新しいラウンドかどうか（一巡後）
 * @return {Promise<Object>} 初期化されたゲームデータ
 */
async function initializeGameData(playerUids, existingGameData = null, isNewRound = false) {
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

  if (allImages.length < 5 || allTopics.length < playerUids.length - 1) {
    throw new Error("アセットが不足しています");
  }

  if (!existingGameData) {
    const shuffledImages = shuffleArray(allImages);
    const currentImages = shuffledImages.slice(0, 5);
    const answerImageIndex = Math.floor(Math.random() * 5);
    const randomIndex = Math.floor(Math.random() * playerUids.length);
    const parentPlayer = playerUids[randomIndex];
    const playersData = {};
    playerUids.forEach((uid) => {
      playersData[uid] = {
        isReady: false,
        isEverParent: uid === parentPlayer,
        point: 0,
      };
    });

    const shuffledTopics = shuffleArray(allTopics);
    const topics = {};
    let topicIndex = 0;

    playerUids.forEach((uid) => {
      if (uid !== parentPlayer) {
        topics[uid] = shuffledTopics[topicIndex++];
      }
    });

    return {
      players: playersData,
      currentParent: parentPlayer,
      currentImages: currentImages,
      answerImageIndex: answerImageIndex,
      topics: topics,
      usedImages: [...currentImages],
      usedTopics: Object.values(topics),
    };
  }

  if (isNewRound) {
    const randomIndex = Math.floor(Math.random() * playerUids.length);
    const parentPlayer = playerUids[randomIndex];

    const players = existingGameData.players.map((player) => ({
      uid: player.uid,
      isReady: false,
      isEverParent: player.uid === parentPlayer,
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
    const childPlayers = playerUids.filter((uid) => uid !== parentPlayer);
    const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
    const topicSource = unusedTopics.length >= childPlayers.length ? unusedTopics : allTopics;
    const shuffledTopics = shuffleArray(topicSource);

    childPlayers.forEach((uid, index) => {
      topics[uid] = shuffledTopics[index % shuffledTopics.length];
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
      (player) => player.uid === existingGameData.currentParent,
  );
  const nextParentIndex = (currentParentIndex + 1) % existingGameData.players.length;
  const nextParent = existingGameData.players[nextParentIndex].uid;
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
  const childPlayers = playerUids.filter((uid) => uid !== nextParent);
  const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
  const topicSource = unusedTopics.length >= childPlayers.length ? unusedTopics : allTopics;
  const shuffledTopics = shuffleArray(topicSource);

  childPlayers.forEach((uid, index) => {
    topics[uid] = shuffledTopics[index % shuffledTopics.length];
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
