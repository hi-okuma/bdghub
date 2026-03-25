/**
 * ゲーム0006（流行語ゲーム）のカードデータを追加するスクリプト
 *
 * 使い方:
 *   node scripts/addCards0006.js dev cards0006.json   # 開発環境
 *   node scripts/addCards0006.js stg cards0006.json   # 検証環境
 *   node scripts/addCards0006.js prd cards0006.json   # 商用環境
 *
 * JSONファイルのフォーマット:
 *   [
 *     { "buzzword": "忖度", "year": 2017 },
 *     { "buzzword": "インスタ映え", "year": 2017 },
 *     ...
 *   ]
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

const GAME_ID = "0006";

async function main() {
  const env = process.argv[2];
  const jsonPath = process.argv[3];

  if (!env || !PROJECT_MAP[env] || !jsonPath) {
    console.error("使い方: node scripts/addCards0006.js <dev|stg|prd> <cards.json>");
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

  const cards = JSON.parse(fs.readFileSync(fullPath, "utf-8"));

  // バリデーション
  if (!Array.isArray(cards) || cards.length === 0) {
    console.error("JSONファイルは空でない配列である必要があります");
    process.exit(1);
  }

  for (let i = 0; i < cards.length; i++) {
    const card = cards[i];
    if (typeof card.buzzword !== "string" || !card.buzzword.trim()) {
      console.error(`カード[${i}]: buzzword が不正です`);
      process.exit(1);
    }
    if (typeof card.year !== "number" || !Number.isInteger(card.year)) {
      console.error(`カード[${i}]: year が不正です（整数が必要）`);
      process.exit(1);
    }
  }

  console.log(`カード数: ${cards.length}枚`);

  initializeApp({projectId});
  const db = getFirestore();

  // カードデータをマップ形式に変換（cardId: { buzzword, year }）
  const cardsMap = {};
  cards.forEach((card, index) => {
    const cardId = String(index + 1).padStart(4, "0"); // "0001", "0002", ...
    cardsMap[cardId] = {
      buzzword: card.buzzword,
      year: card.year,
    };
  });

  const cardsRef = db.collection("games").doc(GAME_ID)
      .collection("assets").doc("cards");

  // 既存チェック
  const existing = await cardsRef.get();
  if (existing.exists) {
    console.error(`games/${GAME_ID}/assets/cards は既に存在します。上書きする場合は手動で削除してください。`);
    process.exit(1);
  }

  await cardsRef.set(cardsMap);
  console.log(`games/${GAME_ID}/assets/cards に ${cards.length}枚のカードを追加しました`);
  console.log("完了！");
}

main().catch((err) => {
  console.error("エラー:", err.message);
  process.exit(1);
});
