import 'package:flutter_test/flutter_test.dart';
import 'package:momwealth/format.dart';
import 'package:momwealth/widgets.dart';

void main() {
  test('naira formats kobo', () {
    expect(naira(1234567), '₦12,345.67');
    expect(naira(500000, decimals: false), '₦5,000');
  });
  test('parseKobo reads typed amounts', () {
    expect(parseKobo('12,000.50'), 1200050);
    expect(parseKobo('0'), null);
    expect(parseKobo(''), null);
  });
  test('amount field formatting', () {
    expect(formatAmountField(1250000), '12,500');
    expect(formatAmountField(1250050), '12,500.50');
  });
}
