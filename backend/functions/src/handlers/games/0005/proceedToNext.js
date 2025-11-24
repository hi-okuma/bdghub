const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {initializeGameData} = require("./init");
const {
  throwValidationError,
  throwNotFoundError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

/**
 * 1人で偏見プロフィールゲームの次ターン準備リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function proceedToNext0005Handler(request) {
  const {roomId, isCorrect} = request.data;

  if (!roomId || isCorrect === undefined || isCorrect === null) {
    throwValidationError("不正なリクエストです。");
  }

  try {
    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0005");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwNotFoundError(
            "ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。",
        );
      }

      const currentGameData = currentGameDoc.data();
      const currentQuestionNumber = currentGameData.currentQuestionNumber || 1;
      const currentPoint = currentGameData.point || 0;

      const newPoint = isCorrect ? currentPoint + 1 : currentPoint;

      if (currentQuestionNumber < 5) {
        const nextQuestionData = await prepareNextQuestion(currentGameData);

        transaction.update(currentGameRef, {
          currentQuestionNumber: currentQuestionNumber + 1,
          currentImages: nextQuestionData.currentImages,
          answerImageIndex: nextQuestionData.answerImageIndex,
          topicsAndHints: nextQuestionData.topicsAndHints,
          selectedIndex: null,
          usedImages: nextQuestionData.usedImages,
          usedTopics: nextQuestionData.usedTopics,
          point: newPoint,
        });
      } else {
        const nextGameData = await initializeGameData(currentGameData);

        transaction.update(currentGameRef, {
          currentQuestionNumber: nextGameData.currentQuestionNumber,
          currentImages: nextGameData.currentImages,
          answerImageIndex: nextGameData.answerImageIndex,
          topicsAndHints: nextGameData.topicsAndHints,
          selectedIndex: null,
          usedImages: nextGameData.usedImages,
          usedTopics: nextGameData.usedTopics,
          point: newPoint,
        });
      }
    });

    logger.info(`次ターン準備成功: roomId=${roomId}, isCorrect=${isCorrect}`, {
      roomId,
      isCorrect,
    });

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("次ターン準備エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      isCorrect,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * 次の問題を準備する
 * @param {Object} currentGameData - 現在のゲームデータ
 * @return {Promise<Object>} 次の問題のデータ
 */
async function prepareNextQuestion(currentGameData) {
  const assetsDoc = await db.collection("games").doc("0005")
      .collection("assets")
      .doc("data")
      .get();

  if (!assetsDoc.exists) {
    throw new Error("アセットが見つかりません");
  }

  const assets = assetsDoc.data();
  const allImages = assets.images || [];
  const allTopicsAndHints = assets.topicsAndHints || {};
  const allTopics = Object.keys(allTopicsAndHints);

  if (allImages.length < 5 || allTopics.length < 3) {
    throw new Error("アセットが不足しています");
  }

  let usedImages = currentGameData.usedImages || [];
  const unusedImages = allImages.filter((img) => !usedImages.includes(img));
  let currentImages;

  if (unusedImages.length >= 5) {
    const shuffled = shuffleArray(unusedImages);
    currentImages = shuffled.slice(0, 5);
    usedImages = [...usedImages, ...currentImages];
  } else {
    const shuffled = shuffleArray(allImages);
    currentImages = shuffled.slice(0, 5);
    usedImages = [...currentImages];
  }

  const answerImageIndex = Math.floor(Math.random() * 5);

  let usedTopics = currentGameData.usedTopics || [];
  const unusedTopics = allTopics.filter((topic) => !usedTopics.includes(topic));
  let selectedTopics;

  if (unusedTopics.length >= 3) {
    selectedTopics = shuffleArray(unusedTopics).slice(0, 3);
    usedTopics = [...usedTopics, ...selectedTopics];
  } else {
    selectedTopics = shuffleArray(allTopics).slice(0, 3);
    usedTopics = [...selectedTopics];
  }

  const topicsAndHints = {};
  selectedTopics.forEach((topic) => {
    const hints = allTopicsAndHints[topic];
    if (hints && hints.length > 0) {
      const randomHintIndex = Math.floor(Math.random() * hints.length);
      topicsAndHints[topic] = hints[randomHintIndex];
    }
  });

  return {
    currentImages: currentImages,
    answerImageIndex: answerImageIndex,
    topicsAndHints: topicsAndHints,
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
  proceedToNext0005Handler,
};
