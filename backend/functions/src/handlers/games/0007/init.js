const {db} = require("../../../config/firebase");

/**
 * サンタ苦労ス（0007）のcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報（room.playersから渡される）
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);

  const topicsList = await loadTopics();
  const roleCardUrls = await loadRoleCardUrls();

  if (topicsList.length === 0) {
    throw new Error("お題が登録されていません");
  }
  if (roleCardUrls.length === 0) {
    throw new Error("おじさんカードが登録されていません");
  }

  const firstPresenter = playerUids[Math.floor(Math.random() * playerUids.length)];
  const firstTopic = topicsList[Math.floor(Math.random() * topicsList.length)];
  const firstRoleCard = roleCardUrls[Math.floor(Math.random() * roleCardUrls.length)];

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
    currentRoleCard: firstRoleCard,
    usedTopic: [firstTopic],
    usedRoleCard: [firstRoleCard],
    endsAt: null,
  };
}

/**
 * お題リストをFirestoreから取得する
 * @return {Promise<Array<string>>} お題リスト
 */
async function loadTopics() {
  const topicsDoc = await db.collection("games").doc("0007")
      .collection("assets")
      .doc("topics")
      .get();

  if (!topicsDoc.exists) {
    throw new Error("お題リストが見つかりません");
  }

  return topicsDoc.data().topics || [];
}

/**
 * おじさんカードのURLリストをFirestoreから取得する
 * games/0007/assets/roleCards はマップ形式で、キーがカードID、値が { url: string }
 * @return {Promise<Array<string>>} カードURLの配列
 */
async function loadRoleCardUrls() {
  const roleCardsDoc = await db.collection("games").doc("0007")
      .collection("assets")
      .doc("roleCards")
      .get();

  if (!roleCardsDoc.exists) {
    throw new Error("おじさんカードが見つかりません");
  }

  const data = roleCardsDoc.data() || {};
  return Object.values(data)
      .map((card) => card && card.url)
      .filter((url) => typeof url === "string" && url.length > 0);
}

module.exports = {
  createCurrentGame,
  loadTopics,
  loadRoleCardUrls,
};
