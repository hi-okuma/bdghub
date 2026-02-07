# 流行語150 - DB設計書

**ゲームID**: `0006`
**ゲームタイトル**: 流行語150
**ゲームタイプ**: 数字パズル × 記憶 × 戦略カードゲーム

---

## 1. Firestoreコレクション構成

```
games/
  0006/                              ... ゲームメタデータ
    assets/
      buzzwords/                     ... カードマスターデータ（全150枚）

rooms/
  {roomId}/
    currentGame/
      0006/                          ... ゲーム進行状態
```

---

## 2. ゲームメタデータ

**パス**: `games/0006`

| フィールド | 型 | 説明 | 例 |
|---|---|---|---|
| title | string | ゲームタイトル | "流行語150" |
| overview | string | 概要（一覧表示用） | "流行語の年を推測して合計150を目指せ！" |
| description | string | 詳細説明 | "流行語が流行った『年』を推測して..." |
| duration | number | プレイ時間（分） | 10 |
| minPlayers | number | 最小プレイ人数 | 1 |
| maxPlayers | number | 最大プレイ人数 | 2 |
| tags | array\<string\> | タグ | ["カードゲーム", "数字パズル", "戦略"] |
| creatorName | string | 作者名 | "" |
| thumbnailUrl | string | サムネイル画像URL | "" |
| playCnt | number | プレイ回数 | 0 |
| releaseDate | Timestamp | リリース日 | Timestamp |
| version | string | バージョン | "1.0.0" |
| isPublished | boolean | 公開状態 | false |
| tutorialImageList | array\<string\> | チュートリアル画像URL | [] |

---

## 3. カードマスターデータ（アセット）

**パス**: `games/0006/assets/buzzwords`

全150種類の流行語カードデータを保持する。ゲーム開始時にここから16枚をランダム選出する。

### ドキュメント構造

```javascript
{
  cards: [
    {
      id: "card_001",        // カード固有ID
      buzzword: "忖度",       // 流行語テキスト（カード表面）
      year: 2017,            // 西暦
      eraName: "平成",       // 和暦の元号名
      eraYear: 29            // 和暦の年数
    },
    {
      id: "card_002",
      buzzword: "インスタ映え",
      year: 2017,
      eraName: "平成",
      eraYear: 29
    },
    // ... 全150枚
  ]
}
```

### カードフィールド詳細

| フィールド | 型 | 説明 | 値の範囲 |
|---|---|---|---|
| id | string | カード固有ID | "card_001" ~ "card_150" |
| buzzword | string | 流行語テキスト | 任意の文字列 |
| year | number | 西暦年 | 1984 ~ 2024（想定） |
| eraName | string | 和暦の元号名 | "昭和" / "平成" / "令和" |
| eraYear | number | 和暦の年数 | 1 ~ 64 |

### 採用値の算出ルール

プレイヤーがカード選択後に選べる2つの値:

| 選択肢 | 算出方法 | 例（2017年/平成29年） | 値の範囲 |
|---|---|---|---|
| 西暦採用 | `year % 100` | 17 | 0 ~ 99 |
| 和暦採用 | `eraYear`そのまま | 29 | 1 ~ 64 |

> **注意**: 2000年の場合、西暦採用値は0になる（戦略的に重要な特殊ケース）

---

## 4. ゲーム進行状態

**パス**: `rooms/{roomId}/currentGame/0006`

ゲーム中のリアルタイム状態を保持する。Firestoreのリアルタイムリスナーで両プレイヤーに同期される。

### ドキュメント構造

```javascript
{
  // --- startGameハンドラーが付与するフィールド ---
  title: "流行語150",
  startedAt: Timestamp,

  // --- ゲームステータス ---
  gameStatus: "playing",           // "playing" | "finished"

  // --- ターン管理 ---
  turnOrder: ["uid_A", "uid_B"],   // プレイヤーの手番順（固定）
  currentTurnPlayerIndex: 0,       // turnOrder内の現在の手番インデックス
  turnPhase: "selectCard",         // "selectCard" | "chooseValue"
  totalTurnCount: 0,               // 完了したターン数（両プレイヤー合計）

  // --- 盤面状態（4×4グリッド = 16枚） ---
  boardCards: [
    {
      id: "card_042",
      buzzword: "忖度",
      year: 2017,
      eraName: "平成",
      eraYear: 29,
      westernValue: 17,            // year % 100（事前計算）
      isAvailable: true            // 選択可能かどうか
    },
    // ... 16枚（配列インデックス = グリッド位置: 0~15）
  ],

  // --- 選択中カード（chooseValueフェーズ中のみ使用） ---
  pendingCardIndex: null,          // boardCards内のインデックス（null = 未選択）

  // --- プレイヤーデータ ---
  players: {
    "uid_A": {
      score: 0,                    // 現在の合計スコア
      cardCount: 0,                // 取得カード枚数（0~5）
      isBurst: false,              // 150超過でバースト
      selectedCards: [
        // 取得済みカードの配列（時系列順）
        // {
        //   cardId: "card_042",
        //   buzzword: "忖度",
        //   chosenType: "western",  // "western" | "era"
        //   chosenValue: 17,
        //   year: 2017,
        //   eraName: "平成",
        //   eraYear: 29
        // }
      ]
    },
    "uid_B": {
      score: 0,
      cardCount: 0,
      isBurst: false,
      selectedCards: []
    }
  },

  // --- ゲーム設定（将来の拡張に対応） ---
  config: {
    targetScore: 150,              // 目標スコア
    maxCardsPerPlayer: 5,          // プレイヤーあたりの最大カード枚数
    boardSize: 16                  // 盤面のカード枚数
  },

  // --- CPU設定 ---
  hasCpu: false,                   // CPUプレイヤーが含まれるか
  cpuPlayerId: null,               // CPUのプレイヤーID（例: "cpu"）

  // --- ゲーム結果（gameStatus: "finished" 時に設定） ---
  result: null
  // 終了時:
  // {
  //   winnerId: "uid_A",          // 勝者のUID（引き分け時はnull）
  //   isDraw: false,              // 引き分けかどうか
  //   winnerScore: 148,           // 勝者のスコア
  //   loserScore: 145,            // 敗者のスコア
  //   winReason: "closer"         // "closer" | "opponentBurst" | "perfect"
  // }
}
```

### フィールド詳細

#### gameStatus

| 値 | 説明 |
|---|---|
| `"playing"` | ゲーム進行中 |
| `"finished"` | ゲーム終了（result が設定される） |

#### turnPhase

| 値 | 説明 | 遷移タイミング |
|---|---|---|
| `"selectCard"` | 手番プレイヤーがカードを選択中 | ターン開始時 / adoptValue完了後 |
| `"chooseValue"` | カード確定後、西暦/和暦を選択中 | confirmCard完了後 |

#### players[uid].selectedCards の要素

| フィールド | 型 | 説明 |
|---|---|---|
| cardId | string | カードID |
| buzzword | string | 流行語テキスト |
| chosenType | string | 採用した値の種類 `"western"` / `"era"` |
| chosenValue | number | 採用した数値 |
| year | number | 西暦 |
| eraName | string | 元号名 |
| eraYear | number | 和暦年数 |

#### result

| フィールド | 型 | 説明 |
|---|---|---|
| winnerId | string \| null | 勝者のUID。引き分け時はnull |
| isDraw | boolean | 引き分けフラグ |
| winnerScore | number | 勝者のスコア |
| loserScore | number | 敗者のスコア |
| winReason | string | 勝因: `"closer"` / `"opponentBurst"` / `"perfect"` |

#### result.winReason

| 値 | 説明 |
|---|---|
| `"closer"` | 両者150以下で、より150に近い方が勝利 |
| `"opponentBurst"` | 相手が150を超えた（バースト）ため勝利 |
| `"perfect"` | ぴったり150を達成して勝利 |

---

## 5. ゲームフロー（状態遷移）

```
[ゲーム開始]
    |
    v
gameStatus: "playing"
turnPhase: "selectCard"
currentTurnPlayerIndex: 0
    |
    v
┌─────────────────────────────────┐
│  手番プレイヤーがカードを選択     │  ← selectCard フェーズ
│  (confirmCard0006 呼び出し)      │
└─────────┬───────────────────────┘
          |
          v
turnPhase: "chooseValue"
pendingCardIndex: N
          |
          v
┌─────────────────────────────────┐
│  西暦/和暦の値を選択             │  ← chooseValue フェーズ
│  (adoptValue0006 呼び出し)       │
└─────────┬───────────────────────┘
          |
          v
    ┌─── 150超過? ──────┐
    |                    |
  [YES]                [NO]
    |                    |
    v                    v
isBurst: true     cardCount++
                  score += value
                         |
                    ┌─── 全プレイヤー5枚選択完了? ───┐
                    |                                  |
                  [YES]                              [NO]
                    |                                  |
                    v                                  v
           gameStatus: "finished"           currentTurnPlayerIndex++
           result: { ... }                  turnPhase: "selectCard"
                                            pendingCardIndex: null
                                                     |
                                                     v
                                            ┌──── 次のプレイヤーは
                                            │     バースト済み? ────┐
                                            |                       |
                                          [YES]                   [NO]
                                            |                       |
                                            v                       v
                                     そのプレイヤーを   通常ターンへ
                                     スキップして次へ   (selectCardに戻る)
```

---

## 6. 勝敗判定ロジック

### バースト判定（即時）
- `adoptValue`実行時にスコアが150を超えた場合、そのプレイヤーは即バースト
- バーストしたプレイヤーの`isBurst`が`true`になる
- バーストしたプレイヤーの残りターンはスキップされる

### ゲーム終了条件
以下のいずれかを満たした場合、ゲーム終了:
1. 全プレイヤーが5枚のカードを選択完了
2. 全プレイヤーがバースト
3. バーストしていないプレイヤーが1人のみで、そのプレイヤーが5枚選択完了

### 勝者決定
| 状況 | 勝者 | winReason |
|---|---|---|
| 片方のみバースト | バーストしていない方 | `"opponentBurst"` |
| 両方バースト | 引き分け（isDraw: true） | - |
| どちらかが150ぴったり | 150ぴったりの方 | `"perfect"` |
| 両方150以下 | 150により近い方 | `"closer"` |
| 両方150以下で同点 | 引き分け（isDraw: true） | - |

---

## 7. APIハンドラー設計

### 7.1 confirmCard0006

カード選択を確定する。`turnPhase`を`"chooseValue"`に遷移させ、相手側にカードフリップを通知する。

**リクエスト**:
```javascript
{
  roomId: "ABCDE",
  uid: "player_uid",
  cardIndex: 7              // boardCards内のインデックス（0~15）
}
```

**バリデーション**:
- roomId, uid, cardIndex が存在すること
- 該当プレイヤーの手番であること（currentTurnPlayerIndex一致）
- turnPhase が "selectCard" であること
- cardIndex のカードが isAvailable: true であること
- 該当プレイヤーがバーストしていないこと

**更新内容**:
```javascript
{
  turnPhase: "chooseValue",
  pendingCardIndex: cardIndex
}
```

### 7.2 adoptValue0006

西暦/和暦の値を採用し、スコアを更新する。ターンを次のプレイヤーに進める、またはゲームを終了する。

**リクエスト**:
```javascript
{
  roomId: "ABCDE",
  uid: "player_uid",
  valueType: "western"       // "western" | "era"
}
```

**バリデーション**:
- roomId, uid, valueType が存在すること
- 該当プレイヤーの手番であること
- turnPhase が "chooseValue" であること
- pendingCardIndex が null でないこと
- valueType が "western" または "era" であること

**更新内容**（バーストしない場合）:
```javascript
{
  // カードを使用済みに
  boardCards[pendingCardIndex].isAvailable: false,

  // プレイヤーのスコア/カード更新
  players[uid].score: currentScore + chosenValue,
  players[uid].cardCount: currentCount + 1,
  players[uid].selectedCards: [...existing, newCard],

  // ターンを進める
  pendingCardIndex: null,
  turnPhase: "selectCard",
  currentTurnPlayerIndex: nextPlayerIndex,
  totalTurnCount: currentTotalTurnCount + 1
}
```

**更新内容**（バーストの場合）:
```javascript
{
  boardCards[pendingCardIndex].isAvailable: false,
  players[uid].score: currentScore + chosenValue,
  players[uid].cardCount: currentCount + 1,
  players[uid].selectedCards: [...existing, newCard],
  players[uid].isBurst: true,

  // 相手もバースト済み or 全員完了の場合 → ゲーム終了
  // そうでなければ次のプレイヤーへ
  pendingCardIndex: null,
  turnPhase: "selectCard",
  currentTurnPlayerIndex: nextAlivePlayerIndex,
  totalTurnCount: currentTotalTurnCount + 1,

  // ゲーム終了条件を満たす場合
  gameStatus: "finished",
  result: { ... }
}
```

---

## 8. CPUプレイヤー設計

### CPU識別
- `hasCpu: true` の場合、`cpuPlayerId`に格納されたIDがCPUプレイヤー
- CPUのUIDには `"cpu"` を使用
- `turnOrder` にCPUのUIDが含まれる（例: `["uid_human", "cpu"]`）

### CPUターンの処理
CPUのターンはクライアント側で自動実行する:
1. Firestoreリスナーで`currentTurnPlayerIndex`の変更を検知
2. 手番がCPUの場合、クライアントがCPU AIロジックを実行
3. クライアントがCPUの代わりに`confirmCard0006`と`adoptValue0006`を呼び出す
4. 適度な遅延（1~2秒）を入れて演出する

### CPU AIロジック（クライアント側実装の参考）

```
1. カード選択: 盤面のisAvailableなカードからランダムに1枚選択
2. 値選択:
   - 残り枚数と残りスコア余裕から理想的な1枚あたりの値を計算
   - idealValue = (targetScore - currentScore) / remainingCards
   - westernValueとeraYearのうち、idealValueに近い方を選択
   - ただし選択した値でバーストする場合、もう一方を選択
   - 両方でバーストする場合、小さい方を選択（バーストは避けられない）
```

---

## 9. 将来の拡張（3~4人対戦）への対応

現在の設計は以下のポイントで拡張に対応:

| 項目 | 現在（2人） | 拡張時の変更 |
|---|---|---|
| turnOrder | 2要素の配列 | 3~4要素に拡大 |
| players | 2エントリ | 3~4エントリに拡大 |
| config.targetScore | 150 | バランス調整可能 |
| config.maxCardsPerPlayer | 5 | バランス調整（例: 3~4枚） |
| config.boardSize | 16 | 拡大可能（例: 20~25枚） |
| result | winnerId/loserId | 順位（ranking配列）に変更が必要 |

### 拡張時に追加が必要なフィールド

```javascript
// result構造の拡張案
result: {
  rankings: [
    { playerId: "uid_A", score: 148, rank: 1 },
    { playerId: "uid_B", score: 145, rank: 2 },
    { playerId: "uid_C", score: 0, rank: 3, isBurst: true }
  ],
  perfectPlayerId: null    // 150ぴったりの人（いれば）
}
```

---

## 10. データ量の見積もり

| データ | サイズ目安 |
|---|---|
| アセット（150枚のカードデータ） | 約 15~20 KB |
| currentGame ドキュメント（初期状態） | 約 3~5 KB |
| currentGame ドキュメント（終了時） | 約 5~8 KB |
| 1ゲームあたりの読み取り回数 | ~20回（リアルタイムリスナー更新） |
| 1ゲームあたりの書き込み回数 | ~12回（confirmCard×10 + adoptValue×10 + init + end） |
