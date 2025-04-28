const {defineString} = require("firebase-functions/params");

const region = defineString("MY_FUNCTION_REGION", {default: "asia-northeast1"});

const MAX_ROOM_PLAYERS = 4;
const ROOM_ID_LENGTH = 8;

module.exports = {
  region,
  MAX_ROOM_PLAYERS,
  ROOM_ID_LENGTH,
};
