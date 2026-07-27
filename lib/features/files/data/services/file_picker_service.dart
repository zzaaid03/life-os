/// Picks a file from the device and prepares it for upload.
///
/// "Prepares" means: enforce the size cap, and re-encode/resize images
/// client-side before they ever leave the device. Re-encoding is worth
/// roughly 8-10x on a phone photo, costs nothing, and sends nothing to a
/// third party. Camera capture is deliberately out of scope for this slice.
library;

import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/services/platform_file_picker_service.dart';
import 'package:riverpod/riverpod.dart';

/// Thrown when the user picked something that cannot be uploaded.
class FilePickException implements Exception {
  /// Creates a [FilePickException].
  const FilePickException(this.message);

  /// Human-readable reason, safe to show in a snackbar.
  final String message;

  @override
  String toString() => message;
}

/// Picks and prepares files for upload.
abstract class FilePickerService {
  /// Opens the platform file picker.
  ///
  /// Returns null if the user cancelled. Throws [FilePickException] if the
  /// result is still over [kMaxUploadBytes] after any re-encode, so callers
  /// can show the reason rather than failing silently.
  Future<PickedFile?> pickAndPrepare();
}

/// Provides the [FilePickerService].
final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return PlatformFilePickerService();
});
