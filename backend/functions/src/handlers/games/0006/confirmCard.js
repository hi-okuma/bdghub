const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 流行語150のカード選択確定リクエストを処理するハンドラー
 * カードを確定し、turnPhaseを"chooseValue"に遷移させる
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function confirmCard0006Handler(request) {
  const {roomId, uid, cardIndex} = request.data;

  if (!roomId || !uid || cardIndex === undefined || cardIndex === null) {
    throwValidationError("不正なリクエストです。");
  }

  if (typeof cardIndex !== "number" || cardIndex < 0 || cardIndex > 15) {
    throwValidationError("不正なカードインデックスです。");
  }

  try {
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
      if (gameData.turnPhase !== "selectCard") {
        throwStructuredError(
            "InvalidGameStatus",
            "現在カード選択フェーズではありません。",
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

      // バーストチェック
      if (gameData.players[uid].isBurst) {
        throwStructuredError(
            "InvalidGameStatus",
            "バーストしているため操作できません。",
        );
      }

      // カード選択可能チェック
      const card = gameData.boardCards[cardIndex];
      if (!card || !card.isAvailable) {
        throwStructuredError(
            "InvalidArgument",
            "このカードは選択できません。",
        );
      }

      // カード選択を確定
      transaction.update(currentGameRef, {
        turnPhase: "chooseValue",
        pendingCardIndex: cardIndex,
      });
    });

    logger.info(
        `カード選択確定: roomId=${roomId}, uid=${uid}, cardIndex=${cardIndex}`,
        {roomId, uid, cardIndex},
    );

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("カード選択確定エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      cardIndex,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

module.exports = {
  confirmCard0006Handler,
};
