enum GameStatus {
  waiting, // ゲーム開始前/終了後
  playing, // ゲーム中（基本状態）
  childTurn, // 子ターン（0004のみ）
  parentTurn, // 親ターン（0004のみ）
  result,
}

enum GamePhase {
  initial, // 初期状態（ゲーム開始前）
  started, // ゲーム開始済み
  ended, // ゲーム終了済み
}
