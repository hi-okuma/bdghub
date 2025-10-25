import '../components/app_theme.dart';

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});

  static const ValidationResult valid = ValidationResult(isValid: true);
  static ValidationResult invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}

class ValidationUtils {
  static ValidationResult validateNickname(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return ValidationResult.invalid('ニックネームを入力してください');
    }

    // 最小文字数の制限は不要
    // if (value.length < AppLayout.minNicknameLength) {
    //   return ValidationResult.invalid(
    //       'ニックネームは${AppLayout.minNicknameLength}文字以上入力してください');
    // }

    if (value.length > AppLayout.maxNicknameLength) {
      return ValidationResult.invalid(
          'ニックネームは${AppLayout.maxNicknameLength}文字以内で入力してください');
    }

    if (value.contains('/') || value.contains('.')) {
      return ValidationResult.invalid('「/」や「.」は使用できません');
    }

    return ValidationResult.valid;
  }

  static ValidationResult validateRoomId(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return ValidationResult.invalid('部屋コードを入力してください');
    }

    return ValidationResult.valid;
  }

  static ValidationResult validateProfile(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return ValidationResult.invalid('偏見を入力してください');
    }

    if (value.length > AppLayout.maxProfileLength) {
      return ValidationResult.invalid(
          'ニックネームは${AppLayout.maxProfileLength}文字以内で入力してください');
    }

    if (value.contains('\'') ||
        value.contains('"') ||
        value.contains(';') ||
        value.contains('-') ||
        value.contains('=') ||
        value.contains('/') ||
        value.contains('*')) {
      return ValidationResult.invalid('使用できない文字が含まれています。');
    }

    return ValidationResult.valid;
  }
}
