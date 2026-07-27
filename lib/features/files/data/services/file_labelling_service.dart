/// Requests AI search labels for an uploaded file.
///
/// The AI is given the user's note and the file name ONLY. File contents are
/// never transmitted, for two reasons: the model is text-only so it could not
/// read a photo anyway, and keeping bytes inside Supabase is what makes the
/// per-file "private, never send to AI" toggle cheap to honour rather than
/// something that has to be enforced in several places.
///
/// The call expands the note into synonyms, so a file noted as "my flat
/// lease" is also found by "tenancy" or "rental contract".
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/demo/demo_mode.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks the backend to label a stored file.
abstract class FileLabellingService {
  /// Requests labels for [fileId].
  ///
  /// FIRE AND FORGET: labelling is an enhancement to search, never a
  /// precondition for a successful upload. Callers must not let a failure
  /// here fail the upload, and the file stays findable by its note and name
  /// regardless. The backend is responsible for skipping private files.
  Future<void> requestLabel(String fileId);
}

/// Calls the `label-file` Edge Function.
class SupabaseFileLabellingService implements FileLabellingService {
  /// Creates a [SupabaseFileLabellingService].
  SupabaseFileLabellingService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> requestLabel(String fileId) async {
    await _client.functions.invoke(
      'label-file',
      body: {'fileId': fileId},
    );
  }
}

/// Does nothing. Used in demo mode.
///
/// Demo mode makes ZERO network calls; that is a guarantee the demo rests on,
/// not a performance choice. Without this, uploading a file in the sandbox
/// would quietly reach out to a real Edge Function.
class NoopFileLabellingService implements FileLabellingService {
  /// Creates a [NoopFileLabellingService].
  const NoopFileLabellingService();

  @override
  Future<void> requestLabel(String fileId) async {}
}

/// Provides the [FileLabellingService], no-op in demo mode.
final fileLabellingServiceProvider = Provider<FileLabellingService>((ref) {
  if (ref.watch(isDemoModeProvider)) {
    return const NoopFileLabellingService();
  }
  return SupabaseFileLabellingService(ref.watch(supabaseClientProvider));
});
