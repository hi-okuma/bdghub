/**
 * ゲーム0007（サンタ苦労ス）のアセットデータ（お題・おじさんカード）を追加するスクリプト
 *
 * 使い方:
 *   node scripts/addAssets0007.js dev assets0007.json   # 開発環境
 *   node scripts/addAssets0007.js stg assets0007.json   # 検証環境
 *   node scripts/addAssets0007.js prd assets0007.json   # 商用環境
 *
 * JSONファイルのフォーマット:
 *   {
 *     "topics": [
 *       "ランニングシューズ",
 *       "プリン",
 *       ...
 *     ],
 *     "roleCards": [
 *       "https://firebasestorage.googleapis.com/.../mamemura.png",
 *       "https://firebasestorage.googleapis.com/.../yansu.png",
 *       ...
 *     ]
 *   }
 *
 * Firestoreの書き込み先:
 *   - games/0007/assets/topics:    { topics: ["...", ...] }
 *   - games/0007/assets/roleCards: { "0001": { url: "..." }, "0002": { url: "..." }, ... }
 */

const fs = require("fs");
const path = require("path");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const PROJECT_MAP = {
  dev: "bdghub-dev",
  stg: "bdghub-stg",
  prd: "bdghub-prd",
};

const GAME_ID = "0007";

async function main() {
  const env = process.argv[2];
  const jsonPath = process.argv[3];

  if (!env || !PROJECT_MAP[env] || !jsonPath) {
    console.error("使い方: node scripts/addAssets0007.js <dev|stg|prd> <assets.json>");
    process.exit(1);
  }

  const projectId = PROJECT_MAP[env];
  console.log(`環境: ${env} (${projectId})`);

  // JSONファイル読み込み
  const fullPath = path.resolve(jsonPath);
  if (!fs.existsSync(fullPath)) {
    console.error(`ファイルが見つかりません: ${fullPath}`);
    process.exit(1);
  }

  const assets = JSON.parse(fs.readFileSync(fullPath, "utf-8"));

  // バリデーション
  if (!assets || typeof assets !== "object" || Array.isArray(assets)) {
    console.error("JSONファイルはオブジェクトである必要があります（topics と roleCards をキーに持つ）");
    process.exit(1);
  }

  const topics = assets.topics;
  const roleCards = assets.roleCards;

  if (!Array.isArray(topics) || topics.length === 0) {
    console.error("topics は空でない文字列配列である必要があります");
    process.exit(1);
  }
  for (let i = 0; i < topics.length; i++) {
    if (typeof topics[i] !== "string" || !topics[i].trim()) {
      console.error(`topics[${i}] が不正です（非空文字列が必要）`);
      process.exit(1);
    }
  }

  if (!Array.isArray(roleCards) || roleCards.length === 0) {
    console.error("roleCards は空でない文字列配列（URL）である必要があります");
    process.exit(1);
  }
  for (let i = 0; i < roleCards.length; i++) {
    if (typeof roleCards[i] !== "string" || !/^https?:\/\//.test(roleCards[i])) {
      console.error(`roleCards[${i}] が不正です（http(s) URL が必要）`);
      process.exit(1);
    }
  }

  console.log(`お題数: ${topics.length}件`);
  console.log(`おじさんカード数: ${roleCards.length}枚`);

  initializeApp({projectId});
  const db = getFirestore();

  const topicsRef = db.collection("games").doc(GAME_ID)
      .collection("assets").doc("topics");
  const roleCardsRef = db.collection("games").doc(GAME_ID)
      .collection("assets").doc("roleCards");

  // 既存チェック（どちらかが存在したら停止）
  const [topicsExisting, roleCardsExisting] = await Promise.all([
    topicsRef.get(),
    roleCardsRef.get(),
  ]);

  if (topicsExisting.exists) {
    console.error(`games/${GAME_ID}/assets/topics は既に存在します。上書きする場合は手動で削除してください。`);
    process.exit(1);
  }
  if (roleCardsExisting.exists) {
    console.error(`games/${GAME_ID}/assets/roleCards は既に存在します。上書きする場合は手動で削除してください。`);
    process.exit(1);
  }

  // おじさんカードデータをマップ形式に変換（cardId: { url }）
  const roleCardsMap = {};
  roleCards.forEach((url, index) => {
    const cardId = String(index + 1).padStart(4, "0"); // "0001", "0002", ...
    roleCardsMap[cardId] = {url};
  });

  const batch = db.batch();
  batch.set(topicsRef, {topics});
  batch.set(roleCardsRef, roleCardsMap);
  await batch.commit();

  console.log(`games/${GAME_ID}/assets/topics に ${topics.length}件のお題を追加しました`);
  console.log(`games/${GAME_ID}/assets/roleCards に ${roleCards.length}枚のおじさんカードを追加しました`);
  console.log("完了！");
}

main().catch((err) => {
  console.error("エラー:", err.message);
  process.exit(1);
});
