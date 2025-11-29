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

      if (currentQuestionNumber < 5) {
        const nextQuestionData = await prepareNextQuestion(currentGameData);

        // 1問目でpointが0以外の場合は、前回のゲーム結果が残っているのでリセット
        const resetPoint = (currentQuestionNumber === 1 && currentPoint > 0) ? 0 : currentPoint;
        const newPoint = isCorrect ? resetPoint + 1 : resetPoint;

        transaction.update(currentGameRef, {
          currentQuestionNumber: currentQuestionNumber + 1,
          currentImages: nextQuestionData.currentImages,
          answerImageIndex: nextQuestionData.answerImageIndex,
          topicsAndHints: nextQuestionData.topicsAndHints,
          selectedIndex: null,
          usedCharacters: nextQuestionData.usedCharacters,
          point: newPoint,
        });
      } else {
        const nextGameData = await initializeGameData(currentGameData);

        // 5問目終了時は結果発表画面で表示するためpointを保持
        const newPoint = isCorrect ? currentPoint + 1 : currentPoint;

        transaction.update(currentGameRef, {
          currentQuestionNumber: nextGameData.currentQuestionNumber,
          currentImages: nextGameData.currentImages,
          answerImageIndex: nextGameData.answerImageIndex,
          topicsAndHints: nextGameData.topicsAndHints,
          selectedIndex: null,
          usedCharacters: nextGameData.usedCharacters,
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
  const allCharacters = assets.characters || [];

  if (allCharacters.length < 5) {
    throw new Error("キャラクターが不足しています（最低5人必要）");
  }

  // 使用済みキャラクターを管理
  let usedCharacters = currentGameData.usedCharacters || [];
  const unusedCharacters = allCharacters.filter(
      (char) => !usedCharacters.includes(char.imageUrl),
  );

  // 正解のキャラクターを選択
  let answerCharacter;
  if (unusedCharacters.length > 0) {
    answerCharacter = unusedCharacters[Math.floor(Math.random() * unusedCharacters.length)];
  } else {
    // 全キャラクター使用済みの場合はリセットして選び直し
    answerCharacter = allCharacters[Math.floor(Math.random() * allCharacters.length)];
    usedCharacters = [];
  }

  // 正解キャラクターのprofilesから3つのトピックをランダムに選択
  const profiles = answerCharacter.profiles || {};
  const allTopics = Object.keys(profiles);

  if (allTopics.length < 3) {
    throw new Error(`キャラクター ${answerCharacter.imageUrl} のトピックが不足しています（最低3つ必要）`);
  }

  const selectedTopics = shuffleArray(allTopics).slice(0, 3);

  // 各トピックから1つのヒントをランダムに選択
  const topicsAndHints = {};
  selectedTopics.forEach((topic) => {
    const hints = profiles[topic];
    if (hints && hints.length > 0) {
      const randomHintIndex = Math.floor(Math.random() * hints.length);
      topicsAndHints[topic] = hints[randomHintIndex];
    }
  });

  // 5枚の画像を用意（正解1枚 + 他4枚）
  const otherCharacters = allCharacters.filter((char) => char.imageUrl !== answerCharacter.imageUrl);
  if (otherCharacters.length < 4) {
    throw new Error("選択肢用のキャラクターが不足しています（正解以外に最低4人必要）");
  }

  const shuffledOthers = shuffleArray(otherCharacters);
  const selectedOthers = shuffledOthers.slice(0, 4);

  // 5枚の画像をシャッフル
  const allImages = [answerCharacter.imageUrl, ...selectedOthers.map((char) => char.imageUrl)];
  const shuffledImages = shuffleArray(allImages);

  // 正解画像のインデックスを取得
  const answerImageIndex = shuffledImages.indexOf(answerCharacter.imageUrl);

  // 使用済みキャラクターに追加
  usedCharacters = [...usedCharacters, answerCharacter.imageUrl];

  return {
    currentImages: shuffledImages,
    answerImageIndex: answerImageIndex,
    topicsAndHints: topicsAndHints,
    usedCharacters: usedCharacters,
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
