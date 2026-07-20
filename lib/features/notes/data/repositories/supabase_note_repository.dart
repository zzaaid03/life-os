/// Supabase implementation of [NoteRepository].
///
/// Remote-only CRUD against the `notes` table (RLS-scoped per user).
/// Deletes are soft (set `deleted_at`) to match the entity model.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [NoteRepository].
class SupabaseNoteRepository implements NoteRepository {
  /// Creates a [SupabaseNoteRepository].
  const SupabaseNoteRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'notes';

  @override
  Future<Note?> getById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Note.fromJson(response);
  }

  @override
  Future<List<Note>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('is_pinned', ascending: false)
        .order('updated_at', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList();
  }

  @override
  Future<Note> create(Note note) async {
    final response = await _client
        .from(_table)
        .insert(note.toJson())
        .select()
        .single();
    return Note.fromJson(response);
  }

  @override
  Future<Note> update(Note note) async {
    final response = await _client
        .from(_table)
        .update(note.toJson())
        .eq('id', note.id)
        .select()
        .single();
    return Note.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from(_table)
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  @override
  Future<void> purge(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

/// Provides the [NoteRepository].
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseNoteRepository(client);
});
