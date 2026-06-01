/// Base class for all Expenzo exceptions.
abstract class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a database operation fails.
class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

/// Thrown when backup export fails.
class BackupExportException extends AppException {
  const BackupExportException(super.message);
}

/// Thrown when backup import/restore fails.
class BackupImportException extends AppException {
  const BackupImportException(super.message);
}

/// Thrown when imported JSON is structurally invalid.
class CorruptedBackupException extends BackupImportException {
  const CorruptedBackupException(super.message);
}

/// Thrown when backup version is unsupported.
class UnsupportedBackupVersionException extends BackupImportException {
  const UnsupportedBackupVersionException(int version)
      : super('Unsupported backup version: $version');
}

/// Thrown when a transfer operation is logically invalid.
class InvalidTransferException extends AppException {
  const InvalidTransferException(super.message);
}

/// Thrown when form or model validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Thrown when a category name already exists.
class DuplicateCategoryException extends AppException {
  const DuplicateCategoryException(String name)
      : super('Category "$name" already exists.');
}

/// Thrown when attempting to delete a default (protected) category.
class ProtectedCategoryException extends AppException {
  const ProtectedCategoryException()
      : super('Default categories cannot be deleted.');
}