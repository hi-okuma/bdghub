const {logger} = require("firebase-functions");

/**
 * 成功レスポンスを送信する
 * @param {object} res - レスポンスオブジェクト
 * @param {object} data - レスポンスデータ
 * @param {string} [message] - 成功メッセージ
 * @param {number} [status=200] - HTTPステータスコード
 */
function sendSuccess(res, data = {}, message = "", status = 200) {
  res.status(status).send({
    success: true,
    message,
    ...data,
  });
}

/**
 * エラーレスポンスを送信する
 * @param {object} res - レスポンスオブジェクト
 * @param {string} error - エラーコード
 * @param {string} message - エラーメッセージ
 * @param {number} status - HTTPステータスコード
 * @param {object} [logData={}] - ログに記録する追加データ
 */
function sendError(res, error, message, status, logData = {}) {
  if (status >= 500) {
    logger.error(`サーバーエラー: ${error}`, {
      error,
      message,
      ...logData,
    });
  } else {
    logger.warn(`クライアントエラー: ${error}`, {
      error,
      message,
      ...logData,
    });
  }

  res.status(status).send({
    success: false,
    error,
    message,
  });
}

module.exports = {
  sendSuccess,
  sendError,
};
