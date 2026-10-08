// Entry to community claims: sign in to the VanMitra backend, then the village's
// Form B (community rights) and Form C (community forest resource) cases and roster.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'form_b_api.dart';
import 'form_b_models.dart';
import 'form_b_screen.dart';
import '../form_c/form_c_screen.dart';
import '../form_c/members_screen.dart';
import '../notifications/notifications_screen.dart';

class FormBHomeScreen extends StatefulWidget {
  const FormBHomeScreen({super.key});

  @override
  State<FormBHomeScreen> createState() => _FormBHomeScreenState();
}

class _FormBHomeScreenState extends State<FormBHomeScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;
  Me? _me;
  RoleGrant? _village;
  List<CaseSummary> _cases = [];
  int _unread = 0;
  String? _pushToken;
  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<String>? _onTokenRefresh;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    if (await formBApi.isLoggedIn()) {
      _loadMe();
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _onMessage?.cancel();
    _onTokenRefresh?.cancel();
    super.dispose();
  }

  /// Push messages in the language the app is shown in (Marathi unless English).
  String get _lang => Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'mr';

  Future<void> _refreshUnread() async {
    try {
      final page = await formBApi.notifications();
      if (mounted) setState(() => _unread = page.unread);
    } catch (_) {}
  }

  /// Ask permission for notifications and register this phone for push messages.
  /// Never blocks sign-in: without push, messages still appear in the app.
  Future<void> _registerPush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && formBApi.isLoggedIn) {
        await formBApi.registerDevice(token, language: _lang);
        _pushToken = token;
      }
      _onTokenRefresh ??= messaging.onTokenRefresh.listen((t) async {
        if (!formBApi.isLoggedIn) return;
        try {
          await formBApi.registerDevice(t, language: _lang);
          _pushToken = t;
        } catch (_) {}
      });
      // A push that arrives while the app is open: show it and update the bell.
      _onMessage ??= FirebaseMessaging.onMessage.listen((m) {
        _refreshUnread();
        final n = m.notification;
        if (n != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${n.title ?? ''}\n${n.body ?? ''}'), duration: const Duration(seconds: 6)),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final token = _pushToken;
    if (token != null) {
      try {
        await formBApi.removeDevice(token);
      } catch (_) {}
    }
    setState(() {
      formBApi.logout();
      _me = null;
      _cases = [];
      _unread = 0;
      _pushToken = null;
    });
  }

  Future<void> _openMessages() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    await _refreshUnread();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _error = e.status == 401 ? 'Wrong phone number or PIN' : e.toString());
    } catch (e) {
      setState(() => _error = 'Cannot reach the VanMitra server (${formBApi.baseUrl}).\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() => _run(() async {
        await formBApi.login(_phone.text.trim(), _pin.text.trim());
        await _loadMeInner();
        _registerPush();
      });

  Future<void> _loadMe() => _run(_loadMeInner);

  Future<void> _loadMeInner() async {
    final me = await formBApi.me();
    final village = me.roles.where((r) => r.villageId != null).firstOrNull;
    final cases = village == null ? <CaseSummary>[] : await formBApi.listCases(village.villageId!);
    final unread = (await formBApi.notifications()).unread;
    setState(() {
      _unread = unread;
      _me = me;
      _village = village;
      _cases = cases.where((c) => c.claimType == 'cr' || c.claimType == 'cfr').toList();
    });
  }

  Future<void> _newCase(String claimType) => _run(() async {
        final created = await formBApi.createCase(_village!.villageId!, claimType);
        await _loadMeInner();
        if (mounted) await _open(created);
      });

  Future<void> _open(CaseSummary c) async {
    final villageId = _village!.villageId!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => c.claimType == 'cfr'
            ? FormCScreen(caseId: c.id, canEdit: _me!.canEditFormC(villageId))
            : FormBScreen(caseId: c.id, canEdit: _me!.canEditFormB(villageId)),
      ),
    );
    if (mounted) await _loadMe();
  }

  Future<void> _openMembers() async {
    final villageId = _village!.villageId!;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MembersScreen(villageId: villageId, canEdit: _me!.canEditRoster(villageId))),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'villager' => 'Villager · ग्रामस्थ',
        'gram_sabha' => 'Gram Sabha · ग्रामसभा',
        'sdo' => 'SDO · उपविभागीय अधिकारी',
        _ => role,
      };

  String _stateLabel(String state) => switch (state) {
        'draft' => 'Draft · मसुदा',
        'gs_review' => 'With the Gram Sabha · ग्रामसभेकडे',
        'sdo_review' => 'With the SDO · उपविभागीय अधिकाऱ्यांकडे',
        'district_review' => 'Sent to the district · जिल्हास्तरावर पाठवला',
        'title_issued' => 'Title issued · हक्कपत्र दिले',
        'rejected' => 'Rejected · नामंजूर',
        'expired' => 'Closed: not resubmitted in 60 days · मुदत संपली',
        _ => state,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Community claims · सामूहिक दावे'),
        actions: [
          if (_me != null)
            IconButton(
              tooltip: 'Messages',
              onPressed: _openMessages,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text('$_unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          if (_me != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
        ],
      ),
      body: SafeArea(child: _me == null ? _loginView() : _casesView()),
    );
  }

  Widget _loginView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Form B and Form C claims',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Community rights and community forest resource · sign in with your VanMitra phone number and PIN',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit PIN', border: OutlineInputBorder()),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.alertRed)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.forestCanopy),
            onPressed: _busy ? null : _login,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sign in', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _casesView() {
    final me = _me!;
    final village = _village;
    if (village == null) {
      final isSdo = me.roles.any((r) => r.role == 'sdo');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isSdo
                ? 'Signed in as SDO. Claims reach you after the Gram Sabha forwards them.'
                : 'Your account has no role in any village yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final villageId = village.villageId!;
    final canEdit = me.canEditFormB(villageId);
    final canFormC = me.canEditFormC(villageId);
    return RefreshIndicator(
      onRefresh: _loadMe,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: AppColors.forestSage),
              title: Text(me.name),
              subtitle: Text('${_roleLabel(village.role)} · ${village.villageNameMr} (${village.villageNameEn})'),
            ),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.alertRed)),
          ),
          const SizedBox(height: 8),
          if (canEdit) ...[
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.saffron),
                onPressed: _busy ? null : () => _newCase('cr'),
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('New Form B · Community Rights', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.forestCanopy),
                onPressed: _busy || !canFormC ? null : () => _newCase('cfr'),
                icon: const Icon(Icons.forest_outlined),
                label: const Text('New Form C · Community Forest Resource', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _openMembers,
            icon: const Icon(Icons.people_alt_outlined),
            label: Text(me.canEditRoster(villageId) ? 'Gram Sabha members (edit)' : 'Gram Sabha members'),
          ),
          const SizedBox(height: 16),
          Text('Community claims (${_cases.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No Form B or Form C claims yet.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final c in _cases)
            Card(
              child: ListTile(
                leading: Icon(c.claimType == 'cfr' ? Icons.forest_outlined : Icons.groups_2_outlined,
                    color: AppColors.forestCanopy),
                title: Text('${c.claimType == 'cfr' ? 'Form C' : 'Form B'} · ${c.id.substring(0, 8)}'),
                subtitle: _caseSubtitle(c),
                isThreeLine: c.returned != null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(c),
              ),
            ),
        ],
      ),
    );
  }

  /// Status, and for a claim sent back: who sent it, why, and how many days are left.
  Widget _caseSubtitle(CaseSummary c) {
    final back = c.returned;
    final status = Text('${_stateLabel(c.state)} · created ${_date(c.createdAt)}');
    if (back == null) return status;
    final by = back.byRole == 'sdo' ? 'SDO' : 'Gram Sabha';
    final urgent = back.daysLeft <= 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        const SizedBox(height: 4),
        Text('Sent back by $by: ${back.remarks}',
            style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w600)),
        Text(
          back.daysLeft > 0
              ? '${back.daysLeft} days left to resubmit (until ${_date(back.resubmitBy)}) · ${back.daysLeft} दिवस बाकी'
              : 'Last day to resubmit has passed · मुदत संपली',
          style: TextStyle(color: urgent ? AppColors.alertRed : AppColors.textSecondary),
        ),
      ],
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
