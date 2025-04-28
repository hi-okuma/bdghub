/**
 * CORSヘッダーを設定し、プリフライトリクエストを処理する
 * @param {object} req - リクエストオブジェクト
 * @param {object} res - レスポンスオブジェクト
 * @return {boolean} プリフライトリクエストの場合はtrue、それ以外はfalse
 */
function setupCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return true;
  }
  return false;
}

module.exports = {
  setupCors,
};
