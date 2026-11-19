import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper over the backend's callable Cloud Functions (backend/functions/src).
/// Every money action goes through these; the app never writes balances itself.
class Api {
  static final _fns = FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    final res = await _fns.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 60))).call(data ?? {});
    final v = res.data;
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  static Future<void> memberSetup({required String displayName, required String phone}) =>
      call('memberSetup', {'displayName': displayName, 'phone': phone});

  /// target: {'planId': id} | {'groupId': id} | {'ajoId': id}. Returns {reference, checkoutUrl}.
  static Future<Map<String, dynamic>> startPayment(Map<String, dynamic> target, int? amountKobo) =>
      call('initiateSavingsPayment', {...target, if (amountKobo != null) 'amountKobo': amountKobo, 'returnTo': 'app'});

  static Future<Map<String, dynamic>> confirmPayment(String reference) => call('confirmSavingsPayment', {'reference': reference});
}

/// Turns backend and network errors into a sentence a member can act on.
String friendlyError(Object e) {
  if (e is FirebaseFunctionsException) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return "We couldn't reach MOM Wealth. Check your connection and try again.";
      case 'internal':
        return 'Something went wrong on our side. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
  final s = e.toString();
  const auth = {
    'invalid-credential': 'Email or password is incorrect.',
    'wrong-password': 'Email or password is incorrect.',
    'user-not-found': 'No account with this email.',
    'email-already-in-use': 'An account with this email already exists. Sign in instead.',
    'weak-password': 'Use a password of at least 6 characters.',
    'invalid-email': 'Enter a valid email address.',
    'too-many-requests': 'Too many attempts. Please wait a few minutes and try again.',
    'network-request-failed': 'No internet connection. Check your connection and try again.',
    'requires-recent-login': 'For your security, please sign out and sign in again, then try once more.',
  };
  for (final k in auth.keys) {
    if (s.contains(k)) return auth[k]!;
  }
  return 'Something went wrong. Please try again.';
}
