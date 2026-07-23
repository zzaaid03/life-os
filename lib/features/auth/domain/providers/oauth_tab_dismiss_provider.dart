/// Closes the native Google sign-in browser tab after a successful sign-in.
///
/// On Android/iOS, `signInWithOAuth` opens a Chrome Custom Tab /
/// SFSafariViewController that stays open on top of the app after the OAuth
/// deep link returns, forcing the user to tap X manually. This provider
/// listens to the raw `onAuthStateChange` stream and calls
/// `closeInAppWebView()` once sign-in completes, native platforms only.
/// Activate it once at app startup by reading it (see `main.dart`). Failures
/// are logged, never thrown.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final oauthTabDismissProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);

  final subscription = client.auth.onAuthStateChange.listen((data) async {
    if (kIsWeb || data.event != AuthChangeEvent.signedIn) {
      return;
    }

    // `closeInAppWebView` is async — awaiting it inside the try is what makes
    // the catch effective; unawaited, a failure escapes as an unhandled error.
    try {
      await closeInAppWebView();
    } catch (e) {
      debugPrint('[auth] failed to close in-app web view: $e');
    }
  });

  ref.onDispose(subscription.cancel);
});
