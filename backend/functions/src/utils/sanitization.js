/**
 * XSS対策のための共通サニタイゼーションユーティリティ
 */

/**
 * HTMLエスケープを行う
 * @param {string} str - エスケープする文字列
 * @return {string} エスケープされた文字列
 */
function escapeHtml(str) {
  if (typeof str !== "string") {
    return str;
  }

  return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
      .replace(/\//g, "&#x2F;")
      .replace(/`/g, "&#x60;")
      .replace(/=/g, "&#x3D;");
}

/**
 * JavaScriptコードの実行を防ぐための危険な文字列パターンを除去
 * @param {string} str - チェック対象の文字列
 * @return {string} サニタイズされた文字列
 */
function removeJavaScriptPatterns(str) {
  if (typeof str !== "string") {
    return str;
  }

  // 危険なJavaScriptパターンを除去
  const dangerousPatterns = [
    /<script[\s\S]*?<\/script>/gi,
    /javascript:/gi,
    /on\w+\s*=/gi, // onload, onclick, onmouseover等のイベントハンドラ
    /data:text\/html/gi,
    /vbscript:/gi,
    /expression\s*\(/gi,
    /import\s+/gi,
    /eval\s*\(/gi,
    /function\s*\(/gi,
    /setTimeout\s*\(/gi,
    /setInterval\s*\(/gi,
  ];

  let sanitized = str;
  dangerousPatterns.forEach((pattern) => {
    sanitized = sanitized.replace(pattern, "");
  });

  return sanitized;
}

/**
 * 制御文字を除去する関数
 * @param {string} str - 対象文字列
 * @return {string} 制御文字が除去された文字列
 */
function removeControlCharacters(str) {
  return str
      .split("")
      .filter((char) => {
        const charCode = char.charCodeAt(0);
        return charCode >= 32 && charCode !== 127; // ASCII制御文字（0-31）とDEL文字（127）を除外
      })
      .join("");
}

/**
 * 汎用的なユーザー入力サニタイゼーション
 * @param {string} input - サニタイズする入力値
 * @param {Object} options - サニタイゼーションオプション
 * @param {number} [options.maxLength] - 最大文字数
 * @param {string[]} [options.forbiddenChars] - 禁止文字の配列
 * @param {boolean} [options.allowEmpty=false] - 空文字を許可するか
 * @param {string} [options.fieldName='入力値'] - エラーメッセージで使用するフィールド名
 * @return {string} サニタイズされた文字列
 * @throws {Error} バリデーションエラーの場合
 */
function sanitizeUserInput(input, options = {}) {
  const {
    maxLength,
    forbiddenChars = [],
    allowEmpty = false,
    fieldName = "入力値",
  } = options;

  if (typeof input !== "string") {
    throw new Error(`${fieldName}は文字列である必要があります。`);
  }

  let sanitized = input.trim();

  if (!allowEmpty && sanitized.length === 0) {
    throw new Error(`${fieldName}を入力してください。`);
  }

  if (maxLength && sanitized.length > maxLength) {
    throw new Error(`${fieldName}は${maxLength}文字以内で入力してください。`);
  }

  for (const char of forbiddenChars) {
    if (sanitized.includes(char)) {
      throw new Error(`${fieldName}に禁止文字「${char}」が含まれています。`);
    }
  }

  sanitized = escapeHtml(sanitized);

  sanitized = removeJavaScriptPatterns(sanitized);

  sanitized = removeControlCharacters(sanitized);

  if (!allowEmpty && sanitized.length === 0) {
    throw new Error(`${fieldName}に使用できない文字が含まれています。`);
  }

  return sanitized;
}

/**
 * 英数字のみの入力値をサニタイゼーション（部屋コードなど用）
 * @param {string} input - サニタイズする入力値
 * @param {Object} options - サニタイゼーションオプション
 * @param {number} [options.maxLength] - 最大文字数
 * @param {string} [options.fieldName='入力値'] - エラーメッセージで使用するフィールド名
 * @return {string} サニタイズされた文字列
 * @throws {Error} バリデーションエラーの場合
 */
function sanitizeAlphanumeric(input, options = {}) {
  const {maxLength, fieldName = "入力値"} = options;

  if (typeof input !== "string") {
    throw new Error(`${fieldName}は文字列である必要があります。`);
  }

  const trimmed = input.trim();

  if (trimmed.length === 0) {
    throw new Error(`${fieldName}を入力してください。`);
  }

  if (maxLength && trimmed.length > maxLength) {
    throw new Error(`${fieldName}は${maxLength}文字以内で入力してください。`);
  }

  const sanitized = trimmed.replace(/[^a-zA-Z0-9]/g, "");

  if (sanitized !== trimmed) {
    throw new Error(`${fieldName}は半角英数字のみ使用できます。`);
  }

  return sanitized;
}

module.exports = {
  escapeHtml,
  removeJavaScriptPatterns,
  removeControlCharacters,
  sanitizeUserInput,
  sanitizeAlphanumeric,
};
