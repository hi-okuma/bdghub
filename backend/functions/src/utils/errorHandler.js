const {HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");

/**
 * エラーコードマッピング
 */
const ERROR_CODE_MAPPING = {
  // 400系エラー
  "InvalidArgument": "invalid-argument",
  "DuplicateNickname": "already-exists",
  "InvalidGameStatus": "failed-precondition",
  "InvalidRoomStatus": "failed-precondition",
  "InvalidBestHintPlayer": "invalid-argument",
  "BestHintPlayerRequired": "invalid-argument",
  "ParentCannotsubmitHint": "permission-denied",
  "OnlyParentCandetermineAnswer": "permission-denied",
  "PlayerDidNotSubmitHint": "not-found",

  // 403系エラー
  "Unpublished": "permission-denied",
  "NotReleased": "permission-denied",

  // 404系エラー
  "NotFound": "not-found",
  "RoomNotFound": "not-found",
  "GameNotFound": "not-found",
  "PlayerNotFound": "not-found",

  // 409系エラー
  "RoomFull": "resource-exhausted",
  "InProgress": "unavailable",
  "AlreadyInProgress": "already-exists",

  // 429系エラー
  "ResourceExhausted": "resource-exhausted",

  // 500系エラー
  "Internal": "internal",
  "InitializerNotFound": "internal",

  // 503系エラー
  "Maintenance": "unavailable",
  "Unavailable": "unavailable",
  "Closed": "unavailable",
  "RoomClosed": "unavailable",
};

/**
 * ドキュメント仕様に対応したHTTPステータスコードマッピング
 * クライアント側での参考用（実際のHTTPステータスはFirebaseが管理）
 */
const HTTP_STATUS_MAPPING = {
  "InvalidArgument": 400,
  "DuplicateNickname": 400,
  "InvalidGameStatus": 400,
  "InvalidRoomStatus": 400,
  "InvalidBestHintPlayer": 400,
  "BestHintPlayerRequired": 400,
  "ParentCannotsubmitHint": 400,
  "OnlyParentCandetermineAnswer": 400,
  "PlayerDidNotSubmitHint": 400,
  "Unpublished": 403,
  "NotReleased": 403,
  "NotFound": 404,
  "RoomNotFound": 404,
  "GameNotFound": 404,
  "PlayerNotFound": 404,
  "RoomFull": 409,
  "InProgress": 409,
  "AlreadyInProgress": 409,
  "ResourceExhausted": 429,
  "Internal": 500,
  "InitializerNotFound": 500,
  "Maintenance": 503,
  "Unavailable": 503,
  "Closed": 503,
  "RoomClosed": 503,
};

/**
 * 構造化されたエラーを投げるヘルパー関数
 * @param {string} errorCode - ドキュメント仕様のエラーコード
 * @param {string} message - エラーメッセージ
 * @param {object} details - 追加の詳細情報（オプション）
 * @throws {HttpsError} エラー
 */
function throwStructuredError(errorCode, message, details = {}) {
  const firebaseErrorCode = ERROR_CODE_MAPPING[errorCode];
  const httpStatus = HTTP_STATUS_MAPPING[errorCode];

  if (!firebaseErrorCode) {
    logger.error(`未定義のエラーコード: ${errorCode}`);
    throw new HttpsError("internal", "サーバーエラーが発生しました。", {
      code: "Internal",
      httpStatus: 500,
      ...details,
    });
  }

  // サーバーエラー（500番台）の場合はログに記録
  if (httpStatus >= 500) {
    logger.error(`サーバーエラー: ${errorCode}`, {
      errorCode,
      message,
      details,
    });
  } else {
    logger.warn(`クライアントエラー: ${errorCode}`, {
      errorCode,
      message,
      details,
    });
  }

  throw new HttpsError(firebaseErrorCode, message, {
    code: errorCode,
    httpStatus,
    ...details,
  });
}

/**
 * メンテナンス中エラーを投げるヘルパー関数
 * @param {string} customMessage - カスタムメッセージ（オプション）
 */
function throwMaintenanceError(customMessage) {
  const message = customMessage || "現在メンテナンス中です。しばらくお待ちください。";
  throwStructuredError("Maintenance", message);
}

/**
 * バリデーションエラーを投げるヘルパー関数
 * @param {string} message - エラーメッセージ
 * @param {object} details - 追加の詳細情報
 */
function throwValidationError(message, details = {}) {
  throwStructuredError("InvalidArgument", message, details);
}

/**
 * リソースが見つからないエラーを投げるヘルパー関数
 * @param {string} resource - リソース名
 * @param {string} identifier - リソースの識別子
 */
function throwNotFoundError(resource, identifier) {
  const message = `指定された${resource}が見つかりません。`;
  throwStructuredError("NotFound", message, {resource, identifier});
}

/**
 * 権限エラーを投げるヘルパー関数
 * @param {string} message - エラーメッセージ
 */
function throwPermissionError(message) {
  throwStructuredError("PermissionDenied", message);
}

/**
 * ゲーム状態エラーを投げるヘルパー関数
 * @param {string} expectedStatus - 期待される状態
 * @param {string} actualStatus - 実際の状態
 */
function throwGameStatusError(expectedStatus, actualStatus) {
  const message = "ゲームが開始できませんでした。ホストプレイヤーより一度ゲームを終了してください。";
  throwStructuredError("InvalidGameStatus", message, {
    expectedStatus,
    actualStatus,
  });
}

/**
 * 部屋状態エラーを投げるヘルパー関数
 * @param {string} status - 部屋の状態
 */
function throwRoomStatusError(status) {
  const statusMessages = {
    "inProgress": "この部屋はすでにゲームが開始されています。",
    "closed": "この部屋はすでに閉じられています。",
    "full": "部屋が満員です。",
  };

  const message = statusMessages[status] || "この部屋は現在参加できません。";
  const errorCode = status === "full" ? "RoomFull" :
                   status === "inProgress" ? "InProgress" :
                   status === "closed" ? "Closed" : "InvalidRoomStatus";

  throwStructuredError(errorCode, message, {status});
}

module.exports = {
  throwStructuredError,
  throwMaintenanceError,
  throwValidationError,
  throwNotFoundError,
  throwPermissionError,
  throwGameStatusError,
  throwRoomStatusError,
  ERROR_CODE_MAPPING,
  HTTP_STATUS_MAPPING,
};
