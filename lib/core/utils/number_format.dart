/// Number formatting shared by user-facing text.
library;

/// Formats [n] with a comma between thousands, e.g. 2259 -> "2,259".
String formatThousands(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
