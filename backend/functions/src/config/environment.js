const {defineString} = require("firebase-functions/params");

const region = defineString("MY_FUNCTION_REGION", {default: "asia-northeast1"});

// この定数はデフォルト値として使用し、実際の値はserviceConfigから取得
const DEFAULT_MAX_ROOM_PLAYERS = 4;
const ROOM_ID_LENGTH = 8;

module.exports = {
  region,
  DEFAULT_MAX_ROOM_PLAYERS,
  ROOM_ID_LENGTH,
};
