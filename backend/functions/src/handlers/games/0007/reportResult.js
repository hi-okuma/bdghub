const {logger} = require("firebase-functions");
const {db} = require("../../../config/firebase");
const {loadTopics, loadRoleCardUrls} = require("./init");
const {
  throwValidationError,
  throwGameStatusError,
  throwStructuredError,
} = require("../../../utils/errorHandler");

const POINT_PRESENTER = 2;
const POINT_ANSWERER = 1;
const POINT_BONUS_PRESENTER = 1;

/**
 * サンタ苦労ス（0007）の結果報告リクエストを処理するハンドラー
 * おじさんが成功/失敗ダイアログで「次に進む」を押下した際に呼び出される。
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function reportResult0007Handler(request) {
  const {roomId, uid, result, answererUid, bonus} = request.data;

  if (!roomId || !uid || result === undefined) {
    throwValidationError("不正なリクエストです。");
  }
  if (result === true && (!answererUid || bonus === undefined)) {
    throwValidationError("不正なリクエストです。");
  }

  try {
    const topicsList = await loadTopics();
    const roleCardUrls = await loadRoleCardUrls();

    await db.runTransaction(async (transaction) => {
      const roomRef = db.collection("rooms").doc(roomId);
      const currentGameRef = roomRef.collection("currentGame").doc("0007");
      const currentGameDoc = await transaction.get(currentGameRef);

      if (!currentGameDoc.exists) {
        throwStructuredError("GameNotFound", "エラーが発生しました。リロードし、再度部屋を作り直してください。");
      }

      const currentGameData = currentGameDoc.data();

      if (currentGameData.gameStatus !== "playing") {
        throwGameStatusError("playing", currentGameData.gameStatus);
      }

      if (uid !== currentGameData.currentPresenter) {
        throwStructuredError("NotPresenter", "出題者ではありません。");
      }

      if (currentGameData.endsAt === null || currentGameData.endsAt === undefined) {
        throwStructuredError("InvalidGameStatus", "タイマーが開始されていません。");
      }

      if (result === true) {
        if (!currentGameData.players[answererUid]) {
          throwStructuredError("InvalidAnswerer", "不正な回答者です。");
        }
        if (answererUid === currentGameData.currentPresenter) {
          throwStructuredError("InvalidAnswerer", "不正な回答者です。");
        }
      }

      const updatedPlayers = applyScores(
          currentGameData.players,
          currentGameData.currentPresenter,
          result,
          answererUid,
          bonus,
      );

      const nextPresenter = findNextPresenter(updatedPlayers);
      const isOneRoundCompleted = nextPresenter === null;

      const updateData = isOneRoundCompleted ?
        buildOneRoundCompletedUpdate(
            updatedPlayers,
            currentGameData,
            topicsList,
            roleCardUrls,
        ) :
        buildNextRoundUpdate(
            updatedPlayers,
            nextPresenter,
            currentGameData,
            topicsList,
            roleCardUrls,
        );

      transaction.update(currentGameRef, updateData);
    });

    logger.info(`結果報告成功: roomId=${roomId}, uid=${uid}, result=${result}`, {
      roomId,
      uid,
      result,
      answererUid,
      bonus,
    });

    return {
      success: true,
      message: "",
    };
  } catch (error) {
    if (error.code && error.details) {
      throw error;
    }

    logger.error("結果報告エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      uid,
      result,
      answererUid,
      bonus,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
}

/**
 * 得点を加算する
 * - result=true             : presenter +2, answerer +1
 * - result=true && bonus    : 上記に加え presenter +1（サンタには加算しない）
 * - result=false            : 加点なし
 * @param {Object} players - プレイヤーデータ
 * @param {string} presenterUid - 出題者UID
 * @param {boolean} result - 正解かどうか
 * @param {string} answererUid - 回答者UID（result=true時）
 * @param {boolean} bonus - 縛りボーナス達成（result=true時）
 * @return {Object} 更新されたプレイヤーデータ
 */
function applyScores(players, presenterUid, result, answererUid, bonus) {
  const updated = {...players};

  if (result !== true) {
    return updated;
  }

  let presenterAdd = POINT_PRESENTER;
  if (bonus === true) {
    presenterAdd += POINT_BONUS_PRESENTER;
  }

  updated[presenterUid] = {
    ...updated[presenterUid],
    point: (updated[presenterUid].point || 0) + presenterAdd,
  };

  updated[answererUid] = {
    ...updated[answererUid],
    point: (updated[answererUid].point || 0) + POINT_ANSWERER,
  };

  return updated;
}

/**
 * 次の出題者を isEverPresenter === false のプレイヤーからランダム選出する
 * @param {Object} players - プレイヤーデータ
 * @return {string|null} 次の出題者のUID。全員が出題済みなら null
 */
function findNextPresenter(players) {
  const candidates = Object.entries(players)
      .filter(([, player]) => !player.isEverPresenter)
      .map(([uid]) => uid);

  if (candidates.length === 0) {
    return null;
  }

  return candidates[Math.floor(Math.random() * candidates.length)];
}

/**
 * 未使用のアイテムから1つランダムに選ぶ。全て使用済みなら全体からランダムに選ぶ。
 * @param {Array<string>} allItems - 全アイテム
 * @param {Array<string>} usedItems - 使用済みアイテム
 * @return {string} 選択されたアイテム
 */
function pickRandomUnused(allItems, usedItems) {
  const unused = allItems.filter((item) => !usedItems.includes(item));
  const pool = unused.length > 0 ? unused : allItems;
  return pool[Math.floor(Math.random() * pool.length)];
}

/**
 * 次ラウンドに進むための更新データを構築する
 * @param {Object} updatedPlayers - 得点反映後のプレイヤーデータ
 * @param {string} nextPresenter - 次の出題者UID
 * @param {Object} currentGameData - 現在のゲームデータ
 * @param {Array<string>} topicsList - 全お題リスト
 * @param {Array<string>} roleCardUrls - 全おじさんカードURLリスト
 * @return {Object} Firestore更新データ
 */
function buildNextRoundUpdate(
    updatedPlayers,
    nextPresenter,
    currentGameData,
    topicsList,
    roleCardUrls,
) {
  const nextTopic = pickRandomUnused(topicsList, currentGameData.usedTopic);
  const nextRoleCard = pickRandomUnused(roleCardUrls, currentGameData.usedRoleCard);

  const newPlayers = Object.fromEntries(
      Object.entries(updatedPlayers).map(([uid, player]) => [
        uid,
        uid === nextPresenter ? {...player, isEverPresenter: true} : player,
      ]),
  );

  return {
    players: newPlayers,
    currentPresenter: nextPresenter,
    currentTopic: nextTopic,
    currentRoleCard: nextRoleCard,
    usedTopic: [...currentGameData.usedTopic, nextTopic],
    usedRoleCard: [...currentGameData.usedRoleCard, nextRoleCard],
    endsAt: null,
  };
}

/**
 * ターン1周完了時の更新データを構築する。
 * 次ゲームに向けて新しい出題者・お題・カードを抽選し、isEverPresenter/isReadyをリセットする。
 * point はゲームをまたいで保持されるためリセットしない。
 * @param {Object} updatedPlayers - 得点反映後のプレイヤーデータ
 * @param {Object} currentGameData - 現在のゲームデータ
 * @param {Array<string>} topicsList - 全お題リスト
 * @param {Array<string>} roleCardUrls - 全おじさんカードURLリスト
 * @return {Object} Firestore更新データ
 */
function buildOneRoundCompletedUpdate(
    updatedPlayers,
    currentGameData,
    topicsList,
    roleCardUrls,
) {
  const playerUids = Object.keys(updatedPlayers);
  const nextFirstPresenter = playerUids[Math.floor(Math.random() * playerUids.length)];

  const nextTopic = pickRandomUnused(topicsList, currentGameData.usedTopic);
  const nextRoleCard = pickRandomUnused(roleCardUrls, currentGameData.usedRoleCard);

  const newPlayers = Object.fromEntries(
      Object.entries(updatedPlayers).map(([uid, player]) => [
        uid,
        {
          ...player,
          isReady: false,
          isEverPresenter: uid === nextFirstPresenter,
        },
      ]),
  );

  return {
    gameStatus: "waiting",
    players: newPlayers,
    currentPresenter: nextFirstPresenter,
    currentTopic: nextTopic,
    currentRoleCard: nextRoleCard,
    usedTopic: [...currentGameData.usedTopic, nextTopic],
    usedRoleCard: [...currentGameData.usedRoleCard, nextRoleCard],
    endsAt: null,
  };
}

module.exports = {
  reportResult0007Handler,
};
