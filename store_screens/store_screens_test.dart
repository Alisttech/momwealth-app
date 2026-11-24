// Renders the real app screens with demo data, for the Google Play / App Store listing.
// Run (CI does this): flutter test store_screens --update-goldens --dart-define=LOANS_ENABLED=false
// Output: store_screens/goldens/*.png at 1080 x 2340.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momwealth/models.dart';
import 'package:momwealth/screens/account.dart';
import 'package:momwealth/screens/groups.dart';
import 'package:momwealth/screens/savings.dart';
import 'package:momwealth/screens/shell.dart';
import 'package:momwealth/services/session.dart';
import 'package:momwealth/theme.dart';
import 'package:provider/provider.dart';

// ignore: subtype_of_sealed_class
class FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  FakeDoc(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  bool get exists => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const me = 'demo-adaeze';
final now = DateTime.now();
Timestamp ago(int days) => Timestamp.fromDate(now.subtract(Duration(days: days)));
Timestamp ahead(int days) => Timestamp.fromDate(now.add(Duration(days: days)));
int naira(int n) => n * 100; // to kobo

Session demoSession() {
  final s = Session.preview(me);
  s.profile = Profile.fromMap(me, {
    'display_name': 'Adaeze Okafor', 'firstName': 'Adaeze', 'lastName': 'Okafor', 'email': 'adaeze.okafor@example.com',
    'phone_number': '08031234567', 'kycStatus': 'verified', 'memberNo': 'MW0482913', 'walletBalance': naira(1025000),
    'Gender': 'Female', 'DOB': '14/03/1988', 'Address': '12 Allen Avenue', 'City': 'Ikeja', 'State': 'Lagos',
    'maritalStatus': 'Married', 'employmentStatus': 'Business owner', 'occupation': 'Fashion designer',
    'bvnLast4': '4821', 'ninLast4': '7730', 'created_time': ago(120),
  });
  s.plans = [
    FakeDoc('school', {'savingsName': 'School fees 2027', 'planType': 'target', 'frequency': 'monthly', 'status': 'active',
      'savedKobo': naira(270000), 'targetKobo': naira(600000), 'contributionKobo': naira(45000), 'totalContributionsKobo': naira(270000),
      'contributionsCount': 6, 'startDate': ago(180), 'maturityDate': ahead(240), 'nextContributionDue': ahead(5), 'createdAt': ago(180)}),
    FakeDoc('shop', {'savingsName': 'New shop equipment', 'planType': 'target', 'frequency': 'weekly', 'status': 'active',
      'savedKobo': naira(420000), 'targetKobo': naira(1500000), 'contributionKobo': naira(30000), 'totalContributionsKobo': naira(420000),
      'contributionsCount': 14, 'startDate': ago(98), 'maturityDate': ahead(300), 'nextContributionDue': ahead(2), 'createdAt': ago(98)}),
    FakeDoc('xmas', {'savingsName': 'Christmas 2026', 'planType': 'target', 'frequency': 'monthly', 'status': 'active',
      'savedKobo': naira(150000), 'targetKobo': naira(150000), 'contributionKobo': naira(15000), 'totalContributionsKobo': naira(150000),
      'contributionsCount': 10, 'startDate': ago(300), 'maturityDate': ahead(30), 'createdAt': ago(300)}),
    FakeDoc('general', {'savingsName': 'General Savings', 'planType': 'general', 'frequency': 'flexible', 'status': 'active', 'isDefault': true,
      'savedKobo': naira(185000), 'totalContributionsKobo': naira(185000), 'contributionsCount': 9, 'createdAt': ago(120)}),
  ].map(SavingsPlan.fromDoc).toList();
  Map<String, dynamic> dep(String plan, String name, int amount, int days, String method) => {
        'account': 'savings', 'type': 'savings_contribution', 'direction': 'credit', 'status': 'successful', 'planId': plan, 'planName': name,
        'amount': naira(amount), 'createdAt': ago(days), 'paymentMethod': method, 'Description': 'Savings payment', 'reference': 'MW-$plan-$days'};
  s.ledger = [
    FakeDoc('l1', dep('shop', 'New shop equipment', 30000, 1, 'transfer')),
    FakeDoc('l2', dep('school', 'School fees 2027', 45000, 4, 'card')),
    FakeDoc('l3', {'account': 'ajo', 'type': 'ajo_contribution', 'direction': 'credit', 'status': 'successful', 'ajoId': 'ajo', 'planName': 'Balogun Market Ajo',
      'amount': naira(20000), 'createdAt': ago(6), 'paymentMethod': 'ussd', 'Description': 'Ajo contribution, round 3', 'reference': 'MW-ajo-3'}),
    FakeDoc('l4', {'account': 'group', 'type': 'group_contribution', 'direction': 'credit', 'status': 'successful', 'groupId': 'land', 'planName': 'Okafor Family Land Fund',
      'amount': naira(50000), 'createdAt': ago(9), 'paymentMethod': 'transfer', 'Description': 'Group contribution', 'reference': 'MW-land-9'}),
    FakeDoc('l5', dep('general', 'General Savings', 25000, 12, 'card')),
    FakeDoc('l6', dep('shop', 'New shop equipment', 30000, 8, 'transfer')),
  ].map(LedgerEntry.fromDoc).toList();
  Map<String, dynamic> member(String name, String role, int contributed) => {'name': name, 'role': role, 'contributedKobo': naira(contributed), 'withdrawnKobo': 0, 'heldKobo': 0};
  s.groups = [
    FakeDoc('land', {'name': 'Okafor Family Land Fund', 'description': 'Buying the family plot in Ibeju-Lekki', 'frequency': 'monthly', 'withdrawalRule': 'maturity',
      'joinCode': 'LAND24', 'createdByName': 'Adaeze Okafor', 'status': 'active', 'targetKobo': naira(5000000), 'contributionKobo': naira(50000),
      'savedKobo': naira(2150000), 'maxMembers': 10, 'maturityDate': ahead(400), 'createdAt': ago(200),
      'memberIds': [me, 'u2', 'u3', 'u4', 'u5', 'u6'],
      'members': {me: member('Adaeze Okafor', 'admin', 450000), 'u2': member('Chidi Okafor', 'member', 400000), 'u3': member('Ngozi Eze', 'member', 350000),
        'u4': member('Emeka Okafor', 'member', 350000), 'u5': member('Ifeoma Nwosu', 'member', 300000), 'u6': member('Obinna Okafor', 'member', 300000)}}),
  ].map(SavingsGroup.fromDoc).toList();
  final order = [ 'u7', 'u8', me, 'u9', 'u10', 'u11', 'u12', 'u13'];
  final names = {me: 'Adaeze Okafor', 'u7': 'Funke Adeyemi', 'u8': 'Bisi Lawal', 'u9': 'Kemi Bello', 'u10': 'Tolu Ajayi', 'u11': 'Halima Musa', 'u12': 'Grace Udoh', 'u13': 'Yemi Ogun'};
  final paidAll = {for (final u in order) u: naira(20000)};
  s.ajos = [
    FakeDoc('ajo', {'name': 'Balogun Market Ajo', 'frequency': 'weekly', 'joinCode': 'AJO8BM', 'createdBy': 'u7', 'createdByName': 'Funke Adeyemi', 'status': 'active',
      'contributionKobo': naira(20000), 'maxMembers': 8, 'currentCycleIndex': 2, 'startDate': ago(15), 'createdAt': ago(25),
      'memberIds': order, 'payoutOrder': order,
      'members': {for (final u in order) u: {'name': names[u], 'role': u == 'u7' ? 'admin' : 'member'}},
      'paid': {'0': paidAll, '1': paidAll, '2': {me: naira(20000), 'u7': naira(20000), 'u8': naira(20000), 'u9': naira(20000), 'u10': naira(20000)}},
      'payouts': {'0': {'uid': 'u7', 'amountKobo': naira(160000), 'reference': 'GTB-110', 'paidAt': ago(14)},
        '1': {'uid': 'u8', 'amountKobo': naira(160000), 'reference': 'GTB-221', 'paidAt': ago(7)}}}),
  ].map(AjoCircle.fromDoc).toList();
  s.notifications = [
    FakeDoc('n1', {'title': 'Payment received', 'body': '₦30,000.00 added to New shop equipment.', 'type': 'deposit', 'read': false, 'createdAt': ago(1)}),
    FakeDoc('n2', {'title': 'Ajo round 3', 'body': 'Your ₦20,000.00 for Balogun Market Ajo is recorded.', 'type': 'ajo', 'read': false, 'createdAt': ago(6)}),
  ].map(AppNotification.fromDoc).toList();
  s.settings = {'appDownloadUrl': 'https://app.momrehoboth.com'};
  return s;
}

Future<void> loadFonts() async {
  final dm = FontLoader('DMSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    dm.addFont(rootBundle.load('assets/fonts/DMSans-$w.ttf'));
  }
  await dm.load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

Future<void> shoot(WidgetTester tester, String name, Widget home, {int tab = 0, Session? session}) async {
  final s = session ?? demoSession();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  tester.view.padding = const FakeViewPadding(top: 70, bottom: 40);
  tester.view.viewPadding = const FakeViewPadding(top: 70, bottom: 40);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<Session>.value(
    value: s,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: RepaintBoundary(key: const ValueKey('shot'), child: home)),
  ));
  if (tab != 0) {
    AppShell.shellKey.currentState!.go(tab);
  }
  await tester.pump();
  // Decode every image on screen before capturing.
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      final w = el.widget as Image;
      await precacheImage(w.image, el);
    }
  });
  await tester.pumpAndSettle();
  await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(loadFonts);
  testWidgets('01 home', (t) => shoot(t, '01-home', AppShell(key: AppShell.shellKey)));
  testWidgets('02 savings', (t) => shoot(t, '02-savings', AppShell(key: AppShell.shellKey), tab: 1));
  testWidgets('03 plan', (t) => shoot(t, '03-plan', const PlanScreen(planId: 'school')));
  testWidgets('04 groups', (t) => shoot(t, '04-groups', AppShell(key: AppShell.shellKey), tab: 2));
  testWidgets('05 ajo', (t) => shoot(t, '05-ajo', const AjoScreen(ajoId: 'ajo')));
  testWidgets('06 group', (t) => shoot(t, '06-group', const GroupScreen(groupId: 'land')));
  testWidgets('07 card', (t) => shoot(t, '07-card', const AccountCardScreen()));
  // Keep the analyzer happy about dart:io (used by CI to list outputs).
  test('outputs folder', () => expect(Directory('store_screens').existsSync(), isTrue));
}
