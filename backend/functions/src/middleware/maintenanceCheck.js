const {getMaintenanceStatus} = require("../utils/serviceConfig");

/**
 * メンテナンス状態を確認するミドルウェア（onCall用）
 * @param {object} request - onCallのリクエストオブジェクト
 * @return {Promise<void>} メンテナンス中の場合は例外を投げる
 */
async function checkMaintenanceForCall(request) {
  const maintenanceStatus = await getMaintenanceStatus();

  if (maintenanceStatus && maintenanceStatus.isMaintenance === true) {
    const message = maintenanceStatus.maintenanceMessage || "現在メンテナンス中です。しばらくお待ちください。";
    throw new Error(message);
  }
}

// 既存のonRequest用のメンテナンスチェック（互換性のため残す）
const {sendError} = require("../utils/responseHandler");

/**
 * メンテナンス状態を確認するミドルウェア（onRequest用）
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 * @return {Promise<boolean>} メンテナンス中の場合はtrue、それ以外はfalse
 */
async function checkMaintenance(req, res) {
  const maintenanceStatus = await getMaintenanceStatus();

  if (maintenanceStatus && maintenanceStatus.isMaintenance === true) {
    const message = maintenanceStatus.maintenanceMessage || "現在メンテナンス中です。しばらくお待ちください。";
    sendError(res, "Maintenance", message, 503);
    return true;
  }

  return false;
}

module.exports = {
  checkMaintenance,
  checkMaintenanceForCall,
};
