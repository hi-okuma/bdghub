const {logger} = require("firebase-functions");
const {db} = require("../../config/firebase");
const {FieldValue} = require("firebase-admin/firestore");
const {DEFAULT_MAX_ROOM_PLAYERS} = require("../../config/environment");
const {sanitizeUserInput, sanitizeAlphanumeric} = require("../../utils/sanitization");
const {
  throwValidationError,
  throwNotFoundError,
  throwRoomStatusError,
  throwStructuredError,
} = require("../../utils/errorHandler");

/**
 * 部屋参加リクエストを処理するハンドラー
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<object>} レスポンスデータ
 */
async function joinRoomHandler(request) {
  const {nickname, uid, roomId} = request.data;

  if (!nickname || !uid || !roomId) {
    throwValidationError("部屋に参加できませんでした。");
  }

  try {
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
      throwNotFoundError("部屋", sanitizedRoomId);
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
      throwRoomStatusError(roomData.status);
    }

    if (isNicknameDuplicate(roomData, sanitizedNickname)) {
      throwStructuredError("DuplicateNickname", "このニックネームは既に使われています。");
    }

    if (currentPlayerCount >= maxRoomPlayers) {
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
      throwRoomStatusError("full");
    }

    const willBeFull = currentPlayerCount + 1 >= maxRoomPlayers;
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
    if (error.code && error.details) {
      throw error;
    }

    if (error.message.includes("ニックネーム") || error.message.includes("部屋コード")) {
      throwValidationError(error.message);
    }

    logger.error("部屋参加エラー", {
      error: error.message,
      stack: error.stack,
      roomId,
      nickname,
      uid,
    });
    throwStructuredError("Internal", "サーバーエラーが発生しました。");
  }
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
