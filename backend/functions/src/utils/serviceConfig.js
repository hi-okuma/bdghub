const {db} = require("../config/firebase");
const {logger} = require("firebase-functions");

/**
 * サービス設定情報を取得する
 * @return {Promise<object|null>} サービス設定情報、取得失敗時はnull
 */
async function getServiceConfig() {
  try {
    const configDoc = await db.collection("serviceConfig").doc("global").get();

    if (!configDoc.exists) {
      logger.warn("serviceConfig/global document does not exist");
      return null;
    }

    return configDoc.data();
  } catch (error) {
    logger.error("Error fetching service config", error);
    return null;
  }
}

/**
 * メンテナンス情報を取得する
 * @return {Promise<{isMaintenance: boolean, maintenanceMessage: string}|null>} メンテナンス情報、取得失敗時はnull
 */
async function getMaintenanceStatus() {
  try {
    const config = await getServiceConfig();
    if (!config || !config.maintenance) {
      return {isMaintenance: false, maintenanceMessage: ""};
    }

    return config.maintenance;
  } catch (error) {
    logger.error("Error fetching maintenance status", error);
    return {isMaintenance: false, maintenanceMessage: ""};
  }
}

module.exports = {
  getServiceConfig,
  getMaintenanceStatus,
};
