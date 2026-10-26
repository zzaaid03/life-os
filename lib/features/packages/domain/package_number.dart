/// Tracking and order numbers are the only identity key for a package, so the
/// model's spacing, casing and "#" / "No." decoration must never make one
/// package look like two.
library;

final _leadingLabel = RegExp(
  r'^(?:no|nr)(?:\.\s*|\s+|(?=\d))',
  caseSensitive: false,
);
final _leadingHash = RegExp(r'^#\s*');
final _whitespace = RegExp(r'\s+');

/// Normalizes a tracking or order number: strips a leading "No." / "No" /
/// "Nr." label and a leading "#", drops all whitespace, uppercases, and caps
/// at the 60 character column limit. Returns null for anything that is not
/// text or a number, or that ends up empty.
String? normalizePackageNumber(Object? raw) {
  final text = raw is num ? raw.toString() : raw;
  if (text is! String) return null;
  final cleaned = text
      .trim()
      .replaceFirst(_leadingLabel, '')
      .replaceFirst(_leadingHash, '')
      .replaceAll(_whitespace, '')
      .toUpperCase();
  if (cleaned.isEmpty) return null;
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}
