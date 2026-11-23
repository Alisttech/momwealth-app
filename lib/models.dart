// Data models for the Firestore collections the backend writes. All money is in kobo (int).
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _str(dynamic v) => v == null ? '' : '$v';
DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}

String _refId(dynamic v) => v is DocumentReference ? v.id : _str(v);

class Profile {
  final String uid, name, email, phone, kycStatus, kycLastError;
  final String first, middle, last, dob, gender, maritalStatus, address, city, state;
  final String employmentStatus, occupation, employer, bvnLast4, ninLast4, photoUrl;
  final int walletBalance, withdrawalHold, loanOutstanding;
  final DateTime? createdAt, phoneChangedAt;
  final Map<String, dynamic>? virtualAccount;
  Profile.fromMap(this.uid, Map<String, dynamic> d)
      : name = _str(d['display_name']),
        email = _str(d['email']),
        phone = _str(d['phone_number']),
        kycStatus = _str(d['kycStatus']),
        kycLastError = _str(d['kycLastError']),
        first = _str(d['firstName']),
        middle = _str(d['middleName']),
        last = _str(d['lastName']),
        dob = _str(d['DOB']),
        gender = _str(d['Gender']),
        maritalStatus = _str(d['maritalStatus']),
        address = _str(d['Address']),
        city = _str(d['City']),
        state = _str(d['State']),
        employmentStatus = _str(d['employmentStatus']),
        occupation = _str(d['occupation']),
        employer = _str(d['employer']),
        bvnLast4 = _str(d['bvnLast4']),
        ninLast4 = _str(d['ninLast4']),
        photoUrl = _str(d['photo_url']),
        walletBalance = _int(d['walletBalance']),
        withdrawalHold = _int(d['withdrawalHold']),
        loanOutstanding = _int(d['loanOutstanding']),
        createdAt = _date(d['created_time']),
        phoneChangedAt = _date(d['phoneChangedAt']),
        virtualAccount = d['virtualAccount'] is Map ? Map<String, dynamic>.from(d['virtualAccount']) : null;
  int get available => math.max(0, walletBalance - withdrawalHold);
  bool get verified => kycStatus == 'verified';
  String get firstName {
    if (first.trim().isNotEmpty) return first.trim();
    return name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
  }
  String get accountNumber => _str(virtualAccount?['accountNumber']);
  String get accountBank => _str(virtualAccount?['bankName']).isEmpty ? 'GTBank' : _str(virtualAccount?['bankName']);
  String get accountName => _str(virtualAccount?['accountName']).isEmpty ? name : _str(virtualAccount?['accountName']);
  bool get hasAccount => accountNumber.isNotEmpty;
}

class SavingsPlan {
  final String id, name, planType, frequency, status;
  final int savedKobo, heldKobo, targetKobo, contributionKobo, totalContributionsKobo, contributionsCount;
  final bool isDefault;
  final DateTime? startDate, maturityDate, nextContributionDue, createdAt;
  SavingsPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        name = _str(doc.data()!['savingsName']),
        planType = _str(doc.data()!['planType']),
        frequency = _str(doc.data()!['frequency']).isEmpty ? 'flexible' : _str(doc.data()!['frequency']),
        status = _str(doc.data()!['status']).isEmpty ? 'active' : _str(doc.data()!['status']),
        savedKobo = _int(doc.data()!['savedKobo']),
        heldKobo = _int(doc.data()!['heldKobo']),
        targetKobo = _int(doc.data()!['targetKobo']),
        contributionKobo = _int(doc.data()!['contributionKobo']),
        totalContributionsKobo = _int(doc.data()!['totalContributionsKobo']),
        contributionsCount = _int(doc.data()!['contributionsCount']),
        isDefault = doc.data()!['isDefault'] == true,
        startDate = _date(doc.data()!['startDate']),
        maturityDate = _date(doc.data()!['maturityDate']),
        nextContributionDue = _date(doc.data()!['nextContributionDue']),
        createdAt = _date(doc.data()!['createdAt']);
  bool get isTarget => planType == 'target' && targetKobo > 0;
  int get available => math.max(0, savedKobo - heldKobo);
  int get percent => targetKobo > 0 ? ((savedKobo / targetKobo) * 100).clamp(0, 100).round() : 0;
}

class LedgerEntry {
  final String id, account, type, direction, status, reference, description, channel, paymentMethod, planName;
  final String? planId, groupId, ajoId, relatedId;
  final int amount;
  final DateTime? createdAt;
  LedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        account = _str(doc.data()!['account']).isEmpty ? 'savings' : _str(doc.data()!['account']),
        type = _str(doc.data()!['type']),
        direction = _str(doc.data()!['direction']),
        status = _str(doc.data()!['status']).isEmpty ? 'successful' : _str(doc.data()!['status']),
        reference = _str(doc.data()!['reference']),
        description = _str(doc.data()!['Description']),
        channel = _str(doc.data()!['channel']),
        paymentMethod = _str(doc.data()!['paymentMethod']),
        planName = _str(doc.data()!['planName']),
        planId = doc.data()!['planId'] as String?,
        groupId = doc.data()!['groupId'] as String?,
        ajoId = doc.data()!['ajoId'] as String?,
        relatedId = doc.data()!['relatedId'] as String?,
        amount = _int(doc.data()!['amount']),
        createdAt = _date(doc.data()!['createdAt']);
}

class Payment {
  final String id, reference, kind, status, planName, paymentMethod;
  final String? planId, groupId, ajoId, creditedPlanId;
  final int amountKobo;
  final bool credited;
  final DateTime? createdAt;
  Payment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        reference = _str(doc.data()!['reference']),
        kind = _str(doc.data()!['kind']).isEmpty ? 'plan' : _str(doc.data()!['kind']),
        status = _str(doc.data()!['status']),
        planName = _str(doc.data()!['planName']),
        paymentMethod = _str(doc.data()!['paymentMethod']),
        planId = doc.data()!['planId'] as String?,
        groupId = doc.data()!['groupId'] as String?,
        ajoId = doc.data()!['ajoId'] as String?,
        creditedPlanId = doc.data()!['creditedPlanId'] as String?,
        amountKobo = _int(doc.data()!['amountKobo']),
        credited = doc.data()!['credited'] == true,
        createdAt = _date(doc.data()!['createdAt']);
}

class BankDetails {
  final String bank, accountNumber, accountName;
  const BankDetails(this.bank, this.accountNumber, this.accountName);
  factory BankDetails.fromMap(dynamic m) {
    final d = m is Map ? m : const {};
    return BankDetails(_str(d['bank']), _str(d['accountNumber']), _str(d['accountName']));
  }
  Map<String, String> toMap() => {'bank': bank, 'accountNumber': accountNumber, 'accountName': accountName};
  bool get isSet => accountNumber.length == 10;
}

class Withdrawal {
  final String id, status, planName, reason, failureReason, paymentReference;
  final String? planId, groupId;
  final int amount;
  final BankDetails bank;
  final DateTime? createdAt;
  Withdrawal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        status = _str(doc.data()!['status']),
        planName = _str(doc.data()!['planName']),
        reason = _str(doc.data()!['reason']),
        failureReason = _str(doc.data()!['failureReason']),
        paymentReference = _str(doc.data()!['paymentReference']),
        planId = doc.data()!['planId'] as String?,
        groupId = doc.data()!['groupId'] as String?,
        amount = _int(doc.data()!['amount']),
        bank = BankDetails.fromMap(doc.data()!['destinationBank']),
        createdAt = _date(doc.data()!['createdAt']);
  bool get isOpen => status == 'pending' || status == 'approved';
}

class LoanMessage {
  final String from, text;
  final DateTime? at;
  LoanMessage(Map m)
      : from = _str(m['from']),
        text = _str(m['text']),
        at = _date(m['at']);
}

class Loan {
  final String id, status, purpose, notes, rejectionReason;
  final int amount, requestedAmount, tenureMonths, totalRepayable, interest, monthly, outstanding, amountRepaid, nextDue, overdueAmount;
  final double ratePctPerMonth;
  final bool hasOverdue;
  final DateTime? createdAt, disbursedAt, nextDueDate;
  final List<LoanMessage> messages;
  Loan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        status = _str(doc.data()!['status']),
        purpose = _str(doc.data()!['purpose']),
        notes = _str(doc.data()!['notes']),
        rejectionReason = _str(doc.data()!['rejectionReason']),
        amount = _int(doc.data()!['amount']),
        requestedAmount = _int(doc.data()!['requestedAmount']),
        tenureMonths = _int(doc.data()!['tenureMonths']),
        totalRepayable = _int(doc.data()!['totalRepayable']),
        interest = _int(doc.data()!['interest']),
        monthly = _int(doc.data()!['monthly']),
        outstanding = _int(doc.data()!['outstanding']),
        amountRepaid = _int(doc.data()!['amountRepaid']),
        nextDue = _int(doc.data()!['nextDue']),
        overdueAmount = _int(doc.data()!['overdueAmount']),
        ratePctPerMonth = (doc.data()!['ratePctPerMonth'] as num?)?.toDouble() ?? 0,
        hasOverdue = doc.data()!['hasOverdue'] == true,
        createdAt = _date(doc.data()!['createdAt']),
        disbursedAt = _date(doc.data()!['disbursedAt']),
        nextDueDate = _date(doc.data()!['nextDueDate']),
        messages = ((doc.data()!['messages'] as List?) ?? const []).whereType<Map>().map(LoanMessage.new).toList();
  bool get isOpen => const ['submitted', 'under_review', 'info_requested', 'approved', 'active', 'defaulted'].contains(status);
  bool get isRunning => status == 'active' || status == 'defaulted';
}

class Instalment {
  final String id, loanId, status;
  final int number, amountDue, paidAmount;
  final DateTime? dueDate;
  Instalment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        loanId = _refId(doc.data()!['loanId']),
        status = _str(doc.data()!['status']),
        number = _int(doc.data()!['installmentNumber']),
        amountDue = _int(doc.data()!['amountDue']),
        paidAmount = _int(doc.data()!['paidAmount']),
        dueDate = _date(doc.data()!['dueDate']);
  bool get paid => paidAmount >= amountDue;
}

class GroupMember {
  final String uid, name, role;
  final int contributed, withdrawn, held;
  GroupMember(this.uid, Map m)
      : name = _str(m['name']),
        role = _str(m['role']),
        contributed = _int(m['contributedKobo']),
        withdrawn = _int(m['withdrawnKobo']),
        held = _int(m['heldKobo']);
  int get balance => contributed - withdrawn;
  int get available => balance - held;
}

class SavingsGroup {
  final String id, name, description, frequency, withdrawalRule, joinCode, createdByName, status;
  final int targetKobo, contributionKobo, savedKobo, heldKobo, maxMembers;
  final DateTime? maturityDate, createdAt;
  final List<String> memberIds;
  final Map<String, GroupMember> members;
  SavingsGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        name = _str(doc.data()!['name']),
        description = _str(doc.data()!['description']),
        frequency = _str(doc.data()!['frequency']),
        withdrawalRule = _str(doc.data()!['withdrawalRule']),
        joinCode = _str(doc.data()!['joinCode']),
        createdByName = _str(doc.data()!['createdByName']),
        status = _str(doc.data()!['status']),
        targetKobo = _int(doc.data()!['targetKobo']),
        contributionKobo = _int(doc.data()!['contributionKobo']),
        savedKobo = _int(doc.data()!['savedKobo']),
        heldKobo = _int(doc.data()!['heldKobo']),
        maxMembers = _int(doc.data()!['maxMembers']),
        maturityDate = _date(doc.data()!['maturityDate']),
        createdAt = _date(doc.data()!['createdAt']),
        memberIds = List<String>.from((doc.data()!['memberIds'] as List?) ?? const []),
        members = ((doc.data()!['members'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', GroupMember('$k', v is Map ? v : const {})));
  int get percent => targetKobo > 0 ? ((savedKobo / targetKobo) * 100).clamp(0, 100).round() : 0;
  bool get locked => withdrawalRule == 'maturity' && maturityDate != null && maturityDate!.isAfter(DateTime.now());
  GroupMember? member(String uid) => members[uid];
}

class AjoPayout {
  final String uid, reference;
  final int amountKobo;
  final DateTime? paidAt;
  AjoPayout(Map m)
      : uid = _str(m['uid']),
        reference = _str(m['reference']),
        amountKobo = _int(m['amountKobo']),
        paidAt = _date(m['paidAt']);
}

class AjoCircle {
  final String id, name, frequency, joinCode, createdBy, createdByName, status;
  final int contributionKobo, maxMembers, currentCycleIndex;
  final DateTime? startDate, createdAt;
  final List<String> memberIds, payoutOrder;
  final Map<String, Map> members;
  final Map<int, Map<String, int>> paid;
  final Map<int, AjoPayout> payouts;
  AjoCircle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        name = _str(doc.data()!['name']),
        frequency = _str(doc.data()!['frequency']),
        joinCode = _str(doc.data()!['joinCode']),
        createdBy = _str(doc.data()!['createdBy']),
        createdByName = _str(doc.data()!['createdByName']),
        status = _str(doc.data()!['status']),
        contributionKobo = _int(doc.data()!['contributionKobo']),
        maxMembers = _int(doc.data()!['maxMembers']),
        currentCycleIndex = _int(doc.data()!['currentCycleIndex']),
        startDate = _date(doc.data()!['startDate']),
        createdAt = _date(doc.data()!['createdAt']),
        memberIds = List<String>.from((doc.data()!['memberIds'] as List?) ?? const []),
        payoutOrder = List<String>.from((doc.data()!['payoutOrder'] as List?) ?? const []),
        members = ((doc.data()!['members'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', v is Map ? v : const {})),
        paid = ((doc.data()!['paid'] as Map?) ?? const {}).map((k, v) => MapEntry(
            int.tryParse('$k') ?? 0, (v is Map ? v : const {}).map((u, a) => MapEntry('$u', _int(a))))),
        payouts = ((doc.data()!['payouts'] as Map?) ?? const {}).map((k, v) => MapEntry(int.tryParse('$k') ?? 0, AjoPayout(v is Map ? v : const {})));

  int get rounds => payoutOrder.isNotEmpty ? payoutOrder.length : memberIds.length;
  int get pot => contributionKobo * rounds;
  String nameOf(String uid) => _str(members[uid]?['name']).isEmpty ? 'Member' : _str(members[uid]?['name']);
  String roleOf(String uid) => _str(members[uid]?['role']);

  DateTime dueDate(int i) {
    var d = startDate ?? DateTime.now();
    for (var k = 0; k < i; k++) {
      d = frequency == 'daily'
          ? d.add(const Duration(days: 1))
          : frequency == 'weekly'
              ? d.add(const Duration(days: 7))
              : DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
    }
    return d;
  }

  /// First round (from the current one) this member hasn't paid, or -1.
  int nextUnpaid(String uid) {
    for (var i = currentCycleIndex; i < payoutOrder.length; i++) {
      if (!(paid[i]?.containsKey(uid) ?? false)) return i;
    }
    return -1;
  }
}

class AjoBank {
  final String ajoId;
  final BankDetails bank;
  AjoBank.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : ajoId = _str(doc.data()!['ajoId']),
        bank = BankDetails.fromMap(doc.data()!['bank']);
}

class AppNotification {
  final String id, title, body, type;
  final bool read;
  final DateTime? createdAt;
  AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        title = _str(doc.data()!['title']),
        body = _str(doc.data()!['body']),
        type = _str(doc.data()!['type']),
        read = doc.data()!['read'] == true,
        createdAt = _date(doc.data()!['createdAt']);
}

class SupportTicket {
  final String id, ticketNo, category, title, description, status, resolution;
  final DateTime? createdAt, completedAt;
  SupportTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        ticketNo = _str(doc.data()!['ticketNo']),
        category = _str(doc.data()!['category']),
        title = _str(doc.data()!['title']),
        description = _str(doc.data()!['description']),
        status = _str(doc.data()!['status']).isEmpty ? 'open' : _str(doc.data()!['status']),
        resolution = _str(doc.data()!['resolution']),
        createdAt = _date(doc.data()!['createdAt']),
        completedAt = _date(doc.data()!['completedAt']);
  bool get done => status == 'completed' || status == 'closed';
}

class VendorOffer {
  final String id, vendor, title, details, code, link, category;
  final bool active;
  VendorOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        vendor = _str(doc.data()!['vendor']),
        title = _str(doc.data()!['title']),
        details = _str(doc.data()!['details']),
        code = _str(doc.data()!['code']),
        link = _str(doc.data()!['link']),
        category = _str(doc.data()!['category']),
        active = doc.data()!['active'] != false;
}
