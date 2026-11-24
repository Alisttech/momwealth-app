import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api.dart';

/// Live view of everything the signed-in member can see. Screens read from this and rebuild
/// when Firestore changes (payments confirmed, withdrawals approved, and so on).
class Session extends ChangeNotifier {
  Session() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription> _subs = [];
  final Set<String> _loaded = {};

  User? user;
  bool authResolved = false;
  Profile? profile;
  List<SavingsPlan> plans = [];
  List<LedgerEntry> ledger = [];
  List<Payment> payments = [];
  List<Withdrawal> withdrawals = [];
  List<Loan> loans = [];
  List<Instalment> instalments = [];
  List<SavingsGroup> groups = [];
  List<AjoCircle> ajos = [];
  List<AjoBank> ajoBanks = [];
  List<AppNotification> notifications = [];
  List<SupportTicket> tickets = [];
  List<VendorOffer> offers = [];
  /// config/settings (society rules set by MOM; readable by members).
  Map<String, dynamic> settings = {};
  /// Link added to shared invites, e.g. the App Store / Play Store page or MOM's website.
  String get appLink => '${settings['appDownloadUrl'] ?? ''}'.trim();
  int get unreadCount => notifications.where((n) => !n.read).length;

  bool get ready => user != null && const ['profile', 'plans', 'ledger', 'payments', 'withdrawals', 'loans', 'groups', 'ajos'].every(_loaded.contains);
  String get uid => user?.uid ?? '';

  /// True when the phone number given at sign-up already belongs to another account (so it wasn't saved).
  bool phoneTaken = false;
  /// Values captured at sign-up and sent to memberSetup on first sign-in.
  String? pendingName, pendingPhone;

  Future<void> _onAuth(User? u) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _loaded.clear();
    user = u;
    profile = null;
    plans = [];
    ledger = [];
    payments = [];
    withdrawals = [];
    loans = [];
    instalments = [];
    groups = [];
    ajos = [];
    ajoBanks = [];
    notifications = [];
    phoneTaken = false;
    tickets = [];
    offers = [];
    authResolved = true;
    notifyListeners();
    if (u == null) return;
    try {
      final r = await Api.memberSetup(displayName: pendingName ?? u.displayName ?? '', phone: pendingPhone ?? '', newSignup: pendingName != null);
      if (r['phoneTaken'] == true) {
        phoneTaken = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('memberSetup failed: $e');
    }
    pendingName = null;
    pendingPhone = null;
    _listen(u.uid);
  }

  void _mark(String key) {
    _loaded.add(key);
    notifyListeners();
  }

  void _listen(String uid) {
    Query<Map<String, dynamic>> mine(String c) => _db.collection(c).where('uid', isEqualTo: uid);
    Query<Map<String, dynamic>> memberOf(String c) => _db.collection(c).where('memberIds', arrayContains: uid);
    int newest(DateTime? a, DateTime? b) => (b ?? DateTime(2000)).compareTo(a ?? DateTime(2000));
    void onErr(String key, Object e) {
      debugPrint('$key listener: $e');
      _mark(key);
    }

    _subs.add(_db.collection('users').doc(uid).snapshots().listen((d) {
      profile = Profile.fromMap(uid, d.data() ?? const {});
      _mark('profile');
    }, onError: (e) => onErr('profile', e)));
    _subs.add(mine('targetSavings').snapshots().listen((q) {
      plans = q.docs.map(SavingsPlan.fromDoc).where((p) => p.status != 'closed').toList()
        ..sort((a, b) => a.isDefault != b.isDefault ? (a.isDefault ? -1 : 1) : -newest(a.createdAt, b.createdAt));
      _mark('plans');
    }, onError: (e) => onErr('plans', e)));
    _subs.add(mine('walletTransactions').snapshots().listen((q) {
      ledger = q.docs.map(LedgerEntry.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('ledger');
    }, onError: (e) => onErr('ledger', e)));
    _subs.add(mine('squadPayments').snapshots().listen((q) {
      payments = q.docs.map(Payment.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('payments');
    }, onError: (e) => onErr('payments', e)));
    _subs.add(mine('payoutRequests').snapshots().listen((q) {
      withdrawals = q.docs.map(Withdrawal.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('withdrawals');
    }, onError: (e) => onErr('withdrawals', e)));
    _subs.add(mine('Loan').snapshots().listen((q) {
      loans = q.docs.map(Loan.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('loans');
    }, onError: (e) => onErr('loans', e)));
    _subs.add(mine('repayments').snapshots().listen((q) {
      instalments = q.docs.map(Instalment.fromDoc).toList()..sort((a, b) => a.number.compareTo(b.number));
      _mark('repayments');
    }, onError: (e) => onErr('repayments', e)));
    _subs.add(memberOf('savingsGroups').snapshots().listen((q) {
      groups = q.docs.map(SavingsGroup.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('groups');
    }, onError: (e) => onErr('groups', e)));
    _subs.add(memberOf('ajoPlans').snapshots().listen((q) {
      ajos = q.docs.map(AjoCircle.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('ajos');
    }, onError: (e) => onErr('ajos', e)));
    _subs.add(mine('ajoMembers').snapshots().listen((q) {
      ajoBanks = q.docs.map(AjoBank.fromDoc).toList();
      _mark('ajoBanks');
    }, onError: (e) => onErr('ajoBanks', e)));
    _subs.add(mine('notifications').snapshots().listen((q) {
      notifications = q.docs.map(AppNotification.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('notifications');
    }, onError: (e) => onErr('notifications', e)));
    _subs.add(mine('tickets').snapshots().listen((q) {
      tickets = q.docs.map(SupportTicket.fromDoc).toList()..sort((a, b) => newest(a.createdAt, b.createdAt));
      _mark('tickets');
    }, onError: (e) => onErr('tickets', e)));
    _subs.add(_db.collection('config').doc('settings').snapshots().listen((d) {
      settings = d.data() ?? {};
      notifyListeners();
    }, onError: (e) => debugPrint('settings listener: $e')));
    _subs.add(_db.collection('vendorOffers').snapshots().listen((q) {
      offers = q.docs.map(VendorOffer.fromDoc).where((o) => o.active).toList();
      _mark('offers');
    }, onError: (e) => onErr('offers', e)));
  }

  /// Marks every unread notification as read (members may only change `read`).
  Future<void> markAllRead() async {
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final n in unread) {
        batch.update(_db.collection('notifications').doc(n.id), {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllRead: $e');
    }
  }

  // ---- convenience lookups
  SavingsPlan? plan(String id) => plans.where((p) => p.id == id).firstOrNull;
  SavingsGroup? group(String id) => groups.where((g) => g.id == id).firstOrNull;
  AjoCircle? ajo(String id) => ajos.where((a) => a.id == id).firstOrNull;
  Payment? payment(String ref) => payments.where((p) => p.reference == ref).firstOrNull;
  Withdrawal? get openWithdrawal => withdrawals.where((w) => w.isOpen).firstOrNull;
  Loan? get currentLoan => loans.where((l) => l.isOpen).firstOrNull;
  List<SavingsGroup> get activeGroups => groups.where((g) => g.status == 'active').toList();
  BankDetails? bankForAjo(String ajoId) => ajoBanks.where((b) => b.ajoId == ajoId).firstOrNull?.bank;
  BankDetails? get lastBank =>
      ajoBanks.where((b) => b.bank.isSet).firstOrNull?.bank ?? withdrawals.where((w) => w.bank.isSet).firstOrNull?.bank;

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
