/// A file the user picked, already validated and (for images) re-encoded,
/// ready to hand to the repository for upload.
///
/// This is the hand-off type between the picker/re-encode service and the
/// file repository. It holds bytes in memory, which is safe because uploads
/// are capped at [kMaxUploadBytes].
library;

import 'dart:typed_data';

/// Hard cap on what may be uploaded, after any client-side re-encode.
///
/// 10 MB, chosen by Zaid. Supabase's own per-file ceiling on the free plan
/// is 50 MB, so this is the binding limit.
const int kMaxUploadBytes = 10 * 1024 * 1024;

/// A picked, validated, upload-ready file.
class PickedFile {
  /// Creates a [PickedFile].
  const PickedFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  /// Original file name including extension, shown to the user.
  final String fileName;

  /// MIME type. For a re-encoded image this is the type actually produced,
  /// not the type of the original the user chose.
  final String mimeType;

  /// The bytes to upload.
  final Uint8List bytes;

  /// Size of [bytes].
  int get sizeBytes => bytes.length;

  /// True when this file is an image.
  bool get isImage => mimeType.startsWith('image/');
}
