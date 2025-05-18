/**
 * 各ゲームの準備完了時の遷移先ステータスマッピング
 */
const READY_TRANSITION_MAP = {
  "0001": "playing", // NGワード
  "0002": "playing", // カタカナ語禁止
  "0003": "playing", // 水平思考
  "0004": "childTurn", // 偏見プロフィール
};

/**
 * ゲームIDに応じた準備完了時の遷移先ステータスを取得する
 * @param {string} gameId - ゲームID
 * @return {string} 遷移先ステータス
 */
function getReadyTransitionStatus(gameId) {
  return READY_TRANSITION_MAP[gameId] || "playing"; // デフォルトはplaying
}

module.exports = {
  getReadyTransitionStatus,
};
