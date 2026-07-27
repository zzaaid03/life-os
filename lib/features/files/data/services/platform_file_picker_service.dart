/// Real [FilePickerService] implementation: opens the platform picker and
/// re-encodes images client-side before they're handed off for upload.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/services/file_picker_service.dart';

const int _maxImageDimension = 2000;
const int _jpegQuality = 85;
const int _thumbnailDimension = 96;
const int _thumbnailJpegQuality = 60;
const int _maxThumbnailBase64Length = 20000;

const Map<String, String> _mimeTypesByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'heic': 'image/heic',
};

String _mimeTypeForFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return 'application/octet-stream';
  }
  final extension = fileName.substring(dotIndex + 1).toLowerCase();
  return _mimeTypesByExtension[extension] ?? 'application/octet-stream';
}

String _withJpegExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  final base = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
  return '$base.jpg';
}

/// Picks a file via `file_picker` and re-encodes images before returning.
class PlatformFilePickerService implements FilePickerService {
  @override
  Future<PickedFile?> pickAndPrepare() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      return null;
    }

    var fileName = picked.name;
    var mimeType = _mimeTypeForFileName(fileName);
    var outputBytes = bytes;
    String? thumbnailBase64;

    if (mimeType.startsWith('image/')) {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final longestSide = decoded.width > decoded.height
            ? decoded.width
            : decoded.height;
        final resized = longestSide > _maxImageDimension
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height
                    ? _maxImageDimension
                    : null,
                height: decoded.height > decoded.width
                    ? _maxImageDimension
                    : null,
              )
            : decoded;
        outputBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: _jpegQuality),
        );
        mimeType = 'image/jpeg';
        fileName = _withJpegExtension(fileName);

        final thumbnail = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _thumbnailDimension : null,
          height: decoded.height > decoded.width ? _thumbnailDimension : null,
        );
        final thumbnailBytes = img.encodeJpg(
          thumbnail,
          quality: _thumbnailJpegQuality,
        );
        final encoded = base64Encode(thumbnailBytes);
        thumbnailBase64 = encoded.length <= _maxThumbnailBase64Length
            ? encoded
            : null;
      }
    }

    if (outputBytes.length > kMaxUploadBytes) {
      final sizeMb = outputBytes.length / (1024 * 1024);
      const limitMb = kMaxUploadBytes / (1024 * 1024);
      throw FilePickException(
        'That file is ${sizeMb.toStringAsFixed(1)} MB. '
        'The limit is ${limitMb.toStringAsFixed(0)} MB.',
      );
    }

    return PickedFile(
      fileName: fileName,
      mimeType: mimeType,
      bytes: outputBytes,
      thumbnailBase64: thumbnailBase64,
    );
  }
}
