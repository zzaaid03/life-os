/// Pure spending math for subscriptions.
///
/// No Riverpod, no I/O, no clock. Everything here is a plain function over
/// [Subscription] rows so it can be unit tested directly.
///
/// The monthly equivalent is DERIVED, never stored, so changing the formula
/// is a code change and not a migration.
library;

import 'package:life_os/features/subscriptions/data/models/subscription.dart';

/// Weeks in a year, used to convert a weekly charge to a monthly figure.
///
/// 52 rather than 365/7: a weekly charge lands 52 times in a year, and the
/// fractional 53rd week is not money anyone is actually billed.
const int _weeksPerYear = 52;

/// Converts [subscription]'s charge to what it costs per month, in cents.
///
/// Rounds to the nearest cent. A yearly charge of 10.00 is 83c a month, not
/// 83.333c, because a total has to be payable in real money.
int monthlyEquivalentCents(Subscription subscription) {
  final amount = subscription.amountCents;
  switch (subscription.cycle) {
    case BillingCycle.weekly:
      return (amount * _weeksPerYear / 12).round();
    case BillingCycle.monthly:
      return amount;
    case BillingCycle.quarterly:
      return (amount / 3).round();
    case BillingCycle.yearly:
      return (amount / 12).round();
  }
}

/// Converts [subscription]'s charge to what it costs per year, in cents.
int yearlyEquivalentCents(Subscription subscription) {
  final amount = subscription.amountCents;
  switch (subscription.cycle) {
    case BillingCycle.weekly:
      return amount * _weeksPerYear;
    case BillingCycle.monthly:
      return amount * 12;
    case BillingCycle.quarterly:
      return amount * 4;
    case BillingCycle.yearly:
      return amount;
  }
}

/// Total monthly spend per currency, in cents.
///
/// Grouped by currency and NEVER converted between them: this app has no
/// exchange-rate source, and inventing one would put a made-up number on a
/// screen about the user's real money. Cancelled and soft-deleted rows are
/// excluded.
///
/// Returns an empty map when nothing counts, so a caller can distinguish
/// "no subscriptions" from "zero spend".
Map<String, int> monthlyTotalsByCurrency(List<Subscription> subscriptions) {
  final totals = <String, int>{};
  for (final subscription in subscriptions) {
    if (!subscription.countsTowardTotals) continue;
    final currency = subscription.currency.toUpperCase();
    totals[currency] =
        (totals[currency] ?? 0) + monthlyEquivalentCents(subscription);
  }
  return totals;
}

/// The subscriptions charging within [days] of [from], soonest first.
///
/// Rows with no known next charge date are excluded rather than guessed at.
/// Anything already in the past is excluded too: a stale date means the
/// charge has happened, not that it is imminent.
List<Subscription> chargingSoon(
  List<Subscription> subscriptions,
  DateTime from, {
  int days = 7,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = start.add(Duration(days: days));

  final soon = subscriptions.where((s) {
    if (!s.countsTowardTotals) return false;
    final due = s.nextChargeDate;
    if (due == null) return false;
    final day = DateTime(due.year, due.month, due.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  soon.sort((a, b) => a.nextChargeDate!.compareTo(b.nextChargeDate!));
  return soon;
}

/// The Postgres INTEGER ceiling, which is the storage limit on `amount_cents`.
const int maxAmountCents = 2147483647;

/// Parses a decimal amount string (e.g. `12.99`) into integer cents by string
/// manipulation, never `double * 100`, which is fragile and the whole reason
/// the schema stores cents instead of a float.
///
/// Returns null for anything that is not a plain non-negative number with at
/// most two decimal places, and for anything too large to store. Null means
/// "this is not an amount", so every caller has to decide what to do about
/// that rather than receiving a plausible wrong number.
///
/// This is the ONLY amount parser in the app. It is shared by the editor's
/// text field and by the inbox scan, which reads amounts a model copied out
/// of an email: both feed the same column, so both must agree on what is
/// storable, down to the overflow ceiling.
int? parseAmountCents(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(trimmed);
  if (match == null) return null;
  // tryParse, not parse: the regex happily matches thirty digits, and
  // int.parse would throw straight out of a text field's validator.
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
  // Anything past the column's ceiling parses cleanly here and then fails on
  // insert with an overflow the user could make no sense of. Reject it while
  // it is still a form error.
  if (whole > maxAmountCents ~/ 100) return null;
  return whole * 100 + fraction;
}

/// Formats [cents] as a plain amount string, e.g. `12.00`.
///
/// Deliberately returns no currency symbol: the code is stored per row and
/// callers render it alongside, which avoids mapping every possible ISO code
/// to a glyph and getting it subtly wrong.
String formatAmount(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final major = absolute ~/ 100;
  final minor = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$major.$minor';
}
