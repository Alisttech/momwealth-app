import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00', 'en_US');
final _money0 = NumberFormat('#,##0', 'en_US');

/// Kobo -> "₦12,345.00"
String naira(int kobo, {bool decimals = true}) {
  final v = kobo / 100;
  final neg = v < 0 ? '-' : '';
  final s = decimals || v % 1 != 0 ? _money.format(v.abs()) : _money0.format(v.abs());
  return '$neg₦$s';
}

/// "12,000.50" or "12000" -> kobo, or null when not a positive amount.
int? parseKobo(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
  final v = double.tryParse(cleaned);
  if (v == null || v <= 0) return null;
  return (v * 100).round();
}

String formatDay(DateTime? d) => d == null ? '—' : DateFormat('d MMM y').format(d);
String formatDayTime(DateTime? d) => d == null ? '' : DateFormat('d MMM, HH:mm').format(d);
String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

const frequencyLabel = {'flexible': 'Flexible', 'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
const frequencyEvery = {'daily': 'day', 'weekly': 'week', 'monthly': 'month', 'flexible': 'any time'};

const methodLabel = {
  'card': 'Card', 'bank': 'Bank', 'ussd': 'USSD', 'transfer': 'Bank transfer', 'virtual_account': 'Bank transfer',
  'bank_transfer': 'Bank transfer', 'cash': 'Cash', 'manual': 'Recorded by MOM',
};

const nigerianBanks = [
  'Access Bank', 'Citibank', 'Ecobank', 'Fidelity Bank', 'First Bank', 'FCMB', 'Globus Bank', 'GTBank', 'Heritage Bank', 'Jaiz Bank',
  'Keystone Bank', 'Kuda', 'Moniepoint', 'OPay', 'PalmPay', 'Parallex Bank', 'Polaris Bank', 'Providus Bank', 'Stanbic IBTC',
  'Standard Chartered', 'Sterling Bank', 'SunTrust Bank', 'Titan Trust Bank', 'Union Bank', 'UBA', 'Unity Bank', 'VFD Microfinance Bank',
  'Wema Bank', 'Zenith Bank', 'Other',
];
