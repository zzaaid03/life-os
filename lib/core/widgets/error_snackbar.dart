/// The one way screens show a failure as a snackbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [message] in a floating snackbar.
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

/// Shows a snackbar each time [error] changes to a new non-null message.
///
/// Call it from `build`. Pass a selector that only yields the error while the
/// old list is still on screen (a failed refresh), so it does not double up
/// with the full-screen error view after a failed first load.
void listenForRefreshError(
  WidgetRef ref,
  BuildContext context,
  ProviderListenable<String?> error,
) {
  ref.listen<String?>(error, (previous, next) {
    if (next != null && next != previous) showErrorSnackBar(context, next);
  });
}
