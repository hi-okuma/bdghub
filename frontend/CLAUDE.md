# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 運用ルール

- **git コマンドは明示的な指示がない限り実行しない。** コミット・ステージング・プッシュ等は、ユーザーから「コミットして」などの明示的な指示があった場合のみ行う。

## Project Overview

BodogeHub (ボドゲハブ) — a web-based board game platform built with Flutter. Players create/join rooms and play various board games in real-time via Firebase. The app is Japanese-language.

## Common Commands

```bash
# Run locally (web, development)
flutter run -d chrome --dart-define=ENVIRONMENT=development

# Build for specific environment
./build_scripts/build_web.sh development   # or: dev, staging, stg, production, prd

# Analyze code
flutter analyze

# Run tests
flutter test

# Deploy to Firebase Hosting (after build)
firebase deploy --only hosting
```

The build script copies the appropriate `web/index.html.{dev,stg,prd}` variant before building and passes `--dart-define=ENVIRONMENT=<env>` to Flutter.

## Architecture

### State Management — Flutter Riverpod

All state flows through providers in `lib/providers/`:

- **`user_provider.dart`** — `UserNotifier` manages user identity (nickname, uid, roomId, isHost, gamePhase). Persists to `SharedPreferences` for session restoration.
- **`game_provider.dart`** — `CurrentGameNotifier` fetches game metadata + assets from Firestore `games` collection.
- **`game_state_provider.dart`** — `RoomGameStateNotifier` monitors `rooms/{roomId}/currentGame` in real-time. Emits `GameStatus` (waiting/playing/childTurn/parentTurn/result) and `GamePhase` (initial/started/ended). Drives the navigation state machine with duplicate-transition prevention.
- **`room_provider.dart`** — Real-time Firestore stream of room data and player list.

Pages use `ConsumerStatefulWidget` / `ConsumerWidget` to access providers.

### Service Layer (`lib/services/`)

- **`api_service.dart`** — Static methods wrapping Firebase Cloud Functions (`asia-northeast1` region). All game actions (createRoom, joinRoom, startGame, endGame, game-specific moves) go through here.
- **`navigation_service.dart`** — Centralized navigation state machine. Routes users to correct screens based on `GameStatus` + `GamePhase`. Uses a global `NavigatorKey`.
- **`auth_service.dart`** — Firebase Anonymous Authentication.
- **`maintenance_service.dart`** — Checks Firestore `serviceConfig/global` for maintenance mode.
- **`analytics_service.dart`** — Firebase Analytics with `RouteObserver`.

### Page Organization (`lib/pages/`)

Pages are grouped by game with numeric prefixes:
- `0000_HubMain/` — Core pages: top, game selection, game detail, room title, result, profile registration, app initialization, maintenance
- `0001_NgWord/` through `0006_TrendWordBlackJack/` — Individual game implementations

### Startup Flow (`lib/main.dart`)

1. Load environment config (`.env.dev`/`.env.stg`/`.env.prd` via `flutter_dotenv`)
2. Initialize Firebase + App Check (reCAPTCHA v3) + check maintenance status in parallel
3. Extract `roomId` from URL query params (web platform, for room invite links)
4. If maintenance → `MaintenancePage`; otherwise → `AppInitializationPage` (handles auth + user state restoration)

### Environment Configuration

Three environments configured in `lib/config/environment_config.dart` and `.firebaserc`:
- **development** → `bdghub-dev` / `.env.dev`
- **staging** → `bdghub-stg` / `.env.stg`
- **production** → `bdghub-prd` / `.env.prd`

Environment is set via `--dart-define=ENVIRONMENT=<name>` at build time.

### Firebase Structure (Firestore)

- `games/` — Game metadata; `games/{id}/assets/` subcollection for game-specific data
- `rooms/` — Active rooms with `players` map, `hostPlayer` field; `rooms/{id}/currentGame/` subcollection for real-time game state
- `serviceConfig/global` — Maintenance mode flag

### Theming (`lib/components/app_theme.dart`)

Material 3 design system. Primary color: `#E07000`. Font: Google Fonts Noto Sans JP + custom ZouFont. Spacing, border radius, and text style constants are defined in `AppTheme`.

### Error Handling

`lib/utils/error_handler.dart` provides centralized Firebase Functions error handling with SnackBar display. `api_service.dart` methods accept `ignoredErrorCodes` to suppress expected errors.

## 復帰時ルーティングの設計原則

ブラウザリロード時、`AppInitializationPage._restoreCurrentGameLogic` が `gamePhase`（SharedPreferences に永続化）と Firestore の `gameStatus` を組み合わせてどの画面に復帰するかを決定する。新しいゲームを追加するときは必ずこのロジックに対応するケースを追加すること。

### GamePhase の意味

| GamePhase | 意味 | 典型的な復帰先 |
|---|---|---|
| `initial` | ゲーム未開始（タイトル画面で準備中） | `navigateToGameTitle()` |
| `started` | ゲームプレイ中〜ラウンド終了後（結果確認待ち） | `navigateToPlayingPage()` など |
| `ended` | ゲーム完全終了（汎用結果画面へ遷移済み） | `navigateToResult()` |

`GamePhase` は `game_state_provider._updateAndSaveGamePhase()` 経由で更新・保存される。

### ゲーム固有の復帰処理

`_restoreCurrentGameLogic` に `if (gameId == 'XXXX')` ブロックを追加する場合、以下の点を必ず考慮する：

1. **`gamePhase` で分岐する。早期 `return` するので `ended` を汎用コードに委譲できない** — `gameStatus` だけでは「ゲーム未開始の waiting」と「ラウンド終了後の waiting」を区別できない。さらにゲーム固有ブロックは末尾で `return` するため、`ended`（結果発表画面）を下部の汎用 result 処理に委譲できない。`started / ended / initial` の **3分岐をブロック内で自己完結** させること。2分岐（started → Playing、else → Title）にすると `ended` でリロードした際に誤ってタイトル画面へ遷移する。

   ```dart
   if (gameId == 'XXXX') {
     if (savedGamePhase == GamePhase.started) {
       navigationService.navigateToPlayingPage();    // ゲーム進行中・ラウンド終了後
     } else if (savedGamePhase == GamePhase.ended) {
       navigationService.navigateToResult(gameData); // ゲーム完全終了 → 結果発表画面
     } else {
       navigationService.navigateToGameTitle();       // ゲーム未開始(initial)
     }
     ...
     return;
   }
   ```

2. **`gamePhase` を適切に更新する** — `game_state_provider._handleGameStateChange` でゲーム固有の `break` を使う場合、`_updateAndSaveGamePhase` が呼ばれないケースが生じる。復帰ルーティングが正しく機能するか、フェーズ更新のタイミングを確認する。

3. **`waiting → result` を使うゲームは復帰時に `_currentGamePhase` を復元する** — 汎用 GameResultPage への遷移は `_handleGameStateChange` の waiting case にある `if (_currentGamePhase == GamePhase.started)` が発火条件。`_currentGamePhase` は game_state_provider のメモリ上の値で、リロード時に `_resetNavigationFlags()` で `initial` に戻る。`_handleGameDetailUpdate` の復帰ブランチ（`userState.isRestoring`）で **保存済み `userState.gamePhase` を `_currentGamePhase` に復元しないと**、リロード後にラウンドが終了（waiting）しても結果遷移条件を満たさず、結果発表画面に遷移せず次のゲームデータ（次のお題など）が表示される。永続値の読み戻しなので `_updateAndSaveGamePhase` ではなく `_currentGamePhase` への直接代入で行う。

4. **ページ側の `_checkAndRestoreDialogs` でも `gamePhase` を使う** — プレイ画面内でダイアログ復帰を行う場合、`gameStatus` だけで判定すると前のゲームの Firestore 残存データ（例: `winnerId`）を誤検知する。追加の条件（`winnerId != null` など）か `user.gamePhase` で絞り込む。

### よくあるバグパターン

- **症状**: リロード後、ゲームタイトル画面に戻るはずがプレイ画面の結果ダイアログが出る
- **原因**: 復帰ルーティングが `gamePhase` を無視して常に PlayingPage に飛ばしている、かつ前ゲームの `winnerId` 等が Firestore に残存している
- **対処**: 上記 1 の通り `savedGamePhase == GamePhase.started` のときだけ PlayingPage に遷移するよう分岐する

---

- **症状**: 結果発表画面（ended）でリロードすると、結果画面に戻らずゲーム開始画面（タイトル）に遷移する
- **原因**: ゲーム固有の復帰ブロックが2分岐（started → Playing、else → Title）で、早期 `return` のため `ended` が下部の汎用 result 処理に届かず else に吸われている
- **対処**: 上記 1 の通り `started / ended / initial` の3分岐にし、`ended` は `navigateToResult` をブロック内で呼ぶ

---

- **症状**: ゲーム中にリロードして復帰した後、最後の親番が終わり waiting になっても結果発表画面に遷移せず、次のお題（次ラウンドのデータ）が表示されたままになる
- **原因**: リロードで `_currentGamePhase` が `_resetNavigationFlags()` により `initial` に戻り、復帰ブランチで復元していないため、waiting 検知時の result 遷移条件 `_currentGamePhase == GamePhase.started` を満たさない
- **対処**: 上記 3 の通り `_handleGameDetailUpdate` の復帰ブランチで `userState.gamePhase` を `_currentGamePhase` に復元する（`waiting → result` を使う全ゲーム共通）

## Conventions

- Commit messages reference Jira tickets (e.g., `BODOGE-245`)
- Japanese comments are used throughout the codebase
- Game-specific API methods in `api_service.dart` are suffixed with the game ID (e.g., `declare0001`, `submitHint0004`)
- Logger (`lib/utils/logger.dart`) only outputs in development builds

## Adding a New Game — Checklist & Template

### Checklist

1. **ページ作成**: `lib/pages/XXXX_GameName/` にプレイ画面を作成
2. **navigation_service.dart 登録**: `navigateToPlayingPage()` の switch 文に `case 'XXXX'` を追加（ゲームが childTurn/parentTurn/result ステータスを使う場合は対応メソッドにも追加）
3. **api_service.dart 確認**: ゲーム固有の API メソッド（例: `actionXXXX`）が存在することを確認
4. **flutter analyze**: 静的解析でエラーがないことを確認

### ゲーム画面テンプレート（playing ステータス用）

```dart
import 'package:bodogehub/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bodogehub/components/app_theme.dart';
import 'package:bodogehub/components/custom_widgets.dart';
import 'package:bodogehub/providers/user_provider.dart';
import 'package:bodogehub/providers/room_provider.dart';
import 'package:bodogehub/providers/game_provider.dart';
import 'package:bodogehub/providers/analytics_provider.dart';
import 'package:bodogehub/services/api_service.dart';
import 'package:bodogehub/utils/game_exit_handler.dart';

class XxxxPlayingPage extends ConsumerStatefulWidget {
  const XxxxPlayingPage({super.key});

  @override
  ConsumerState<XxxxPlayingPage> createState() => _XxxxPlayingPageState();
}

class _XxxxPlayingPageState extends ConsumerState<XxxxPlayingPage>
    with GameExitHandler, RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  bool _isLoading = false;

  // --- GameExitHandler 必須オーバーライド ---
  @override
  final String pageTitle = '/XXXX/xxxx_playing_page';

  @override
  String? get gameId => ref.read(currentGameProvider).gameId;

  @override
  void setError(String message) {
    if (mounted) {
      Logger.log('XxxxPlayingPageでエラー発生: $message');
    }
  }

  // --- RouteAware ライフサイクル ---
  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(analyticsServiceProvider).routeObserver;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    ref.read(analyticsServiceProvider).logPageView(pageTitle: pageTitle);
  }

  // --- 型安全な値抽出ヘルパー ---
  String? _extractStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value.first?.toString();
    return value.toString();
  }

  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) {
      final v = value.first;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  bool? _extractBoolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    if (value is List && value.isNotEmpty) {
      final v = value.first;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is int) return v != 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final currentGame = ref.watch(currentGameProvider);
    final isHost = ref.watch(isHostProvider);

    // --- ガード: gameData null check ---
    if (currentGame.gameData == null || currentGame.gameData!.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final gameData = currentGame.gameData;
    final gameTitle = gameData?['title'] as String;
    final roomId = currentUser.roomId;

    // --- ガード: roomId null check ---
    if (roomId == null) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Text('部屋情報が見つかりません', style: AppTextStyles.subtitle),
          ),
        ),
      );
    }

    // --- プレイヤーデータ取得 ---
    // roomStreamProvider + gameData を UID ベースで結合
    final roomSnapshot = ref.watch(roomStreamProvider(roomId));
    // TODO: roomSnapshot.when(...) でプレイヤーリストを構築

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: GameAppBar(
          gameTitle: gameTitle,
          isHost: isHost,
          onExitPressed: () {
            ref.read(analyticsServiceProvider).logClick(button: 'game_quit');
            showExitGameDialog();
          },
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            // TODO: ゲーム固有の UI
          ],
        ),
      ),
    );
  }
}
```

### 共通パターン早見表

| パターン | 説明 |
|---|---|
| `GameExitHandler` mixin | ゲーム終了ダイアログ＋API呼び出し。`pageTitle`, `gameId`, `setError()` をオーバーライド |
| `RouteAware` mixin | `didPush()` でアナリティクス送信 |
| `gameData` null ガード | `currentGame.gameData == null` 時に `CircularProgressIndicator` を返す |
| `roomId` null ガード | `currentUser.roomId == null` 時にエラーメッセージを表示 |
| `PopScope(canPop: false)` | ブラウザバック防止 |
| `roomStreamProvider` + `gameData` 結合 | UID をキーに `roomPlayersMap` と `playersGameData` を結合 |
| `ElevatedLoadingButton` + `_isLoading` | API コール中のローディング状態管理 |

## Flutter スキル集

`.agents/skills/` 配下に Flutter の実装ガイドラインが定義されています。該当タスクを依頼する際は、対応するスキルファイルを参照して実装してください。

| スキル名 | 用途 | パス |
|---|---|---|
| `flutter-implement-json-serialization` | `fromJson`/`toJson` を使った手動 JSON シリアライズ | `.agents/skills/flutter-implement-json-serialization/SKILL.md` |
| `flutter-use-http-package` | `http` パッケージで REST API (GET/POST/PUT/DELETE) を呼ぶ | `.agents/skills/flutter-use-http-package/SKILL.md` |
| `flutter-build-responsive-layout` | `LayoutBuilder`/`MediaQuery` でレスポンシブレイアウトを構築する | `.agents/skills/flutter-build-responsive-layout/SKILL.md` |
| `flutter-fix-layout-issues` | RenderFlex overflow など Flutter レイアウトエラーを修正する | `.agents/skills/flutter-fix-layout-issues/SKILL.md` |
| `flutter-apply-architecture-best-practices` | UI/Logic/Data の3層アーキテクチャを適用する | `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md` |
| `flutter-setup-declarative-routing` | `go_router` を使った宣言的ルーティングを設定する | `.agents/skills/flutter-setup-declarative-routing/SKILL.md` |
| `flutter-setup-localization` | `flutter_localizations` + `intl` でローカライズを初期化する | `.agents/skills/flutter-setup-localization/SKILL.md` |
| `flutter-add-widget-test` | `WidgetTester` でウィジェットの描画・操作を検証するテストを書く | `.agents/skills/flutter-add-widget-test/SKILL.md` |
| `flutter-add-widget-preview` | `previews.dart` を使ったインタラクティブなウィジェットプレビューを追加する | `.agents/skills/flutter-add-widget-preview/SKILL.md` |
| `flutter-add-integration-test` | `integration_test` パッケージでインテグレーションテストを追加する | `.agents/skills/flutter-add-integration-test/SKILL.md` |
