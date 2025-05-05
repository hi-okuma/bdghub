const {onRequest} = require("firebase-functions/v2/https");
const {region} = require("./src/config/environment");
const {setupCors} = require("./src/middleware/cors");
const {checkMaintenance} = require("./src/middleware/maintenanceCheck");
const {createRoomHandler} = require("./src/handlers/room/createRoom");
const {joinRoomHandler} = require("./src/handlers/room/joinRoom");
const {leaveRoomHandler} = require("./src/handlers/room/leaveRoom");
const {startGameHandler} = require("./src/handlers/games/management/startGame");
const {endGameHandler} = require("./src/handlers/games/management/endGame");
const {setReadyHandler} = require("./src/handlers/games/0001/setReady");
const {declareHandler} = require("./src/handlers/games/0001/declare");

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

exports.declare = onRequest({region: region}, async (req, res) => {
  if (setupCors(req, res)) return;
  if (await checkMaintenance(req, res)) return;
  await declareHandler(req, res);
});
