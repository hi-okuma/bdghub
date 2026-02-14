const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 流行語ゲームのカード確定リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function confirmCard0006Handler(request) {
  const {roomId, uid, cardId} = request.data;

  if (!roomId || !uid || !cardId) {
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

      // cardIdに一致するカードを検索
      const targetCard = currentGameData.boardCards.find(
          (card) => card.cardId === cardId,
      );

      if (!targetCard) {
        throwValidationError("存在しないカードが指定されています。");
      }

      // カードの利用可能チェック
      if (!targetCard.isAvailable) {
        throwValidationError("獲得済みのカードが指定されています。");
      }

      // selectedCardIdを更新
      transaction.update(currentGameRef, {
        selectedCardId: targetCard.cardId,
      });
    });

    logger.info(`カード確定成功: roomId=${roomId}, uid=${uid}, cardId=${cardId}`, {
      roomId,
      uid,
      cardId,
    });

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("カード確定エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      cardId,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  confirmCard0006Handler,
};
