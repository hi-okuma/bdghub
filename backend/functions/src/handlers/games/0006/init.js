const {db} = require("../../../config/firebase");

const CPU_UID = "cpu";

/**
 * 流行語ゲームのcurrentGameデータを生成する
 * @param {Object} players - プレイヤー情報（room.playersから渡される）
 * @return {Promise<Object>} currentGameデータ
 */
async function createCurrentGame(players) {
  const playerUids = Object.keys(players);

  // 1人プレイの場合、CPUプレイヤーを追加して2人対戦にする
  if (playerUids.length === 1) {
    playerUids.push(CPU_UID);
  }

  const playerCount = playerUids.length;

  // プレイヤー数に応じた設定を取得
  const config = await getGameConfig(playerCount);

  // カードアセットを取得してボードを生成
  const boardCards = await generateBoardCards(config.boardSize);

  // ターン順をランダムに決定
  const turnOrder = shuffleArray([...playerUids]);

  // プレイヤーデータを初期化
  const playersData = {};
  playerUids.forEach((uid) => {
    playersData[uid] = {
      isReady: uid === CPU_UID,
      score: 0,
      lastScore: 0,
      cardCount: 0,
      isBurst: false,
    };
  });

  return {
    gameStatus: "waiting",
    players: playersData,
    turnOrder: turnOrder,
    currentTurnPlayerIndex: 0,
    boardCards: boardCards,
    selectedCardId: null,
    lastTurnScore: null,
    winnerId: null,
  };
}

/**
 * 次ゲーム用にゲームデータを再初期化する
 * @param {Object} currentGameData - 現在のゲームデータ
 * @return {Promise<Object>} 再初期化されたゲームデータ
 */
async function reinitializeGame(currentGameData) {
  const playerUids = Object.keys(currentGameData.players);
  const playerCount = playerUids.length;

  const config = await getGameConfig(playerCount);
  const boardCards = await generateBoardCards(config.boardSize);
  const turnOrder = shuffleArray([...playerUids]);

  // プレイヤーデータを再初期化（lastScoreに現在のスコアを保存）
  const playersData = {};
  playerUids.forEach((uid) => {
    const currentPlayer = currentGameData.players[uid];
    playersData[uid] = {
      isReady: uid === CPU_UID,
      score: 0,
      lastScore: currentPlayer.score || 0,
      cardCount: 0,
      isBurst: false,
    };
  });

  return {
    gameStatus: "waiting",
    players: playersData,
    turnOrder: turnOrder,
    currentTurnPlayerIndex: 0,
    boardCards: boardCards,
    selectedCardId: null,
    lastTurnScore: null,
    winnerId: null,
  };
}

/**
 * プレイヤー数に応じたゲーム設定を取得する
 * @param {number} playerCount - プレイヤー数
 * @return {Promise<Object>} ゲーム設定
 */
async function getGameConfig(playerCount) {
  const configDoc = await db.collection("games").doc("0006")
      .collection("assets")
      .doc("config")
      .get();

  if (!configDoc.exists) {
    throw new Error("ゲーム設定が見つかりません");
  }

  const configData = configDoc.data();
  const playerConfig = configData[String(playerCount)];

  if (!playerConfig) {
    throw new Error(`${playerCount}人プレイの設定が見つかりません`);
  }

  return {
    targetScore: playerConfig.targetScore,
    maxCardsPerPlayer: playerConfig.maxCardsPerPlayer,
    boardSize: playerConfig.boardSize,
  };
}

/**
 * ボードカードを生成する
 * @param {number} boardSize - ボードに配置するカード枚数
 * @return {Promise<Array<Object>>} ボードカードの配列
 */
async function generateBoardCards(boardSize) {
  const cardsDoc = await db.collection("games").doc("0006")
      .collection("assets")
      .doc("cards")
      .get();

  if (!cardsDoc.exists) {
    throw new Error("カードデータが見つかりません");
  }

  const cardsData = cardsDoc.data();
  const allCards = Object.entries(cardsData).map(([cardId, card]) => ({
    cardId: cardId,
    buzzword: card.buzzword,
    year: card.year,
  }));

  if (allCards.length < boardSize) {
    throw new Error(`カードが不足しています（必要: ${boardSize}枚, 利用可能: ${allCards.length}枚）`);
  }

  const shuffled = shuffleArray(allCards);
  const selectedCards = shuffled.slice(0, boardSize);

  return selectedCards.map((card) => ({
    cardId: card.cardId,
    buzzword: card.buzzword,
    year: card.year,
    isAvailable: true,
  }));
}

/**
 * 配列をシャッフルする（Fisher-Yates）
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
  reinitializeGame,
  getGameConfig,
  CPU_UID,
};
