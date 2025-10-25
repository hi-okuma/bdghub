const {logger} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getAuth} = require("firebase-admin/auth");
const {region} = require("../../config/environment");

// 設定を外部化
const CONFIG = {
  RETENTION_DAYS: 2, // 保持日数
  MAX_DELETIONS_PER_RUN: 1000, // 1回の実行での最大削除数
  BATCH_SIZE: 1000, // ユーザー取得時のバッチサイズ（Firebase Admin SDK上限）
  ALERT_THRESHOLD: 0.8, // アラート閾値(最大削除数の80%)
};

/**
 * 匿名ユーザーの定期クリーンアップ関数
 * 毎日午前4時(JST)に実行され、最終ログインから指定日数経った匿名ユーザーを削除します
 */
exports.cleanupAnonymousUsers = onSchedule({
  schedule: "0 4 * * *", // 毎日午前4時(JST)に実行
  timeZone: "Asia/Tokyo",
  region: region,
  memory: "256MiB",
  timeoutSeconds: 300,
}, async (event) => {
  try {
    logger.info("匿名ユーザークリーンアップ開始", {config: CONFIG});
    const auth = getAuth();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - CONFIG.RETENTION_DAYS);
    const result = await processAnonymousUserCleanup(auth, cutoffDate);
    await checkAndAlert(result);
    logger.info("匿名ユーザークリーンアップ完了", result);

    return {
      success: true,
      ...result,
      cutoffDate: cutoffDate.toISOString(),
    };
  } catch (error) {
    logger.error("匿名ユーザークリーンアップエラー", {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
});

/**
 * 匿名ユーザークリーンアップの処理を実行
 * @param {Auth} auth - Firebase Auth インスタンス
 * @param {Date} cutoffDate - 削除対象の基準日時
 * @return {Object} 処理結果
 */
async function processAnonymousUserCleanup(auth, cutoffDate) {
  let deletedCount = 0;
  let processedCount = 0;
  let errorCount = 0;
  let nextPageToken;
  const deletionErrors = [];

  do {
    try {
      const listUsersResult = await auth.listUsers(CONFIG.BATCH_SIZE, nextPageToken);
      const usersToDelete = [];

      for (const userRecord of listUsersResult.users) {
        processedCount++;

        if (!isAnonymousUser(userRecord)) {
          continue;
        }

        const lastLoginDate = getLastLoginDate(userRecord);
        if (!lastLoginDate || lastLoginDate > cutoffDate) {
          continue;
        }

        usersToDelete.push({
          uid: userRecord.uid,
          creationTime: userRecord.metadata.creationTime,
          lastSignInTime: userRecord.metadata.lastSignInTime,
        });

        if (deletedCount + usersToDelete.length >= CONFIG.MAX_DELETIONS_PER_RUN) {
          logger.info("1回の実行での削除上限に達しました", {
            currentDeleted: deletedCount,
            plannedBatch: usersToDelete.length,
            limit: CONFIG.MAX_DELETIONS_PER_RUN,
          });
          break;
        }
      }

      if (usersToDelete.length > 0) {
        const deleteResult = await deleteUsersInBatch(
            auth,
            usersToDelete.map((u) => u.uid),
        );

        if (deleteResult.success) {
          const successCount = deleteResult.successCount || usersToDelete.length;
          const failureCount = deleteResult.failureCount || 0;

          deletedCount += successCount;
          errorCount += failureCount;

          if (failureCount > 0) {
            logger.info(`一括削除部分完了: 成功${successCount}人, 失敗${failureCount}人`);
          } else {
            logger.info(`一括削除完了: ${successCount}人`);
          }
        } else {
          errorCount += usersToDelete.length;
          deletionErrors.push(...usersToDelete.map((u) => u.uid));
          logger.error(`一括削除失敗: ${usersToDelete.length}人`, {
            error: deleteResult.error,
          });
        }
      }

      nextPageToken = listUsersResult.pageToken;

      if (deletedCount >= CONFIG.MAX_DELETIONS_PER_RUN) {
        break;
      }
    } catch (error) {
      logger.error("バッチ処理エラー", {
        error: error.message,
        processedCount,
        deletedCount,
      });
      errorCount++;
    }
  } while (nextPageToken);

  return {
    processedCount,
    deletedCount,
    errorCount,
    deletionErrors: deletionErrors.length > 0 ? deletionErrors : undefined,
  };
}

/**
 * ユーザーが匿名ユーザーかどうかを判定
 * @param {UserRecord} userRecord - ユーザーレコード
 * @return {boolean} 匿名ユーザーの場合true
 */
function isAnonymousUser(userRecord) {
  return (
    userRecord.providerData.length === 0 &&
    !userRecord.email &&
    !userRecord.phoneNumber &&
    !(userRecord.customClaims && userRecord.customClaims.isRegisteredUser)
  );
}

/**
 * ユーザーの最終ログイン日時を取得
 * @param {UserRecord} userRecord - ユーザーレコード
 * @return {Date|null} 最終ログイン日時、または作成日時
 */
function getLastLoginDate(userRecord) {
  if (userRecord.metadata.lastSignInTime) {
    return new Date(userRecord.metadata.lastSignInTime);
  }

  if (userRecord.metadata.creationTime) {
    return new Date(userRecord.metadata.creationTime);
  }

  return null;
}

/**
 * ユーザーを一括削除
 * @param {Auth} auth - Firebase Auth インスタンス
 * @param {string[]} uids - 削除するユーザーのUID配列（最大1000件）
 * @return {Object} 削除結果 {success: boolean, successCount?: number, failureCount?: number, error?: string}
 */
async function deleteUsersInBatch(auth, uids) {
  try {
    const deleteUsersResult = await auth.deleteUsers(uids);

    if (deleteUsersResult.failureCount > 0) {
      logger.warn(`一部削除失敗`, {
        successCount: deleteUsersResult.successCount,
        failureCount: deleteUsersResult.failureCount,
        errors: deleteUsersResult.errors && deleteUsersResult.errors.map((error) => ({
          uid: error.index,
          error: error.error.message,
        })),
      });
    }

    return {
      success: true,
      successCount: deleteUsersResult.successCount,
      failureCount: deleteUsersResult.failureCount,
    };
  } catch (error) {
    logger.error(`一括削除エラー`, {
      error: error.message,
      uidsCount: uids.length,
    });

    return {
      success: false,
      error: error.message,
    };
  }
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

  if (processedCount > CONFIG.BATCH_SIZE * 5) { // 5000人以上処理した場合
    logger.warn(`処理対象ユーザー数が多いです`, {
      processedCount,
      deletedCount,
      anonymousUserRatio: deletedCount > 0 ? Math.round((deletedCount / processedCount) * 100) : 0,
    });
  }
}
