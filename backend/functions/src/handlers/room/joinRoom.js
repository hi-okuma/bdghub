const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../config/environment");
const {sanitizeUserInput, sanitizeAlphanumeric} = require("../../utils/sanitization");

/**
 * 部屋参加リクエストを処理するハンドラー（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function joinRoomHandler(request) {
  const {nickname, uid, roomId} = request.data;

  if (!nickname || !uid || !roomId) {
    throw new Error("部屋に参加できませんでした。必要な情報が不足しています。");
  }

  try {
    // 入力値のサニタイゼーション
    const sanitizedNickname = sanitizeUserInput(nickname, {
      maxLength: 10,
      forbiddenChars: ["/", "."],
      fieldName: "ニックネーム",
    });

    const sanitizedRoomId = sanitizeAlphanumeric(roomId, {
      maxLength: 16,
      fieldName: "部屋コード",
    });

    let maxRoomPlayers = DEFAULT_MAX_ROOM_PLAYERS;
    try {
      const serviceConfigDoc = await db.collection("serviceConfig").doc("global").get();
      if (serviceConfigDoc.exists) {
        maxRoomPlayers = serviceConfigDoc.data().maxPlayersPerRoom || DEFAULT_MAX_ROOM_PLAYERS;
      }
    } catch (configError) {
      logger.warn("serviceConfig取得エラー、デフォルト値を使用します", {error: configError.message});
    }

    const roomDoc = await db.collection("rooms").doc(sanitizedRoomId).get();
    if (!roomDoc.exists) {
      throw new Error("指定された部屋が見つかりません。");
    }

    const roomData = roomDoc.data();
    const roomRef = db.collection("rooms").doc(sanitizedRoomId);

    const currentPlayerCount = Object.keys(roomData.players).length;

    if (roomData.status === "full" && currentPlayerCount < maxRoomPlayers) {
      logger.info(`部屋ID=${sanitizedRoomId} はfullですが、最大人数が引き上げられたためacceptingに戻します。`);
      await roomRef.update({
        status: "accepting",
        updatedAt: FieldValue.serverTimestamp(),
      });
      roomData.status = "accepting";
    }

    if (roomData.status !== "accepting") {
      handleInvalidRoomStatus(roomData.status);
    }

    if (isNicknameDuplicate(roomData, sanitizedNickname)) {
      throw new Error("このニックネームは既に使われています。");
    }

    if (roomData.players.length >= maxRoomPlayers) {
      if (roomData.status === "accepting") {
        try {
          await roomRef.update({
            status: "full",
            updatedAt: FieldValue.serverTimestamp(),
          });
          logger.info(`部屋が満員になったためステータスを更新: roomId=${sanitizedRoomId}`);
        } catch (updateError) {
          logger.error(`満員時のステータス更新に失敗: roomId=${sanitizedRoomId}`, {error: updateError});
        }
      }
      throw new Error("部屋が満員です。");
    }

    const willBeFull = roomData.players.length + 1 >= maxRoomPlayers;
    await addPlayerToRoom(sanitizedRoomId, sanitizedNickname, uid, willBeFull);

    logger.info(`プレイヤー参加成功: ${sanitizedNickname}(${uid}) to room ${sanitizedRoomId}`, {
      nickname: sanitizedNickname,
      uid,
      willBeFull,
    });

    return {
      roomId: sanitizedRoomId,
      nickname: sanitizedNickname,
    };
  } catch (error) {
    logger.error("部屋参加エラー", {
      error: error.message,
      roomId,
      nickname,
      uid,
    });
    throw error;
  }
}

/**
 * 無効な部屋ステータスに対するエラーを投げる
 * @param {string} status - 部屋のステータス
 */
function handleInvalidRoomStatus(status) {
  const statusErrors = {
    inProgress: "この部屋はすでにゲームが開始されています。",
    closed: "この部屋はすでに閉じられています。",
    full: "部屋が満員です。",
    default: "この部屋は現在参加できません。",
  };

  const errorMessage = statusErrors[status] || statusErrors.default;
  throw new Error(errorMessage);
}

/**
 * ニックネームが部屋内で重複しているかをチェックする
 * @param {object} roomData - 部屋データ
 * @param {string} nickname - チェックするニックネーム
 * @return {boolean} 重複している場合はtrue、そうでない場合はfalse
 */
function isNicknameDuplicate(roomData, nickname) {
  return Object.values(roomData.players).some((player) => player.nickname === nickname);
}

/**
 * プレイヤーを部屋に追加する
 * @param {string} roomId - 部屋ID
 * @param {string} nickname - ニックネーム（サニタイズ済み）
 * @param {string} uid - プレイヤーのUID
 * @param {boolean} willBeFull - 部屋が満員になるかどうか
 * @return {Promise} 更新処理のPromise
 */
async function addPlayerToRoom(roomId, nickname, uid, willBeFull) {
  return db.collection("rooms").doc(roomId).update({
    [`players.${uid}`]: {nickname: nickname},
    status: willBeFull ? "full" : "accepting",
    updatedAt: FieldValue.serverTimestamp(),
  });
}

module.exports = {
  joinRoomHandler,
};
