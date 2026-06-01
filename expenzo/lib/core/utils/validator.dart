import '../constants/app_constants.dart';

class AppValidator {
  AppValidator._();

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than zero.';
    }
    if (parsed > AppConstants.maxTransactionAmount) {
      return 'Amount is too large.';
    }
    return null;
  }

  static String? categoryName(String? value, {List<String> existing = const []}) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required.';
    }
    if (value.trim().length > 40) {
      return 'Name must be 40 characters or less.';
    }
    final trimmed = value.trim().toLowerCase();
    if (existing.any((e) => e.toLowerCase() == trimmed)) {
      return 'This category name already exists.';
    }
    return null;
  }

  static String? note(String? value) {
    if (value != null && value.length > AppConstants.maxNoteLength) {
      return 'Note must be ${AppConstants.maxNoteLength} characters or less.';
    }
    return null;
  }

  static String? title(String? value) {
    if (value != null && value.trim().length > AppConstants.maxTitleLength) {
      return 'Title must be ${AppConstants.maxTitleLength} characters or less.';
    }
    return null;
  }

  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  /// Validates that source and destination wallets are not the same.
  static String? transferWallets(String? sourceId, String? destinationId) {
    if (sourceId == null || destinationId == null) {
      return 'Both wallets must be selected.';
    }
    if (sourceId == destinationId) {
      return 'Source and destination wallets must be different.';
    }
    return null;
  }
}