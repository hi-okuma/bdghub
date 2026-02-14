const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {reinitializeGame, getGameConfig} = require("./init");
const {
  throwValidationError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 流行語ゲームの年代決定リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function adoptValue0006Handler(request) {
  const {roomId, uid, valueType} = request.data;

  if (!roomId || !uid || !valueType) {
    throwValidationError("不正なリクエストです。");
  }

  if (valueType !== "Western" && valueType !== "Japanese") {
    throwValidationError("不正なリクエストです。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0006");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwStructuredError("GameNotFound", "エラーが発生しました。リロードし、再度部屋を作り直してください。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throwGameStatusError("playing", currentGameData.gameStatus);
      }

      // 手番プレイヤーの検証
      const currentTurnUid = currentGameData.turnOrder[currentGameData.currentTurnPlayerIndex];
      if (uid !== currentTurnUid) {
        throwValidationError("手番でないプレイヤーのuidが指定されています。");
      }

      // バースト済みプレイヤーの検証
      if (currentGameData.players[uid] && currentGameData.players[uid].isBurst) {
        throwValidationError("バースト済みのプレイヤーのuidが指定されています。");
      }

      // 選択されたカードを特定
      const selectedCardId = currentGameData.selectedCardId;
      if (!selectedCardId) {
        throwValidationError("不正なリクエストです。");
      }

      const selectedCardIndex = currentGameData.boardCards.findIndex(
          (card) => card.cardId === selectedCardId,
      );

      if (selectedCardIndex === -1) {
        throwValidationError("不正なリクエストです。");
      }

      const selectedCard = currentGameData.boardCards[selectedCardIndex];

      // スコア計算
      const addedScore = calculateScore(selectedCard.year, valueType);
      const currentPlayer = currentGameData.players[uid];
      const newScore = currentPlayer.score + addedScore;

      // ゲーム設定を取得
      const playerCount = Object.keys(currentGameData.players).length;
      const config = await getGameConfig(playerCount);

      // カードを取得済みにする
      const updatedBoardCards = [...currentGameData.boardCards];
      updatedBoardCards[selectedCardIndex] = {
        ...updatedBoardCards[selectedCardIndex],
        isAvailable: false,
      };

      // プレイヤーデータを更新
      const updatedPlayers = {...currentGameData.players};
      updatedPlayers[uid] = {
        ...updatedPlayers[uid],
        score: newScore,
        cardCount: currentPlayer.cardCount + 1,
      };

      // バースト判定
      if (newScore > config.targetScore) {
        // バースト
        updatedPlayers[uid] = {
          ...updatedPlayers[uid],
          isBurst: true,
        };

        // 未バーストプレイヤーの数を確認
        const nonBurstPlayers = Object.entries(updatedPlayers)
            .filter(([, player]) => !player.isBurst);

        if (nonBurstPlayers.length <= 1) {
          // ゲーム終了: 未バーストが1人以下
          const endGameData = await buildEndGameData(
              currentGameData,
              updatedPlayers,
              updatedBoardCards,
              addedScore,
              config.targetScore,
          );
          transaction.update(currentGameRef, endGameData);
        } else {
          // ゲーム継続: 次の未バーストプレイヤーへ
          const nextIndex = findNextNonBurstPlayerIndex(
              currentGameData.turnOrder,
              currentGameData.currentTurnPlayerIndex,
              updatedPlayers,
          );

          // 全員がmaxCardsPerPlayer枚引き終わったかチェック
          const allMaxCards = checkAllPlayersMaxCards(updatedPlayers, config.maxCardsPerPlayer);

          if (allMaxCards) {
            const endGameData = await buildEndGameData(
                currentGameData,
                updatedPlayers,
                updatedBoardCards,
                addedScore,
                config.targetScore,
            );
            transaction.update(currentGameRef, endGameData);
          } else {
            transaction.update(currentGameRef, {
              players: updatedPlayers,
              boardCards: updatedBoardCards,
              selectedCardId: null,
              currentTurnPlayerIndex: nextIndex,
              lastTurnScore: addedScore,
            });
          }
        }
      } else {
        // バーストしない場合
        // 次の手番プレイヤーを決定
        const nextIndex = findNextNonBurstPlayerIndex(
            currentGameData.turnOrder,
            currentGameData.currentTurnPlayerIndex,
            updatedPlayers,
        );

        // 全員がmaxCardsPerPlayer枚引き終わったかチェック
        const allMaxCards = checkAllPlayersMaxCards(updatedPlayers, config.maxCardsPerPlayer);

        if (allMaxCards) {
          // ゲーム終了: 規定枚数到達
          const endGameData = await buildEndGameData(
              currentGameData,
              updatedPlayers,
              updatedBoardCards,
              addedScore,
              config.targetScore,
          );
          transaction.update(currentGameRef, endGameData);
        } else {
          // ゲーム継続
          transaction.update(currentGameRef, {
            players: updatedPlayers,
            boardCards: updatedBoardCards,
            selectedCardId: null,
            currentTurnPlayerIndex: nextIndex,
            lastTurnScore: addedScore,
          });
        }
      }
    });

    logger.info(`年代決定成功: roomId=${roomId}, uid=${uid}, valueType=${valueType}`, {
      roomId,
      uid,
      valueType,
    });

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("年代決定エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      valueType,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * スコアを計算する
 * Western: 西暦の下2桁（例: 2017 → 17）
 * Japanese: 和暦の年数（例: 2017 → 平成29 → 29）
 * @param {number} year - カードの西暦年
 * @param {string} valueType - "Western" または "Japanese"
 * @return {number} 計算されたスコア
 */
function calculateScore(year, valueType) {
  if (valueType === "Western") {
    return year % 100;
  }

  // 和暦変換
  return convertToJapaneseEraYear(year);
}

/**
 * 西暦を和暦の年数に変換する
 * @param {number} year - 西暦年
 * @return {number} 和暦の年数
 */
function convertToJapaneseEraYear(year) {
  if (year >= 2019) {
    return year - 2018; // 令和
  } else if (year >= 1989) {
    return year - 1988; // 平成
  } else if (year >= 1926) {
    return year - 1925; // 昭和
  } else if (year >= 1912) {
    return year - 1911; // 大正
  } else if (year >= 1868) {
    return year - 1867; // 明治
  }
  // それ以前は西暦の下2桁を返す
  return year % 100;
}

/**
 * 次の未バーストプレイヤーのインデックスを探す
 * @param {Array<string>} turnOrder - ターン順配列
 * @param {number} currentIndex - 現在のインデックス
 * @param {Object} players - プレイヤーデータ
 * @return {number} 次の未バーストプレイヤーのインデックス
 */
function findNextNonBurstPlayerIndex(turnOrder, currentIndex, players) {
  const totalPlayers = turnOrder.length;

  for (let i = 1; i <= totalPlayers; i++) {
    const nextIndex = (currentIndex + i) % totalPlayers;
    const nextUid = turnOrder[nextIndex];

    if (!players[nextUid].isBurst) {
      return nextIndex;
    }
  }

  // 全員バーストの場合（通常到達しない）
  return currentIndex;
}

/**
 * 全ての未バーストプレイヤーがmaxCardsPerPlayer枚引き終わったかチェック
 * @param {Object} players - プレイヤーデータ
 * @param {number} maxCardsPerPlayer - プレイヤーごとの最大カード枚数
 * @return {boolean} 全員が規定枚数到達の場合true
 */
function checkAllPlayersMaxCards(players, maxCardsPerPlayer) {
  return Object.values(players).every(
      (player) => player.isBurst || player.cardCount >= maxCardsPerPlayer,
  );
}

/**
 * 勝者を決定する
 * @param {Object} players - プレイヤーデータ
 * @param {number} targetScore - 目標スコア
 * @return {string|null} 勝者のUID、引き分けの場合はnull
 */
function determineWinner(players, targetScore) {
  const nonBurstPlayers = Object.entries(players)
      .filter(([, player]) => !player.isBurst);

  // 全員バーストの場合は引き分け
  if (nonBurstPlayers.length === 0) {
    return null;
  }

  // 未バーストが1人の場合はその人が勝者
  if (nonBurstPlayers.length === 1) {
    return nonBurstPlayers[0][0];
  }

  // 複数人が未バーストの場合、targetScoreに最も近いプレイヤーが勝者
  // targetScore以下でスコアが最も高い人 = targetScoreとの差が最も小さい人
  let closestDistance = Infinity;
  let closestPlayers = [];

  for (const [uid, player] of nonBurstPlayers) {
    const distance = targetScore - player.score;

    if (distance < closestDistance) {
      closestDistance = distance;
      closestPlayers = [uid];
    } else if (distance === closestDistance) {
      closestPlayers.push(uid);
    }
  }

  // 同スコアが複数人いれば引き分け
  if (closestPlayers.length > 1) {
    return null;
  }

  return closestPlayers[0];
}

/**
 * ゲーム終了時の更新データを構築する
 * @param {Object} currentGameData - 現在のゲームデータ
 * @param {Object} updatedPlayers - 更新済みプレイヤーデータ
 * @param {Array} updatedBoardCards - 更新済みボードカード
 * @param {number} lastTurnScore - 直近のスコア
 * @param {number} targetScore - 目標スコア
 * @return {Promise<Object>} 更新データ
 */
async function buildEndGameData(
    currentGameData,
    updatedPlayers,
    updatedBoardCards,
    lastTurnScore,
    targetScore,
) {
  const winnerId = determineWinner(updatedPlayers, targetScore);

  // 次ゲーム用に再初期化
  const nextGameData = await reinitializeGame({
    ...currentGameData,
    players: updatedPlayers,
  });

  return {
    gameStatus: "waiting",
    players: nextGameData.players,
    turnOrder: nextGameData.turnOrder,
    currentTurnPlayerIndex: 0,
    boardCards: nextGameData.boardCards,
    selectedCardId: null,
    lastTurnScore: lastTurnScore,
    winnerId: winnerId,
  };
}

module.exports = {
  adoptValue0006Handler,
  calculateScore,
  convertToJapaneseEraYear,
};
