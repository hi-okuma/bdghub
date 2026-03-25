/**
 * 汎用ゲーム追加スクリプト
 * games ドキュメントと assets/config を Firestore に追加する。
 *
 * 使い方:
 *   node scripts/addGame.js <dev|stg|prd>
 *
 * 手順:
 *   1. 下の GAME_ID, GAME_DOC, CONFIG_DOC を編集
 *   2. コマンドを実行
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

// 環境→プロジェクトIDのマッピング（.firebaserc と同期）
const PROJECT_MAP = {
  dev: "bdghub-dev",
  stg: "bdghub-stg",
  prd: "bdghub-prd",
};

// ============================================================
// ★ ここを編集してから実行する
// ============================================================

const GAME_ID = "0006";

// games/{GAME_ID} ドキュメント
const GAME_DOC = {
  title: "この流行語、いつのだっけ？",
  description: "プレイヤーは順番にボード上の流行語カードを引き、その言葉が誕生した年代を西暦か和暦のどちらかから選択します。選択した年代に基づいてスコアが加算されていきますが、設定された目標スコアを超えてしまうと「バースト」となりゲームから脱落してしまいます。バーストを避けながらギリギリを見極めてスコアを稼ぎ、未バーストのプレイヤーが残り1人以下になるか、全プレイヤーが規定の上限枚数までカードを引き終わった時点でゲーム終了となります。",
  overview: "流行語の年代で目標スコアを目指す、チキンレース風のカードゲーム！",
  creatorName: "ボドゲハブ",
  thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/bdghub-prd.firebasestorage.app/o/gameIcon%2F0006.png?alt=media&token=c68c47fd-931c-4e0f-93fd-0e5c0b448bb6",
  tutorialImageList: [
    "https://firebasestorage.googleapis.com/v0/b/bdghub-prd.firebasestorage.app/o/title%2F0006%2F0.png?alt=media&token=8a0e2663-bd73-46ac-97fa-f6d0cb2e99f3",
    "https://firebasestorage.googleapis.com/v0/b/bdghub-prd.firebasestorage.app/o/title%2F0006%2F1.png?alt=media&token=ec18bf27-0f1b-49d5-8a53-bd136b73984b",
    "https://firebasestorage.googleapis.com/v0/b/bdghub-prd.firebasestorage.app/o/title%2F0006%2F2.png?alt=media&token=c05440a6-1c5c-48b4-84de-8f6bd7736d18",
    "https://firebasestorage.googleapis.com/v0/b/bdghub-prd.firebasestorage.app/o/title%2F0006%2F3.png?alt=media&token=47703a8c-4fec-4fd1-81b3-88a921db73ff",
  ],
  isPublished: true,
  minPlayers: 1,
  maxPlayers: 2,
  duration: 5,
  playCnt: 0,
  releaseDate: Timestamp.now(),
};

// games/{GAME_ID}/assets/config ドキュメント
// キーはプレイヤー数（文字列）、値はそのプレイヤー数用の設定
const CONFIG_DOC = {
  "2": {
    targetScore: 150,
    maxCardsPerPlayer: 5,
    boardSize: 16,
  },
};

// ============================================================
// ★ 編集ここまで
// ============================================================

async function main() {
  const env = process.argv[2];

  if (!env || !PROJECT_MAP[env]) {
    console.error("使い方: node scripts/addGame.js <dev|stg|prd>");
    process.exit(1);
  }

  const projectId = PROJECT_MAP[env];
  console.log(`環境: ${env} (${projectId})`);
  console.log(`ゲームID: ${GAME_ID}`);

  // 入力チェック
  if (!GAME_ID || !/^\d{4}$/.test(GAME_ID)) {
    console.error("GAME_ID は4桁の数字文字列にしてください（例: \"0006\"）");
    process.exit(1);
  }
  if (!GAME_DOC.title) {
    console.error("GAME_DOC.title が空です。タイトルを設定してください。");
    process.exit(1);
  }

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

  // games ドキュメント
  batch.set(gameRef, GAME_DOC);
  console.log(`  games/${GAME_ID} を追加`);

  // assets/config ドキュメント（中身がある場合のみ）
  if (Object.keys(CONFIG_DOC).length > 0) {
    const configRef = gameRef.collection("assets").doc("config");
    batch.set(configRef, CONFIG_DOC);
    console.log(`  games/${GAME_ID}/assets/config を追加`);
  } else {
    console.log("  assets/config はスキップ（CONFIG_DOC が空）");
  }

  await batch.commit();
  console.log("完了！");
}

main().catch((err) => {
  console.error("エラー:", err.message);
  process.exit(1);
});
