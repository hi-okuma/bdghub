const {onCall} = require("firebase-functions/v2/https");
const {region} = require("./src/config/environment");
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
const {proceedToNext0005Handler} = require("./src/handlers/games/0005/proceedToNext");
const {confirmCard0006Handler} = require("./src/handlers/games/0006/confirmCard");
const {adoptValue0006Handler} = require("./src/handlers/games/0006/adoptValue");
const {startTimer0007Handler} = require("./src/handlers/games/0007/startTimer");
const {reportResult0007Handler} = require("./src/handlers/games/0007/reportResult");

const {cleanupAnonymousUsers} = require("./src/handlers/maintenance/cleanupAnonymousUsers");
const {cleanupInactiveRooms} = require("./src/handlers/maintenance/cleanupInactiveRooms");

const commonOptions = {
  region: region,
  enforceAppCheck: true,
};

// 部屋関連の関数
exports.createRoom = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await createRoomHandler(request);
});

exports.joinRoom = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await joinRoomHandler(request);
});

exports.leaveRoom = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await leaveRoomHandler(request);
});

// ゲーム管理関連の関数
exports.startGame = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await startGameHandler(request);
});

exports.endGame = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await endGameHandler(request);
});

exports.setReady = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await setReadyHandler(request);
});

// ゲーム固有の関数
exports.declare0001 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await declare0001Handler(request);
});

exports.reportResult0002 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await reportResult0002Handler(request);
});

exports.reportResult0003 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await reportResult0003Handler(request);
});

exports.submitHint0004 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await submitHint0004Handler(request);
});

exports.determineAnswer0004 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await determineAnswer0004Handler(request);
});

exports.proceedToNext0004 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await proceedToNext0004Handler(request);
});

exports.proceedToNext0005 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await proceedToNext0005Handler(request);
});

exports.confirmCard0006 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await confirmCard0006Handler(request);
});

exports.adoptValue0006 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await adoptValue0006Handler(request);
});

exports.startTimer0007 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await startTimer0007Handler(request);
});

exports.reportResult0007 = onCall(commonOptions, async (request) => {
  await checkMaintenance(request);
  return await reportResult0007Handler(request);
});

exports.cleanupAnonymousUsers = cleanupAnonymousUsers;
exports.cleanupInactiveRooms = cleanupInactiveRooms;
