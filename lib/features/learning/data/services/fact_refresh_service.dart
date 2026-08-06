/// Triggers the `infer-facts` Edge Function at most once a day per user.
///
/// Fact inference reads the user's own tasks, goals, job applications and
/// file notes and is not something the UI should ever wait on. This gates
/// the call behind a per-user SharedPreferences timestamp
/// (`facts_last_refreshed_$userId`), the same per-user-ID pattern already
/// used by `onboarding_provider.dart`: a per-browser flag would be wrong
/// here for the same reason it was wrong there.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/demo/demo_mode.dart';
import 'package:life_os/features/learning/domain/providers/fact_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _refreshInterval = Duration(hours: 24);

/// Calls `infer-facts` for [userId] if it hasn't run in the last 24 hours,
/// then refreshes [factListProvider] on success.
///
/// Never throws into the caller: every failure is caught and logged. Skips
/// silently in demo mode, which must make zero network calls.
class FactRefreshService {
  /// Creates a [FactRefreshService].
  FactRefreshService(this._ref);

  final Ref _ref;

  String _keyFor(String userId) => 'facts_last_refreshed_$userId';

  /// Triggers a refresh for [userId] if due. Fire-and-forget from callers.
  Future<void> refreshIfDue(String userId) async {
    if (_ref.read(isDemoModeProvider)) return;

    final prefs = await SharedPreferences.getInstance();
    final lastRaw = prefs.getString(_keyFor(userId));
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    if (last != null && DateTime.now().toUtc().difference(last) < _refreshInterval) {
      return;
    }

    final client = _ref.read(supabaseClientProvider);
    await client.functions.invoke('infer-facts');

    await prefs.setString(_keyFor(userId), DateTime.now().toUtc().toIso8601String());
    await _ref.read(factListProvider.notifier).refresh();
  }
}

/// Provides the [FactRefreshService].
final factRefreshServiceProvider = Provider<FactRefreshService>((ref) {
  return FactRefreshService(ref);
});

/// Activates the fact-refresh trigger for the app session.
///
/// Reading this provider once (e.g. from `LifeOSApp.initState`) subscribes to
/// auth state changes and a cold-start check, mirroring
/// `oauthTabDismissProvider`'s activation pattern. Every call into the
/// service is unawaited: nothing in the UI may ever block on inference.
final factRefreshTriggerProvider = Provider<void>((ref) {
  if (ref.watch(isDemoModeProvider)) return;

  final client = ref.watch(supabaseClientProvider);

  void trigger(String? userId) {
    if (userId == null) return;
    unawaited(
      ref.read(factRefreshServiceProvider).refreshIfDue(userId).catchError((
        Object e,
      ) {
        debugPrint('[learning] fact refresh failed: $e');
      }),
    );
  }

  final subscription = client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      trigger(data.session?.user.id);
    }
  });
  ref.onDispose(subscription.cancel);

  // Cold-start: a restored session has no sign-in transition to listen for.
  trigger(client.auth.currentSession?.user.id);
});
