/// Helpers for reading errors thrown by `supabase.functions.invoke`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

const _fallbackAiLimitMessage =
    "You've used today's AI allowance. It resets at midnight UTC.";

/// The plain message to show when [e] is the daily AI limit error, or null
/// for any other error.
///
/// Edge functions answer HTTP 429 with `{"error":"daily_ai_limit","detail":...}`
/// and `invoke` throws a [FunctionException] for it.
String? aiLimitMessage(Object e) {
  if (e is! FunctionException || e.status != 429) return null;
  final details = e.details;
  if (details is! Map || details['error'] != 'daily_ai_limit') return null;
  final detail = details['detail'];
  return detail is String && detail.trim().isNotEmpty
      ? detail
      : _fallbackAiLimitMessage;
}
