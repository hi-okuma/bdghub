const {onRequest} = require("firebase-functions/v2/https");
const {region} = require("./src/config/environment");
const {setupCors} = require("./src/middleware/cors");
const {verifyAppCheckToken} = require("./src/middleware/appCheck");
const {checkMaintenance} = require("./src/middleware/maintenanceCheck");
const {createRoomHandler} = require("./src/handlers/room/createRoom");
const {joinRoomHandler} = require("./src/handlers/room/joinRoom");
const {leaveRoomHandler} = require("./src/handlers/room/leaveRoom");
const {startGameHandler} = require("./src/handlers/games/management/startGame");
const {endGameHandler} = require("./src/handlers/games/management/endGame");
const {setReadyHandler} = require("./src/handlers/games/management/setReady");
const {declare0001Handler} = require("./src/handlers/games/0001/declare");
const {reportResult0002Handler} = require("./src/handlers/games/0002/reportResult");
const {reportResult0003Handler} = require("./src/handlers/games/0003/reportResult");
const {submitHint0004Handler} = require("./src/handlers/games/0004/submitHint");
const {determineAnswer0004Handler} = require("./src/handlers/games/0004/determineAnswer");
const {proceedToNext0004Handler} = require("./src/handlers/games/0004/proceedToNext");

// App Check設定
const appCheckOptions = {
  region: region,
  consumeAppCheckToken: true,
};

/**
 * 共通のミドルウェア処理
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 * @return {Promise<boolean>} ミドルウェアで処理が終了した場合はtrue
 */
async function runMiddlewares(req, res) {
  if (setupCors(req, res)) return true;
  if (await verifyAppCheckToken(req, res)) return true;
  if (await checkMaintenance(req, res)) return true;
  return false;
}

exports.createRoom = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await createRoomHandler(req, res);
});

exports.joinRoom = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await joinRoomHandler(req, res);
});

exports.leaveRoom = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await leaveRoomHandler(req, res);
});

exports.startGame = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await startGameHandler(req, res);
});

exports.endGame = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await endGameHandler(req, res);
});

exports.setReady = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await setReadyHandler(req, res);
});

exports.declare0001 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await declare0001Handler(req, res);
});

exports.reportResult0002 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await reportResult0002Handler(req, res);
});

exports.reportResult0003 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await reportResult0003Handler(req, res);
});

exports.submitHint0004 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await submitHint0004Handler(req, res);
});

exports.determineAnswer0004 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await determineAnswer0004Handler(req, res);
});

exports.proceedToNext0004 = onRequest(appCheckOptions, async (req, res) => {
  if (await runMiddlewares(req, res)) return;
  await proceedToNext0004Handler(req, res);
});
