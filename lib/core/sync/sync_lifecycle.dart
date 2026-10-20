/// Runs a callback when the app returns to the foreground (native only).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Calls [onResumed] each time the app comes back to the foreground.
///
/// Does nothing on web, where tasks are read and written remotely.
class SyncLifecycle {
  /// Starts listening. Call [dispose] to stop.
  SyncLifecycle({required VoidCallback onResumed})
    : _listener = kIsWeb ? null : AppLifecycleListener(onResume: onResumed);

  final AppLifecycleListener? _listener;

  /// Stops listening.
  void dispose() => _listener?.dispose();
}
