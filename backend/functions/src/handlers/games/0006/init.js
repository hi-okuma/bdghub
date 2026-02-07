const {db} = require("../../../config/firebase");

/**
 * 流行語150のcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);
  const isSoloPlay = playerUids.length === 1;

  const boardCards = await prepareBoardCards();

  // ターン順をランダムに決定
  const turnOrder = isSoloPlay
    ? [playerUids[0], "cpu"]
    : shuffleArray([...playerUids]);

  // プレイヤーデータ初期化
  const playersData = {};
  turnOrder.forEach((uid) => {
    playersData[uid] = {
      score: 0,
      cardCount: 0,
      isBurst: false,
      selectedCards: [],
    };
  });

  return {
    gameStatus: "playing",
    turnOrder: turnOrder,
    currentTurnPlayerIndex: 0,
    turnPhase: "selectCard",
    totalTurnCount: 0,
    boardCards: boardCards,
    pendingCardIndex: null,
    players: playersData,
    config: {
      targetScore: 150,
      maxCardsPerPlayer: 5,
      boardSize: 16,
    },
    hasCpu: isSoloPlay,
    cpuPlayerId: isSoloPlay ? "cpu" : null,
    result: null,
  };
}

/**
 * 盤面カード（16枚）を準備する
 * アセットから全150枚を取得し、ランダムに16枚を選出
 * @return {Promise<Array>} 盤面カード配列
 */
async function prepareBoardCards() {
  const assetsDoc = await db.collection("games").doc("0006")
      .collection("assets")
      .doc("buzzwords")
      .get();

  if (!assetsDoc.exists) {
    throw new Error("流行語カードアセットが見つかりません");
  }

  const assets = assetsDoc.data();
  const allCards = assets.cards || [];

  if (allCards.length < 16) {
    throw new Error("カードが不足しています（最低16枚必要）");
  }

  // 全カードからランダムに16枚を選出
  const shuffled = shuffleArray(allCards);
  const selected = shuffled.slice(0, 16);

  // 盤面カード形式に変換
  return selected.map((card) => ({
    id: card.id,
    buzzword: card.buzzword,
    year: card.year,
    eraName: card.eraName,
    eraYear: card.eraYear,
    westernValue: card.year % 100,
    isAvailable: true,
  }));
}

/**
 * 配列をシャッフルする（Fisher-Yatesアルゴリズム）
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
