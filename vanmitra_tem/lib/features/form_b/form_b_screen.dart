// Form B draft: every input on the printed form (Annexure I, Form B), in its order.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'form_b_api.dart';
import 'form_b_models.dart';

class FormBScreen extends StatefulWidget {
  const FormBScreen({super.key, required this.caseId, required this.canEdit});

  final String caseId;
  final bool canEdit;

  @override
  State<FormBScreen> createState() => _FormBScreenState();
}

class _RightDraft {
  _RightDraft(FormBRight r)
      : spec = r,
        claimed = r.claimed,
        details = TextEditingController(text: r.details ?? ''),
        items = TextEditingController(text: r.items.join(', '));

  final FormBRight spec;
  bool claimed;
  final TextEditingController details;
  final TextEditingController items;
}

class _EvidenceDraft {
  _EvidenceDraft(this.ruleRef, String description) : description = TextEditingController(text: description);

  String ruleRef;
  final TextEditingController description;
}

class _FormBScreenState extends State<FormBScreen> {
  FormBData? _form;
  String? _error;
  bool _saving = false;

  final _names = TextEditingController();
  final _other = TextEditingController();
  bool? _fdst;
  bool? _otfd;
  List<_RightDraft> _rights = [];
  List<_EvidenceDraft> _evidence = [];

  bool get _editable => widget.canEdit && (_form?.editable ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _apply(await formBApi.getFormB(widget.caseId));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _apply(FormBData f) {
    setState(() {
      _form = f;
      _error = null;
      _names.text = f.claimantNames.join('\n');
      _other.text = f.otherInformation ?? '';
      _fdst = f.isFdstCommunity;
      _otfd = f.isOtfdCommunity;
      _rights = f.rights.map(_RightDraft.new).toList();
      _evidence = f.evidence.map((e) => _EvidenceDraft(e.ruleRef, e.description)).toList();
    });
  }

  List<String> _split(String text, Pattern sep) =>
      text.split(sep).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> _body() => {
        'claimant_names': _split(_names.text, '\n'),
        'is_fdst_community': _fdst,
        'is_otfd_community': _otfd,
        'rights': {
          for (final r in _rights.where((r) => r.claimed && r.details.text.trim().isNotEmpty))
            r.spec.code: {'details': r.details.text.trim(), 'items': _split(r.items.text, ',')},
        },
        'evidence': [
          for (final e in _evidence.where((e) => e.description.text.trim().isNotEmpty))
            {'rule_ref': e.ruleRef, 'description': e.description.text.trim()},
        ],
        'other_information': _other.text.trim().isEmpty ? null : _other.text.trim(),
      };

  Future<void> _save() async {
    final unexplained = _rights.where((r) => r.claimed && r.details.text.trim().isEmpty).toList();
    if (unexplained.isNotEmpty) {
      _snack('Describe how the community enjoys: ${unexplained.map((r) => 'item ${r.spec.formItem}').join(', ')}');
      return;
    }
    setState(() => _saving = true);
    try {
      _apply(await formBApi.saveFormB(widget.caseId, _body()));
      _snack('Form B draft saved');
    } on ApiException catch (e) {
      _snack('Not saved: $e');
    } catch (e) {
      _snack('Not saved: cannot reach the server');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final f = _form;
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Form B · Community Rights'),
      ),
      bottomNavigationBar: _editable
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.forestCanopy),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save draft', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            )
          : null,
      body: f == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _completenessCard(f),
                if (!_editable)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('View only: your role cannot edit this draft.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                _section('1. Claimant(s)', 'Rule 11(1)(a)', [
                  TextField(
                    controller: _names,
                    enabled: _editable,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Name of the claimant(s): one per line',
                      hintText: 'e.g. Ozhar Gram Sabha',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _yesNo('(a) FDST community?', _fdst, (v) => setState(() => _fdst = v)),
                  _yesNo('(b) OTFD community?', _otfd, (v) => setState(() => _otfd = v)),
                ]),
                _section('2–5. Village details', 'From the village registry', [
                  _readOnly('2. Village', '${f.header['village_name_mr']} (${f.header['village_name_en']})'),
                  _readOnly('3. Gram Panchayat', f.header['gram_panchayat'] ?? ''),
                  _readOnly('4. Tehsil / Taluka', f.header['taluka'] ?? ''),
                  _readOnly('5. District', f.header['district'] ?? ''),
                ]),
                _section('Nature of community rights enjoyed', 'Switch on each right the community enjoys', [
                  for (final r in _rights) _rightCard(r),
                ]),
                _section('7. Evidence in support', 'Rule 13 · at least two items [Rule 11(1)(a)]', [
                  for (var i = 0; i < _evidence.length; i++) _evidenceRow(i),
                  if (_editable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _evidence.add(_EvidenceDraft('13(1)(a)', ''))),
                        icon: const Icon(Icons.add),
                        label: const Text('Add evidence'),
                      ),
                    ),
                ]),
                _section('8. Any other information', null, [
                  TextField(
                    controller: _other,
                    enabled: _editable,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text(
                  'Signature / thumb impression of the claimant(s) is given on the printed form.\n'
                  'Community record prepared with VanMitra. Not a government document.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
    );
  }

  Widget _completenessCard(FormBData f) {
    final missing = f.completeness.where((i) => !i.ok).toList();
    return Card(
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentation completeness: ${f.done} of ${f.total}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            if (missing.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Nothing missing from the form.', style: TextStyle(color: AppColors.successGreen)),
              ),
            for (final m in missing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.warningAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${kCompletenessText[m.messageKey] ?? m.messageKey}  ·  ${m.rule}',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String? subtitle, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.forestCanopy)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _readOnly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _yesNo(String label, bool? value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: true, label: Text('Yes')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: value == null ? <bool>{} : {value},
            onSelectionChanged: _editable ? (s) => onChanged(s.isEmpty ? null : s.first) : null,
          ),
        ],
      ),
    );
  }

  Widget _rightCard(_RightDraft r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: r.claimed,
              onChanged: _editable ? (v) => setState(() => r.claimed = v) : null,
              title: Text('${r.spec.formItem}. ${r.spec.labelEn}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(r.spec.section, style: const TextStyle(fontSize: 12)),
            ),
            if (r.claimed) ...[
              TextField(
                controller: r.details,
                enabled: _editable,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'How does the community enjoy this right?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: r.items,
                enabled: _editable,
                decoration: const InputDecoration(
                  labelText: 'Named items (optional, comma separated)',
                  hintText: 'e.g. mahua, tendu, gairan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _evidenceRow(int i) {
    final e = _evidence[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: e.ruleRef,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rule 13 category', border: OutlineInputBorder()),
                    items: [
                      for (final entry in kEvidenceRules.entries)
                        DropdownMenuItem(value: entry.key, child: Text('${entry.key}  ${entry.value}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _editable ? (v) => setState(() => e.ruleRef = v ?? e.ruleRef) : null,
                  ),
                ),
                if (_editable)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline, color: AppColors.alertRed),
                    onPressed: () => setState(() => _evidence.removeAt(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: e.description,
              enabled: _editable,
              decoration: const InputDecoration(
                labelText: 'What is it? (issuing office, reference, date)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
