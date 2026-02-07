const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 流行語150の西暦/和暦採用リクエストを処理するハンドラー
 * スコアを更新し、ターンを次のプレイヤーに進める
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function adoptValue0006Handler(request) {
  const {roomId, uid, valueType} = request.data;

  if (!roomId || !uid || !valueType) {
    throwValidationError("不正なリクエストです。");
  }

  if (valueType !== "western" && valueType !== "era") {
    throwValidationError("valueTypeは'western'または'era'を指定してください。");
  }

  try {
    let responseData = {};

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0006");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError(
            "ゲーム",
            "ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。",
        );
      }

      const gameData = currentGameDoc.data();

      // ゲーム状態チェック
      if (gameData.gameStatus !== "playing") {
        throwStructuredError("InvalidGameStatus", "ゲームは既に終了しています。");
      }

      // ターンフェーズチェック
      if (gameData.turnPhase !== "chooseValue") {
        throwStructuredError(
            "InvalidGameStatus",
            "現在値選択フェーズではありません。",
        );
      }

      // 手番チェック
      const currentTurnPlayer =
        gameData.turnOrder[gameData.currentTurnPlayerIndex];
      if (currentTurnPlayer !== uid) {
        throwStructuredError(
            "InvalidGameStatus",
            "あなたのターンではありません。",
        );
      }

      // 選択中カード取得
      const pendingCardIndex = gameData.pendingCardIndex;
      if (pendingCardIndex === null || pendingCardIndex === undefined) {
        throwStructuredError(
            "InvalidGameStatus",
            "選択中のカードがありません。",
        );
      }

      const card = gameData.boardCards[pendingCardIndex];
      const chosenValue =
        valueType === "western" ? card.westernValue : card.eraYear;

      // スコア計算
      const playerData = gameData.players[uid];
      const newScore = playerData.score + chosenValue;
      const isBurst = newScore > gameData.config.targetScore;

      // 選択カード情報を作成
      const selectedCard = {
        cardId: card.id,
        buzzword: card.buzzword,
        chosenType: valueType,
        chosenValue: chosenValue,
        year: card.year,
        eraName: card.eraName,
        eraYear: card.eraYear,
      };

      // 更新データ構築
      const newCardCount = playerData.cardCount + 1;
      const newSelectedCards = [...playerData.selectedCards, selectedCard];

      // カードを使用済みにする
      const updatedBoardCards = [...gameData.boardCards];
      updatedBoardCards[pendingCardIndex] = {
        ...updatedBoardCards[pendingCardIndex],
        isAvailable: false,
      };

      // プレイヤーデータ更新
      const updatedPlayers = {
        ...gameData.players,
        [uid]: {
          ...playerData,
          score: newScore,
          cardCount: newCardCount,
          isBurst: isBurst,
          selectedCards: newSelectedCards,
        },
      };

      const newTotalTurnCount = gameData.totalTurnCount + 1;

      // ゲーム終了判定
      const gameEndResult = checkGameEnd(
          updatedPlayers,
          gameData.turnOrder,
          gameData.config,
      );

      if (gameEndResult) {
        // ゲーム終了
        transaction.update(currentGameRef, {
          boardCards: updatedBoardCards,
          players: updatedPlayers,
          pendingCardIndex: null,
          turnPhase: "selectCard",
          totalTurnCount: newTotalTurnCount,
          gameStatus: "finished",
          result: gameEndResult,
        });

        responseData = {
          gameFinished: true,
          result: gameEndResult,
          isBurst: isBurst,
          chosenValue: chosenValue,
          newScore: newScore,
        };
      } else {
        // 次のプレイヤーのターンへ
        const nextPlayerIndex = findNextActivePlayer(
            gameData.currentTurnPlayerIndex,
            gameData.turnOrder,
            updatedPlayers,
            gameData.config,
        );

        transaction.update(currentGameRef, {
          boardCards: updatedBoardCards,
          players: updatedPlayers,
          pendingCardIndex: null,
          turnPhase: "selectCard",
          currentTurnPlayerIndex: nextPlayerIndex,
          totalTurnCount: newTotalTurnCount,
        });

        responseData = {
          gameFinished: false,
          isBurst: isBurst,
          chosenValue: chosenValue,
          newScore: newScore,
        };
      }
    });

    logger.info(
        `値採用成功: roomId=${roomId}, uid=${uid}, valueType=${valueType}`,
        {roomId, uid, valueType, ...responseData},
    );

    return {
      success: true,
      message: "",
      ...responseData,
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("値採用エラー", {
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
 * ゲーム終了条件をチェックする
 * @param {Object} players - 全プレイヤーデータ
 * @param {Array<string>} turnOrder - ターン順
 * @param {Object} config - ゲーム設定
 * @return {Object|null} 終了時はresultオブジェクト、継続時はnull
 */
function checkGameEnd(players, turnOrder, config) {
  const playerEntries = turnOrder.map((uid) => ({
    uid,
    ...players[uid],
  }));

  // 全員バースト → ゲーム終了
  const allBurst = playerEntries.every((p) => p.isBurst);
  if (allBurst) {
    return {
      winnerId: null,
      isDraw: true,
      winnerScore: 0,
      loserScore: 0,
      winReason: "opponentBurst",
    };
  }

  // バーストしていないプレイヤー
  const activePlayers = playerEntries.filter((p) => !p.isBurst);

  // アクティブプレイヤーが全員maxCardsPerPlayer枚取得済み → ゲーム終了
  const allActiveComplete = activePlayers.every(
      (p) => p.cardCount >= config.maxCardsPerPlayer,
  );

  // バーストしたプレイヤー + 完了プレイヤー = 全プレイヤー → ゲーム終了
  const burstPlayers = playerEntries.filter((p) => p.isBurst);
  const completePlayers = activePlayers.filter(
      (p) => p.cardCount >= config.maxCardsPerPlayer,
  );
  const allDone =
    burstPlayers.length + completePlayers.length === turnOrder.length;

  if (!allActiveComplete && !allDone) {
    return null; // ゲーム継続
  }

  // 勝者決定
  return determineWinner(playerEntries, config);
}

/**
 * 勝者を決定する
 * @param {Array<Object>} playerEntries - プレイヤー情報配列
 * @param {Object} config - ゲーム設定
 * @return {Object} resultオブジェクト
 */
function determineWinner(playerEntries, config) {
  const target = config.targetScore;

  // バーストしていないプレイヤーのみで判定
  const activePlayers = playerEntries.filter((p) => !p.isBurst);
  const burstPlayers = playerEntries.filter((p) => p.isBurst);

  // 全員バースト
  if (activePlayers.length === 0) {
    return {
      winnerId: null,
      isDraw: true,
      winnerScore: 0,
      loserScore: 0,
      winReason: "opponentBurst",
    };
  }

  // 1人だけ生存（相手バースト）
  if (activePlayers.length === 1 && burstPlayers.length > 0) {
    const winner = activePlayers[0];
    const loser = burstPlayers[0];
    return {
      winnerId: winner.uid,
      isDraw: false,
      winnerScore: winner.score,
      loserScore: loser.score,
      winReason: winner.score === target ? "perfect" : "opponentBurst",
    };
  }

  // 両者生存 → スコア比較
  const sorted = [...activePlayers].sort((a, b) => {
    // targetとの差が小さい方が上位
    const diffA = target - a.score;
    const diffB = target - b.score;
    return diffA - diffB;
  });

  const best = sorted[0];
  const second = sorted[1] || burstPlayers[0];

  // 同点判定
  if (second && !second.isBurst && best.score === second.score) {
    return {
      winnerId: null,
      isDraw: true,
      winnerScore: best.score,
      loserScore: second.score,
      winReason: "closer",
    };
  }

  return {
    winnerId: best.uid,
    isDraw: false,
    winnerScore: best.score,
    loserScore: second ? second.score : 0,
    winReason: best.score === target ? "perfect" : "closer",
  };
}

/**
 * 次のアクティブなプレイヤーのインデックスを見つける
 * バースト済み・カード取得完了のプレイヤーはスキップする
 * @param {number} currentIndex - 現在のプレイヤーインデックス
 * @param {Array<string>} turnOrder - ターン順配列
 * @param {Object} players - 全プレイヤーデータ
 * @param {Object} config - ゲーム設定
 * @return {number} 次のプレイヤーインデックス
 */
function findNextActivePlayer(currentIndex, turnOrder, players, config) {
  const playerCount = turnOrder.length;

  for (let i = 1; i <= playerCount; i++) {
    const nextIndex = (currentIndex + i) % playerCount;
    const nextUid = turnOrder[nextIndex];
    const nextPlayer = players[nextUid];

    // バーストしておらず、まだカードを取得できるプレイヤー
    if (!nextPlayer.isBurst && nextPlayer.cardCount < config.maxCardsPerPlayer) {
      return nextIndex;
    }
  }

  // 全員が終了している場合（通常はcheckGameEndで先に検出される）
  return currentIndex;
}

module.exports = {
  adoptValue0006Handler,
};
