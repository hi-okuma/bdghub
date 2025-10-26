const {logger} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {db} = require("../../config/firebase");
const {region} = require("../../config/environment");

// 設定を外部化
const CONFIG = {
  RETENTION_HOURS: 24, // 保持時間（時間）
  BATCH_SIZE: 100, // Firestoreクエリのバッチサイズ（ページネーション用）
  FIRESTORE_BATCH_LIMIT: 500, // Firestoreのバッチ書き込み上限（技術的制約）
  ALERT_THRESHOLD: 1000, // 異常検知用の警告閾値（この件数以上削除時に警告）
};

/**
 * 非アクティブな部屋の定期クリーンアップ関数
 * 毎日午前4時(JST)に実行され、以下の条件に一致する部屋を削除します：
 * 1. status が "closed" の部屋
 * 2. updatedAt が24時間以上更新されていない部屋
 */
exports.cleanupInactiveRooms = onSchedule({
  schedule: "55 11 * * *", // 毎日午前4時(JST)に実行
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

    // 2. updatedAt が24時間以上更新されていない部屋を削除
    const inactiveResult = await deleteInactiveRooms(cutoffDate);
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
 * status が "closed" の部屋を削除（ページネーションで全件処理）
 * @return {Object} 処理結果
 */
async function deleteClosedRooms() {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  const deletionErrors = [];

  try {
    const roomsRef = db.collection("rooms");
    let hasMore = true;
    let lastDoc = null;

    // ページネーションで全件処理
    while (hasMore) {
      let query = roomsRef
          .where("status", "==", "closed")
          .limit(CONFIG.BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      processedCount += snapshot.size;
      lastDoc = snapshot.docs[snapshot.docs.length - 1];

      // バッチ削除処理
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        batchCount++;

        // Firestoreのバッチ書き込み上限は500件
        if (batchCount >= CONFIG.FIRESTORE_BATCH_LIMIT) {
          await batch.commit();
          deletedCount += batchCount;
          logger.info(`closed部屋を${batchCount}件削除しました`);
          batch = db.batch();
          batchCount = 0;
        }
      }

      // 残りのバッチをコミット
      if (batchCount > 0) {
        await batch.commit();
        deletedCount += batchCount;
        logger.info(`closed部屋を${batchCount}件削除しました`);
      }

      // 次のページがあるかチェック
      if (snapshot.size < CONFIG.BATCH_SIZE) {
        hasMore = false;
      }
    }

    logger.info(`closed状態の部屋の削除完了: 合計${deletedCount}件`);
  } catch (error) {
    logger.error("closed部屋の削除エラー", {
      error: error.message,
      errorCode: error.code,
      errorStack: error.stack,
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
 * updatedAt が指定時間以上更新されていない部屋を削除（ページネーションで全件処理）
 * @param {Date} cutoffDate - 削除対象の基準日時
 * @return {Object} 処理結果
 */
async function deleteInactiveRooms(cutoffDate) {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  const deletionErrors = [];

  try {
    const roomsRef = db.collection("rooms");
    let hasMore = true;
    let lastDoc = null;

    // ページネーションで全件処理
    while (hasMore) {
      // Firestoreの制限: 複合インデックスを避けるため、statusフィルタはアプリ側で実施
      let query = roomsRef
          .where("updatedAt", "<", cutoffDate)
          .limit(CONFIG.BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      processedCount += snapshot.size;
      lastDoc = snapshot.docs[snapshot.docs.length - 1];

      // バッチ削除処理（closedステータスはスキップ）
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        const roomData = doc.data();

        // closedステータスは既に削除済みなのでスキップ
        if (roomData.status === "closed") {
          continue;
        }

        batch.delete(doc.ref);
        batchCount++;

        // Firestoreのバッチ書き込み上限は500件
        if (batchCount >= CONFIG.FIRESTORE_BATCH_LIMIT) {
          await batch.commit();
          deletedCount += batchCount;
          logger.info(`非アクティブ部屋を${batchCount}件削除しました`);
          batch = db.batch();
          batchCount = 0;
        }
      }

      // 残りのバッチをコミット
      if (batchCount > 0) {
        await batch.commit();
        deletedCount += batchCount;
        logger.info(`非アクティブ部屋を${batchCount}件削除しました`);
      }

      // 次のページがあるかチェック
      if (snapshot.size < CONFIG.BATCH_SIZE) {
        hasMore = false;
      }
    }

    logger.info(`非アクティブな部屋の削除完了: 合計${deletedCount}件`, {
      cutoffDate: cutoffDate.toISOString(),
    });
  } catch (error) {
    logger.error("非アクティブ部屋の削除エラー", {
      error: error.message,
      errorCode: error.code,
      errorStack: error.stack,
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

  // 異常に多くの部屋が削除された場合に警告（バグの可能性）
  if (deletedCount >= CONFIG.ALERT_THRESHOLD) {
    logger.warn(`削除数が異常に多いです（バグの可能性を確認してください）`, {
      deletedCount,
      processedCount,
      threshold: CONFIG.ALERT_THRESHOLD,
    });
  }

  // エラー率が高い場合に警告
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

  // 処理件数が多い場合は情報ログ（異常ではないが記録のため）
  if (deletedCount > 0) {
    logger.info(`クリーンアップ統計`, {
      processedCount,
      deletedCount,
      deletionRate: processedCount > 0 ? Math.round((deletedCount / processedCount) * 100) : 0,
    });
  }
}
