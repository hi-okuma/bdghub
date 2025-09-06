const {logger} = require("firebase-functions");
const {getAppCheck} = require("firebase-admin/app-check");
const {sendError} = require("../utils/responseHandler");

/**
 * App Checkトークンを検証するミドルウェア
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 * @return {Promise<boolean>} 検証に失敗した場合はtrue、成功した場合はfalse
 */
async function verifyAppCheckToken(req, res) {
  const appCheckToken = req.header("X-Firebase-AppCheck");

  if (!appCheckToken) {
    logger.warn("App Check token missing", {
      path: req.path,
      method: req.method,
      headers: Object.keys(req.headers),
    });
    sendError(
        res,
        "AppCheckTokenMissing",
        "認証に失敗しました。一度ページを閉じてください。",
        401,
    );
    return true;
  }

  try {
    await getAppCheck().verifyToken(appCheckToken);
    logger.info("App Check token verified successfully");
    return false;
  } catch (error) {
    logger.warn("App Check token verification failed", {
      error: error.message,
      path: req.path,
      method: req.method,
    });

    sendError(
        res,
        "AppCheckTokenInvalid",
        "認証に失敗しました。一度ページを閉じてください。",
        401,
    );
    return true;
  }
}

module.exports = {
  verifyAppCheckToken,
};
