/// Inbox consent state.
///
/// Tracks whether the user has agreed to let Life OS read their recent
/// emails to suggest tasks and track job applications. Persisted with
/// SharedPreferences so the consent screen is shown only once.
library;

import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the inbox-scan consent flag.
const String _kInboxConsentKey = 'inbox_scan_consent_granted';

/// Loads and persists the user's inbox-scan consent.
class InboxConsentController extends StateNotifier<bool> {
  /// Creates an [InboxConsentController] and eagerly loads the stored flag.
  InboxConsentController() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_kInboxConsentKey) ?? false;
    } catch (_) {
      // Treat any storage failure as "not yet consented" — the worst case is
      // showing the consent screen again, which is safe.
      state = false;
    }
  }

  /// Records that the user granted consent and persists it.
  Future<void> grantConsent() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kInboxConsentKey, true);
    } catch (_) {
      // If persistence fails the in-memory flag still lets the current
      // session proceed; the consent screen may reappear next launch.
    }
  }
}

/// Whether the user has consented to inbox scanning (persisted).
final inboxConsentProvider =
    StateNotifierProvider<InboxConsentController, bool>((ref) {
      return InboxConsentController();
    });
