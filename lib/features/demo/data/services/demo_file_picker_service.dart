/// In-memory demo override of [FilePickerService], returns a small
/// hardcoded [PickedFile] instead of opening the platform file picker.
library;

import 'dart:typed_data';

import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/services/file_picker_service.dart';

/// A [FilePickerService] that never opens a real platform dialog.
///
/// Tapping upload in demo mode should produce a visible new file, not a
/// native picker or a crash, so this returns a tiny in-memory PDF-shaped
/// payload every time it is called.
class DemoFilePickerService implements FilePickerService {
  @override
  Future<PickedFile?> pickAndPrepare() async {
    return PickedFile(
      fileName: 'demo-upload.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList('Demo upload placeholder'.codeUnits),
    );
  }
}
