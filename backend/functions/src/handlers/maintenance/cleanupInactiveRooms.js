const {logger} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {db} = require("../../config/firebase");
const {region} = require("../../config/environment");

// 設定を外部化
const CONFIG = {
  RETENTION_HOURS: 24, // 保持時間（時間）
  MAX_DELETIONS_PER_RUN: 500, // 1回の実行での最大削除数
  BATCH_SIZE: 100, // Firestoreクエリのバッチサイズ
  ALERT_THRESHOLD: 0.8, // アラート閾値(最大削除数の80%)
};

/**
 * 非アクティブな部屋の定期クリーンアップ関数
 * 毎日午前4時(JST)に実行され、以下の条件に一致する部屋を削除します：
 * 1. status が "closed" の部屋
 * 2. updatedAt が24時間以上更新されていない部屋
 */
exports.cleanupInactiveRooms = onSchedule({
  schedule: "0 4 * * *", // 毎日午前4時(JST)に実行
  timeZone: "Asia/Tokyo",
  region: region,
  memory: "256MiB",
  timeoutSeconds: 300,
}, async (event) => {
  try {
    logger.info("非アクティブな部屋のクリーンアップ開始", {config: CONFIG});
    const cutoffDate = new Date();
    cutoffDate.setHours(cutoffDate.getHours() - CONFIG.RETENTION_HOURS);

    const result = await processInactiveRoomCleanup(cutoffDate);
    await checkAndAlert(result);

    logger.info("非アクティブな部屋のクリーンアップ完了", result);

    return {
      success: true,
      ...result,
      cutoffDate: cutoffDate.toISOString(),
    };
  } catch (error) {
    logger.error("非アクティブな部屋のクリーンアップエラー", {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
});

/**
 * 非アクティブな部屋のクリーンアップ処理を実行
 * @param {Date} cutoffDate - 削除対象の基準日時
 * @return {Object} 処理結果
 */
async function processInactiveRoomCleanup(cutoffDate) {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  const deletionErrors = [];

  try {
    // 1. status が "closed" の部屋を削除
    const closedResult = await deleteClosedRooms();
    deletedCount += closedResult.deletedCount;
    processedCount += closedResult.processedCount;
    errorCount += closedResult.errorCount;
    deletionErrors.push(...closedResult.deletionErrors);

    // 削除上限チェック
    if (deletedCount >= CONFIG.MAX_DELETIONS_PER_RUN) {
      logger.info("削除上限に達したため、非アクティブな部屋の削除をスキップします", {
        deletedCount,
        limit: CONFIG.MAX_DELETIONS_PER_RUN,
      });
      return {
        processedCount,
        deletedCount,
        errorCount,
        deletionErrors: deletionErrors.length > 0 ? deletionErrors : undefined,
      };
    }

    // 2. updatedAt が24時間以上更新されていない部屋を削除
    const inactiveResult = await deleteInactiveRooms(
        cutoffDate,
        CONFIG.MAX_DELETIONS_PER_RUN - deletedCount,
    );
    deletedCount += inactiveResult.deletedCount;
    processedCount += inactiveResult.processedCount;
    errorCount += inactiveResult.errorCount;
    deletionErrors.push(...inactiveResult.deletionErrors);
  } catch (error) {
    logger.error("クリーンアップ処理エラー", {
      error: error.message,
      processedCount,
      deletedCount,
    });
    errorCount++;
  }

  return {
    processedCount,
    deletedCount,
    errorCount,
    deletionErrors: deletionErrors.length > 0 ? deletionErrors : undefined,
  };
}

/**
 * status が "closed" の部屋を削除
 * @return {Object} 処理結果
 */
async function deleteClosedRooms() {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  const deletionErrors = [];

  try {
    const roomsRef = db.collection("rooms");
    const closedRoomsQuery = roomsRef
        .where("status", "==", "closed")
        .limit(CONFIG.BATCH_SIZE);

    const snapshot = await closedRoomsQuery.get();
    processedCount = snapshot.size;

    logger.info(`closed状態の部屋を${snapshot.size}件検出しました`);

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
      if (deletedCount + batchCount >= CONFIG.MAX_DELETIONS_PER_RUN) {
        logger.info("削除上限に達しました（closed部屋）", {
          currentDeleted: deletedCount,
          plannedBatch: batchCount,
          limit: CONFIG.MAX_DELETIONS_PER_RUN,
        });
        break;
      }

      batch.delete(doc.ref);
      batchCount++;

      // Firestoreのバッチ書き込み上限は500件
      if (batchCount >= 500) {
        await batch.commit();
        deletedCount += batchCount;
        logger.info(`closed部屋を${batchCount}件削除しました`);
        batchCount = 0;
      }
    }

    // 残りのバッチをコミット
    if (batchCount > 0) {
      await batch.commit();
      deletedCount += batchCount;
      logger.info(`closed部屋を${batchCount}件削除しました`);
    }
  } catch (error) {
    logger.error("closed部屋の削除エラー", {
      error: error.message,
      deletedCount,
      processedCount,
    });
    errorCount++;
    deletionErrors.push(`closed部屋削除エラー: ${error.message}`);
  }

  return {
    processedCount,
    deletedCount,
    errorCount,
    deletionErrors,
  };
}

/**
 * updatedAt が指定時間以上更新されていない部屋を削除
 * @param {Date} cutoffDate - 削除対象の基準日時
 * @param {number} maxDeletions - 最大削除数
 * @return {Object} 処理結果
 */
async function deleteInactiveRooms(cutoffDate, maxDeletions) {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  const deletionErrors = [];

  try {
    const roomsRef = db.collection("rooms");
    const inactiveRoomsQuery = roomsRef
        .where("updatedAt", "<", cutoffDate)
        .where("status", "!=", "closed") // closedは既に削除済み
        .limit(Math.min(CONFIG.BATCH_SIZE, maxDeletions));

    const snapshot = await inactiveRoomsQuery.get();
    processedCount = snapshot.size;

    logger.info(`非アクティブな部屋を${snapshot.size}件検出しました`, {
      cutoffDate: cutoffDate.toISOString(),
    });

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
      if (deletedCount + batchCount >= maxDeletions) {
        logger.info("削除上限に達しました（非アクティブ部屋）", {
          currentDeleted: deletedCount,
          plannedBatch: batchCount,
          limit: maxDeletions,
        });
        break;
      }

      batch.delete(doc.ref);
      batchCount++;

      // Firestoreのバッチ書き込み上限は500件
      if (batchCount >= 500) {
        await batch.commit();
        deletedCount += batchCount;
        logger.info(`非アクティブ部屋を${batchCount}件削除しました`);
        batchCount = 0;
      }
    }

    // 残りのバッチをコミット
    if (batchCount > 0) {
      await batch.commit();
      deletedCount += batchCount;
      logger.info(`非アクティブ部屋を${batchCount}件削除しました`);
    }
  } catch (error) {
    logger.error("非アクティブ部屋の削除エラー", {
      error: error.message,
      deletedCount,
      processedCount,
    });
    errorCount++;
    deletionErrors.push(`非アクティブ部屋削除エラー: ${error.message}`);
  }

  return {
    processedCount,
    deletedCount,
    errorCount,
    deletionErrors,
  };
}

/**
 * 監視とアラートのチェック
 * @param {Object} result - 処理結果
 */
async function checkAndAlert(result) {
  const {deletedCount, errorCount, processedCount} = result;

  if (deletedCount > CONFIG.MAX_DELETIONS_PER_RUN * CONFIG.ALERT_THRESHOLD) {
    logger.warn(`削除数が上限に近づいています`, {
      deletedCount,
      threshold: Math.floor(CONFIG.MAX_DELETIONS_PER_RUN * CONFIG.ALERT_THRESHOLD),
      maxDeletions: CONFIG.MAX_DELETIONS_PER_RUN,
    });
  }

  if (errorCount > 0 && deletedCount > 0) {
    const errorRate = errorCount / (deletedCount + errorCount);
    if (errorRate > 0.1) { // 10%以上のエラー率
      logger.warn(`削除エラー率が高いです`, {
        errorCount,
        deletedCount,
        errorRate: Math.round(errorRate * 100),
        processedCount,
      });
    }
  }

  if (processedCount > CONFIG.BATCH_SIZE * 5) { // 500件以上処理した場合
    logger.warn(`処理対象の部屋数が多いです`, {
      processedCount,
      deletedCount,
      inactiveRoomRatio: deletedCount > 0 ? Math.round((deletedCount / processedCount) * 100) : 0,
    });
  }
}
