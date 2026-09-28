// Entry to Form B: sign in to the VanMitra backend, then list the village's cases.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'form_b_api.dart';
import 'form_b_models.dart';
import 'form_b_screen.dart';

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

  @override
  void initState() {
    super.initState();
    if (formBApi.isLoggedIn) _loadMe();
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
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
      });

  Future<void> _loadMe() => _run(_loadMeInner);

  Future<void> _loadMeInner() async {
    final me = await formBApi.me();
    final village = me.roles.isNotEmpty ? me.roles.first : null;
    final cases = village == null ? <CaseSummary>[] : await formBApi.listCases(village.villageId);
    setState(() {
      _me = me;
      _village = village;
      _cases = cases.where((c) => c.claimType == 'cr').toList();
    });
  }

  Future<void> _newCase() => _run(() async {
        final created = await formBApi.createCommunityRightsCase(_village!.villageId);
        await _loadMeInner();
        if (mounted) await _open(created.id);
      });

  Future<void> _open(String caseId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormBScreen(caseId: caseId, canEdit: _me!.canEditFormB(_village!.villageId)),
      ),
    );
    if (mounted) await _loadMe();
  }

  String _roleLabel(String role) => switch (role) {
        'facilitator' => 'NGO Facilitator',
        'frc_member' => 'FRC Member',
        'gs_secretary' => 'Gram Sabha Secretary',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Form B · सामूहिक हक्क दावा'),
        actions: [
          if (_me != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => setState(() {
                formBApi.logout();
                _me = null;
                _cases = [];
              }),
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
        const Text('Claim Form for Community Rights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Rule 11(1)(a) and (4) · sign in with your VanMitra phone number and PIN',
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
      return const Center(child: Text('Your account has no role in any village yet.'));
    }
    final canEdit = me.canEditFormB(village.villageId);
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
          if (canEdit)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.saffron),
                onPressed: _busy ? null : _newCase,
                icon: const Icon(Icons.add),
                label: const Text('Start a new Form B claim', style: TextStyle(fontSize: 16)),
              ),
            ),
          const SizedBox(height: 16),
          Text('Community rights claims (${_cases.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No Form B claims yet.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final c in _cases)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined, color: AppColors.forestCanopy),
                title: Text('Form B · ${c.id.substring(0, 8)}'),
                subtitle: Text('Status: ${c.state.toUpperCase()} · created ${_date(c.createdAt)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(c.id),
              ),
            ),
        ],
      ),
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
