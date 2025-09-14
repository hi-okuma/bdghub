const {getMaintenanceStatus} = require("../utils/serviceConfig");
const {throwMaintenanceError} = require("../utils/errorHandler");

/**
 * メンテナンス状態を確認するミドルウェア
 * @param {object} request - リクエストオブジェクト
 * @return {Promise<void>} メンテナンス中の場合は例外を投げる
 */
async function checkMaintenance(request) {
  const maintenanceStatus = await getMaintenanceStatus();

  if (maintenanceStatus && maintenanceStatus.isMaintenance === true) {
    const message = maintenanceStatus.maintenanceMessage || "現在メンテナンス中です。しばらくお待ちください。";
    throwMaintenanceError(message);
  }
}

module.exports = {
  checkMaintenance,
};
