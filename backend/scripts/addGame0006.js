/**
 * ゲーム0006（流行語ゲーム）のgamesドキュメントとassets/configを追加するスクリプト
 *
 * 使い方:
 *   node scripts/addGame0006.js dev   # 開発環境
 *   node scripts/addGame0006.js stg   # 検証環境
 *   node scripts/addGame0006.js prd   # 商用環境
 */

const {initializeApp, cert} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

// 環境→プロジェクトIDのマッピング（.firebaserc と同期）
const PROJECT_MAP = {
  dev: "bdghub-dev",
  stg: "bdghub-stg",
  prd: "bdghub-prd",
};

const GAME_ID = "0006";

// games/0006 ドキュメント
const GAME_DOC = {
  title: "流行語ゲーム",
  isPublished: true,
  minPlayers: 1,
  maxPlayers: 2,
  playCnt: 0,
};

// games/0006/assets/config ドキュメント
// キーはプレイヤー数（文字列）
const CONFIG_DOC = {
  "2": {
    targetScore: 150,
    maxCardsPerPlayer: 5,
    boardSize: 16,
  },
};

async function main() {
  const env = process.argv[2];

  if (!env || !PROJECT_MAP[env]) {
    console.error("使い方: node scripts/addGame0006.js <dev|stg|prd>");
    process.exit(1);
  }

  const projectId = PROJECT_MAP[env];
  console.log(`環境: ${env} (${projectId})`);

  initializeApp({projectId});
  const db = getFirestore();

  const gameRef = db.collection("games").doc(GAME_ID);

  // 既存チェック
  const existing = await gameRef.get();
  if (existing.exists) {
    console.error(`games/${GAME_ID} は既に存在します。上書きする場合は手動で削除してください。`);
    process.exit(1);
  }

  const batch = db.batch();

  // games/0006 ドキュメント
  batch.set(gameRef, GAME_DOC);
  console.log(`  games/${GAME_ID} を追加`);

  // games/0006/assets/config ドキュメント
  const configRef = gameRef.collection("assets").doc("config");
  batch.set(configRef, CONFIG_DOC);
  console.log(`  games/${GAME_ID}/assets/config を追加`);

  await batch.commit();
  console.log("完了！");
}

main().catch((err) => {
  console.error("エラー:", err.message);
  process.exit(1);
});
