// Form C draft: Claim Form for Rights to Community Forest Resource [Sec 3(1)(i); Rule 11(1), (4)].
// Every input on the printed form, in its order (1mitra.md §6.3).

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../form_b/form_b_api.dart';
import '../form_b/form_b_models.dart';
import 'form_c_models.dart';

class FormCScreen extends StatefulWidget {
  const FormCScreen({super.key, required this.caseId, required this.canEdit});

  final String caseId;
  final bool canEdit;

  @override
  State<FormCScreen> createState() => _FormCScreenState();
}

class _LandmarkDraft {
  _LandmarkDraft(this.side, this.kind, String name, String description)
      : name = TextEditingController(text: name),
        description = TextEditingController(text: description);

  String side;
  String kind;
  final TextEditingController name;
  final TextEditingController description;
}

class _VillageDraft {
  _VillageDraft(String name, this.sharesResources, String details)
      : name = TextEditingController(text: name),
        details = TextEditingController(text: details);

  final TextEditingController name;
  bool sharesResources;
  final TextEditingController details;
}

class _EvidenceDraft {
  _EvidenceDraft(this.ruleRef, String description) : description = TextEditingController(text: description);

  String ruleRef;
  final TextEditingController description;
}

class _FormCScreenState extends State<FormCScreen> {
  FormCData? _form;
  String? _error;
  bool _saving = false;

  final _statement = TextEditingController();
  final _area = TextEditingController();
  final _areaHa = TextEditingController();
  final _seasonal = TextEditingController();
  final _khasra = TextEditingController();
  bool _pastoral = false;
  List<_LandmarkDraft> _landmarks = [];
  List<_VillageDraft> _villages = [];
  List<_EvidenceDraft> _evidence = [];

  bool get _editable => widget.canEdit && (_form?.editable ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _apply(await formBApi.getFormC(widget.caseId));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _apply(FormCData f) {
    setState(() {
      _form = f;
      _error = null;
      _statement.text = f.resolutionStatement;
      _area.text = f.areaDescription ?? '';
      _areaHa.text = f.approxAreaHa?.toString() ?? '';
      _pastoral = f.pastoralSeasonalUse;
      _seasonal.text = f.seasonalUseDetails ?? '';
      _khasra.text = f.khasraNumbers.join(', ');
      _landmarks = f.landmarks.map((l) => _LandmarkDraft(l.side, l.kind, l.name, l.description ?? '')).toList();
      _villages = f.borderingVillages.map((v) => _VillageDraft(v.name, v.sharesResources, v.sharingDetails ?? '')).toList();
      _evidence = f.evidence.map((e) => _EvidenceDraft(e.ruleRef, e.description)).toList();
    });
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> _body() => {
        'resolution_statement': _opt(_statement),
        'area_description': _opt(_area),
        'approx_area_ha': double.tryParse(_areaHa.text.trim()),
        'pastoral_seasonal_use': _pastoral,
        'seasonal_use_details': _pastoral ? _opt(_seasonal) : null,
        'landmarks': [
          for (final l in _landmarks.where((l) => l.name.text.trim().isNotEmpty))
            {'side': l.side, 'kind': l.kind, 'name': l.name.text.trim(), 'description': _opt(l.description)},
        ],
        'khasra_compartment_numbers':
            _khasra.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'bordering_villages': [
          for (final v in _villages.where((v) => v.name.text.trim().isNotEmpty))
            {
              'name': v.name.text.trim(),
              'shares_resources': v.sharesResources,
              'sharing_details': v.sharesResources ? _opt(v.details) : null,
            },
        ],
        'evidence': [
          for (final e in _evidence.where((e) => e.description.text.trim().isNotEmpty))
            {'rule_ref': e.ruleRef, 'description': e.description.text.trim()},
        ],
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      _apply(await formBApi.saveFormC(widget.caseId, _body()));
      _snack('Form C draft saved');
    } on ApiException catch (e) {
      _snack('Not saved: $e');
    } catch (e) {
      _snack('Not saved: cannot reach the server');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final f = _form;
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.forestCanopy,
        foregroundColor: Colors.white,
        title: const Text('Form C · Community Forest Resource'),
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
                    child: Text('View only: your role cannot edit this draft.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                _section('1–4. Village / Gram Sabha', 'From the village registry', [
                  _readOnly('1. Village / Gram Sabha', '${f.header['village_name_mr']} (${f.header['village_name_en']})'),
                  _readOnly('2. Gram Panchayat', f.header['gram_panchayat'] ?? ''),
                  _readOnly('3. Tehsil / Taluka', f.header['taluka'] ?? ''),
                  _readOnly('4. District', f.header['district'] ?? ''),
                ]),
                _section('5. Gram Sabha members', 'Separate sheet with ST / OTFD status · kept by the GS Secretary', [
                  Text('${f.memberTotal} members · ${f.memberSt} ST · ${f.memberOtfd} OTFD',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('The presence of a few ST / OTFD members is sufficient to make the claim.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  for (final m in f.members.take(8))
                    Text('• ${m.key}  (${kMemberCategories[m.value] ?? m.value})'),
                  if (f.members.length > 8) Text('… and ${f.members.length - 8} more'),
                ]),
                _section('5a. Resolving statement', 'Section 3(1)(i) · editable by the FRC', [
                  TextField(controller: _statement, enabled: _editable, minLines: 3, maxLines: 8, decoration: _dec('Statement')),
                ]),
                _section('5b. The community forest resource', 'Location, landmarks and the four boundaries · Rule 12(1)(g)', [
                  TextField(
                    controller: _area,
                    enabled: _editable,
                    minLines: 2,
                    maxLines: 6,
                    decoration: _dec('Describe the area', hint: 'Traditional / customary boundary; need not match legal boundaries'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _areaHa,
                    enabled: _editable,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Approximate area (hectares, optional)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _pastoral,
                    onChanged: _editable ? (v) => setState(() => _pastoral = v) : null,
                    title: const Text('Seasonal use of landscape (pastoral community)'),
                  ),
                  if (_pastoral)
                    TextField(controller: _seasonal, enabled: _editable, minLines: 2, maxLines: 4, decoration: _dec('Seasons and routes')),
                  const SizedBox(height: 10),
                  const Text('Landmarks (one or more for each boundary)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _landmarks.length; i++) _landmarkRow(i),
                  if (_editable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _landmarks.add(_LandmarkDraft(_nextSide(), 'stream', '', ''))),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add landmark'),
                      ),
                    ),
                  const Text('The mapped boundary (GPS walk) is added in the mapping step.',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ]),
                _section('6. Khasra / Compartment No.(s)', 'Only if any and if known', [
                  TextField(controller: _khasra, enabled: _editable, decoration: _dec('Numbers, comma separated', hint: 'e.g. 156, 157')),
                ]),
                _section('7. Bordering villages', 'Including sharing of resources and responsibilities', [
                  for (var i = 0; i < _villages.length; i++) _villageRow(i),
                  if (_editable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _villages.add(_VillageDraft('', false, ''))),
                        icon: const Icon(Icons.add),
                        label: const Text('Add bordering village'),
                      ),
                    ),
                ]),
                _section('8. List of evidence in support', 'Rule 13 · ≥ 2 under 13(1) and ≥ 1 under 13(2)', [
                  for (var i = 0; i < _evidence.length; i++) _evidenceRow(i),
                  if (_editable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _evidence.add(_EvidenceDraft('13(2)(b)', ''))),
                        icon: const Icon(Icons.add),
                        label: const Text('Add evidence'),
                      ),
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

  String _nextSide() {
    const order = ['east', 'west', 'north', 'south'];
    for (final s in order) {
      if (!_landmarks.any((l) => l.side == s)) return s;
    }
    return 'within';
  }

  Widget _completenessCard(FormCData f) {
    final missing = f.completeness.where((i) => !i.ok).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentation completeness: ${f.done} of ${f.total}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                    Expanded(child: Text('${kFormCCompletenessText[m.messageKey] ?? m.messageKey}  ·  ${m.rule}')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String? subtitle, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.forestSage)),
            if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _readOnly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _dropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: _dec(label),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: _editable ? (v) => setState(() => onChanged(v ?? value)) : null,
      );

  Widget _removeButton(VoidCallback onPressed) => _editable
      ? IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline, color: AppColors.alertRed),
          onPressed: () => setState(onPressed),
        )
      : const SizedBox.shrink();

  Widget _landmarkRow(int i) {
    final l = _landmarks[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: _dropdown('Boundary', l.side, kBoundarySides, (v) => l.side = v)),
            const SizedBox(width: 8),
            Expanded(child: _dropdown('Type', l.kind, kLandmarkKinds, (v) => l.kind = v)),
            _removeButton(() => _landmarks.removeAt(i)),
          ]),
          const SizedBox(height: 8),
          TextField(controller: l.name, enabled: _editable, decoration: _dec('Landmark name', hint: 'e.g. नागदेवता नाला')),
          const SizedBox(height: 8),
          TextField(controller: l.description, enabled: _editable, decoration: _dec('Where exactly? (optional)')),
        ]),
      ),
    );
  }

  Widget _villageRow(int i) {
    final v = _villages[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Text('(${i + 1})', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: v.name, enabled: _editable, decoration: _dec('Village name'))),
            _removeButton(() => _villages.removeAt(i)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: v.sharesResources,
            onChanged: _editable ? (x) => setState(() => v.sharesResources = x) : null,
            title: const Text('Shares resources or responsibilities'),
          ),
          if (v.sharesResources)
            TextField(controller: v.details, enabled: _editable, decoration: _dec('What is shared?')),
        ]),
      ),
    );
  }

  Widget _evidenceRow(int i) {
    final e = _evidence[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: _dropdown(
                'Rule 13 category',
                e.ruleRef,
                {for (final r in kEvidenceRules.entries) r.key: '${r.key}  ${r.value}'},
                (v) => e.ruleRef = v,
              ),
            ),
            _removeButton(() => _evidence.removeAt(i)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: e.description,
            enabled: _editable,
            decoration: _dec('What is it? (issuing office, reference, date)'),
          ),
        ]),
      ),
    );
  }
}
