const {onRequest} = require("firebase-functions/v2/https");
const {region} = require("./src/config/environment");
const {setupCors} = require("./src/middleware/cors");
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

exports.createRoom = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await createRoomHandler(req, res);
});

exports.joinRoom = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await joinRoomHandler(req, res);
});

exports.leaveRoom = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await leaveRoomHandler(req, res);
});

exports.startGame = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await startGameHandler(req, res);
});

exports.endGame = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await endGameHandler(req, res);
});

exports.setReady = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await setReadyHandler(req, res);
});

exports.declare0001 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await declare0001Handler(req, res);
});

exports.reportResult0002 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await reportResult0002Handler(req, res);
});

exports.reportResult0003 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await reportResult0003Handler(req, res);
});

exports.submitHint0004 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await submitHint0004Handler(req, res);
});

exports.determineAnswer0004 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await determineAnswer0004Handler(req, res);
});

exports.proceedToNext0004 = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await proceedToNext0004Handler(req, res);
});
