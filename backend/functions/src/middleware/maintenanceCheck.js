const {getMaintenanceStatus} = require("../utils/serviceConfig");
const {sendError} = require("../utils/responseHandler");

/**
 * メンテナンス状態を確認するミドルウェア
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
};
