String formatWithCommas(num value) {
  final str = value.round().toString();
  final isNegative = str.startsWith('-');
  final digits = isNegative ? str.substring(1) : str;
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (isNegative ? '-' : '') + buffer.toString();
}
