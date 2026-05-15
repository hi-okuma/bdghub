const {db} = require("../../../config/firebase");

/**
 * サンタ苦労ス（0007）のcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報（room.playersから渡される）
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);

  const topicsList = await loadTopics();
  const roleCardIds = await loadRoleCardIds();

  if (topicsList.length === 0) {
    throw new Error("お題が登録されていません");
  }
  if (roleCardIds.length === 0) {
    throw new Error("おじさんカードが登録されていません");
  }

  const firstPresenter = playerUids[Math.floor(Math.random() * playerUids.length)];
  const firstTopic = topicsList[Math.floor(Math.random() * topicsList.length)];
  const firstRoleCard = roleCardIds[Math.floor(Math.random() * roleCardIds.length)];

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
 * おじさんカードのIDリストをFirestoreから取得する
 * games/0007/assets/roleCards はマップ形式で、キーがカードID、値が { url: string }
 * @return {Promise<Array<string>>} カードIDの配列
 */
async function loadRoleCardIds() {
  const roleCardsDoc = await db.collection("games").doc("0007")
      .collection("assets")
      .doc("roleCards")
      .get();

  if (!roleCardsDoc.exists) {
    throw new Error("おじさんカードが見つかりません");
  }

  return Object.keys(roleCardsDoc.data() || {});
}

module.exports = {
  createCurrentGame,
  loadTopics,
  loadRoleCardIds,
};
