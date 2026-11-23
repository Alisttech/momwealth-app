import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';

const maritalOptions = ['Single', 'Married', 'Divorced', 'Widowed', 'Separated'];
const employmentOptions = ['Employed', 'Self-employed', 'Business owner', 'Unemployed', 'Student', 'Retired'];
const nigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo',
  'Ekiti', 'Enugu', 'FCT Abuja', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos',
  'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

/// Identity onboarding: four short steps, then Squad checks the BVN and creates the member's account number.
/// Shown after sign-up and to any member who isn't verified yet.
class KycFlow extends StatefulWidget {
  const KycFlow({super.key, this.onSubmitting, this.onFinished});
  /// Called when the member submits, so the app keeps this screen up to show the new account number.
  final VoidCallback? onSubmitting;
  final VoidCallback? onFinished;
  @override
  State<KycFlow> createState() => _KycFlowState();
}

class _KycFlowState extends State<KycFlow> {
  static const _draftKey = 'kycDraft';
  final _pages = PageController();
  int _step = 0;
  bool _done = false;
  String? _error;

  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  DateTime? _dob;
  String? _gender, _marital, _state, _employment;
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _occupation = TextEditingController();
  final _employer = TextEditingController();
  final _bvn = TextEditingController();
  final _nin = TextEditingController();
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<Session>().profile;
    if (p != null) {
      final parts = p.name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
      _first.text = p.first.isNotEmpty ? p.first : (parts.isNotEmpty ? parts.first : '');
      _last.text = p.last.isNotEmpty ? p.last : (parts.length > 1 ? parts.last : '');
      _middle.text = p.middle;
      _phone.text = p.phone;
      if (p.kycLastError.isNotEmpty && p.kycStatus == 'failed') _error = p.kycLastError;
    }
    _loadDraft();
  }

  // The draft (never the BVN or NIN) is kept on the phone so a member can stop and continue later.
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final d = Map<String, dynamic>.from(jsonDecode(raw));
      setState(() {
        for (final e in {'first': _first, 'middle': _middle, 'last': _last, 'phone': _phone, 'address': _address, 'city': _city, 'occupation': _occupation, 'employer': _employer}.entries) {
          final v = d[e.key];
          if (v is String && v.isNotEmpty) e.value.text = v;
        }
        _dob = DateTime.tryParse('${d['dob'] ?? ''}');
        _gender = d['gender'] as String?;
        _marital = d['marital'] as String?;
        _state = d['state'] as String?;
        _employment = d['employment'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode({
        'first': _first.text, 'middle': _middle.text, 'last': _last.text, 'phone': _phone.text, 'address': _address.text,
        'city': _city.text, 'occupation': _occupation.text, 'employer': _employer.text, 'dob': _dob?.toIso8601String(),
        'gender': _gender, 'marital': _marital, 'state': _state, 'employment': _employment,
      }));
    } catch (_) {}
  }

  String? _validate(int step) {
    switch (step) {
      case 0:
        if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) return 'Enter your first and last name exactly as on your BVN.';
        if (_dob == null) return 'Choose your date of birth.';
        if (_gender == null) return 'Choose your gender.';
        if (_marital == null) return 'Choose your marital status.';
      case 1:
        if (!RegExp(r'^0[789]\d{9}$').hasMatch(_phone.text.replaceAll(RegExp(r'\D'), ''))) return 'Enter your 11-digit phone number (the one linked to your BVN).';
        if (_address.text.trim().length < 5) return 'Enter your home address.';
        if (_city.text.trim().isEmpty) return 'Enter your city or town.';
        if (_state == null) return 'Choose your state.';
      case 2:
        if (_employment == null) return 'Choose your employment status.';
        if (const ['Employed', 'Self-employed', 'Business owner'].contains(_employment) && _occupation.text.trim().isEmpty) return 'Tell us your occupation.';
      case 3:
        if (_bvn.text.length != 11) return 'Your BVN is 11 digits.';
        if (_nin.text.length != 11) return 'Your NIN is 11 digits.';
        if (!_consent) return 'Tick the box to let MOM Wealth verify your details.';
    }
    return null;
  }

  void _next() {
    final err = _validate(_step);
    setState(() => _error = err);
    if (err != null) return;
    _saveDraft();
    FocusScope.of(context).unfocus();
    if (_step < 3) {
      setState(() => _step++);
      _pages.animateToPage(_step, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  }

  void _back() {
    setState(() {
      _error = null;
      _step--;
    });
    _pages.animateToPage(_step, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    final err = _validate(3);
    setState(() => _error = err);
    if (err != null) return;
    FocusScope.of(context).unfocus();
    widget.onSubmitting?.call();
    try {
      await Api.call('verifyBvnAndCreateAccount', {
        'firstName': _first.text.trim(),
        'middleName': _middle.text.trim(),
        'lastName': _last.text.trim(),
        'dob': isoDay(_dob!),
        'gender': _gender,
        'maritalStatus': _marital,
        'phone': _phone.text.replaceAll(RegExp(r'\D'), ''),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state,
        'employmentStatus': _employment,
        'occupation': _occupation.text.trim(),
        'employer': _employer.text.trim(),
        'bvn': _bvn.text,
        'nin': _nin.text,
      });
      try {
        (await SharedPreferences.getInstance()).remove(_draftKey);
      } catch (_) {}
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (_done && s.profile != null && s.profile!.hasAccount) return _Success(onContinue: () => widget.onFinished?.call());
    const titles = ['About you', 'Where you live', 'Your work', 'Verify your identity'];
    return Scaffold(
      appBar: AppBar(
        leading: _step > 0 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back) : null,
        title: Text('Step ${_step + 1} of 4'),
        actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out'))],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    decoration: BoxDecoration(color: i <= _step ? AppColors.green : AppColors.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text(titles[_step], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: [_aboutYou(), _whereYouLive(), _work(), _identity()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ErrorText(_error),
              const SizedBox(height: 8),
              _step < 3 ? FilledButton(onPressed: _next, child: const Text('Continue')) : BusyButton(label: 'Verify and create my account', onPressed: _submit),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: children);
  static const _gap = SizedBox(height: 14);
  static Widget _hint(String t) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(t, style: const TextStyle(color: AppColors.inkSoft, height: 1.45)));

  Widget _choice(String label, List<String> options, String? value, ValueChanged<String> onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: value == o,
            onSelected: (_) => setState(() => onPick(o)),
            selectedColor: AppColors.greenWash,
            labelStyle: TextStyle(color: value == o ? AppColors.green : AppColors.ink, fontWeight: value == o ? FontWeight.w600 : FontWeight.w500),
            side: BorderSide(color: value == o ? AppColors.green : AppColors.line),
            showCheckmark: false,
          ),
      ]),
    ]);
  }

  Widget _aboutYou() => _page([
        _hint('Enter your details exactly as they appear on your BVN record. Your bank uses them to confirm it\'s you.'),
        TextField(controller: _first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name')),
        _gap,
        TextField(controller: _middle, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Middle name (if on your BVN)')),
        _gap,
        TextField(controller: _last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Surname')),
        _gap,
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final latest = DateTime(now.year - 18, now.month, now.day);
            final d = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(now.year - 30, 1, 1),
              firstDate: DateTime(1920),
              lastDate: latest,
              initialEntryMode: DatePickerEntryMode.calendarOnly,
              helpText: 'Date of birth',
            );
            if (d != null) setState(() => _dob = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date of birth', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(_dob == null ? 'Choose your date of birth' : formatDay(_dob), style: TextStyle(color: _dob == null ? AppColors.inkSoft : AppColors.ink)),
          ),
        ),
        const SizedBox(height: 18),
        _choice('Gender', const ['Female', 'Male'], _gender, (v) => _gender = v),
        const SizedBox(height: 18),
        _choice('Marital status', maritalOptions, _marital, (v) => _marital = v),
      ]);

  Widget _whereYouLive() => _page([
        _hint('Use the phone number linked to your BVN. We\'ll also use it to text you codes that confirm withdrawals.'),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          decoration: const InputDecoration(labelText: 'Phone number', hintText: '08031234567'),
        ),
        _gap,
        TextField(controller: _address, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Home address', hintText: 'House number and street')),
        _gap,
        TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City or town')),
        _gap,
        DropdownButtonFormField<String>(
          initialValue: _state,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'State'),
          items: [for (final st in nigerianStates) DropdownMenuItem(value: st, child: Text(st))],
          onChanged: (v) => setState(() => _state = v),
        ),
      ]);

  Widget _work() {
    final working = const ['Employed', 'Self-employed', 'Business owner'].contains(_employment);
    return _page([
      _hint('This helps MOM serve you better, for example when you apply for a loan.'),
      _choice('Employment status', employmentOptions, _employment, (v) => _employment = v),
      if (working) ...[
        const SizedBox(height: 18),
        TextField(controller: _occupation, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Occupation', hintText: 'e.g. Teacher, Trader, Nurse')),
        _gap,
        TextField(
          controller: _employer,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _employment == 'Employed' ? 'Employer' : 'Business name (optional)'),
        ),
      ],
    ]);
  }

  Widget _identity() => _page([
        _hint('Your BVN lets us confirm your identity and create your own MOM Wealth account number. We never see your bank balance and can\'t move money from your bank.'),
        TextField(
          controller: _bvn,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          decoration: const InputDecoration(labelText: 'BVN (Bank Verification Number)', helperText: 'Dial *565*0# on the phone linked to your bank to get it.'),
        ),
        _gap,
        TextField(
          controller: _nin,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          decoration: const InputDecoration(labelText: 'NIN (National Identification Number)', helperText: 'Dial *346# to get it. It is on your NIN slip.'),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          child: CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I confirm these details are mine and correct, and I allow MOM Wealth to verify them with my bank.', style: TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ),
        const SizedBox(height: 12),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline, size: 16, color: AppColors.inkSoft),
          SizedBox(width: 8),
          Expanded(child: Text('Your full BVN and NIN are not stored. We keep only the last 4 digits.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.4))),
        ]),
      ]);
}

class _Success extends StatelessWidget {
  const _Success({required this.onContinue});
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<Session>().profile!;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 32, 20, 24), children: [
          const Center(child: CircleAvatar(radius: 30, backgroundColor: AppColors.greenWash, child: Icon(Icons.check_rounded, color: AppColors.green, size: 34))),
          const SizedBox(height: 16),
          Text('You\'re verified, ${p.firstName}!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('This is your own MOM Wealth account number. Transfer to it from any bank to add to your savings.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, height: 1.45)),
          const SizedBox(height: 24),
          MomCard(profile: p),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: p.accountNumber));
              toast(context, 'Account number copied');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy account number'),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onContinue, child: const Text('Go to my account')),
        ]),
      ),
    );
  }
}
