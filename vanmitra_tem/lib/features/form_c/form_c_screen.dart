// Form C draft: Claim Form for Rights to Community Forest Resource [Sec 3(1)(i); Rule 11(1), (4)].
// Every input on the printed form, in its order (1mitra.md §6.3), as cards in the
// villager design, with the documentation checklist on top and Save at the bottom.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../form_b/form_b_api.dart';
import '../form_b/form_b_models.dart';
import 'form_c_models.dart';
import 'members_screen.dart';

class FormCScreen extends StatefulWidget {
  const FormCScreen({super.key, required this.caseId, required this.canEdit, this.villageId});

  final String caseId;
  final bool canEdit;

  /// For the member list (item 5).
  final String? villageId;

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
  Object? _error;
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
      if (mounted) setState(() => _error = e);
    }
  }

  void _apply(FormCData f) {
    if (!mounted) return;
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
      if (mounted) showDone(context, 'Form C draft saved.');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// An empty statement is sent as null, which makes the server restore the printed text.
  Future<void> _restoreStatement() async {
    _statement.clear();
    await _save();
  }

  void _openMembers() {
    final vid = widget.villageId;
    if (vid == null || vid.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MembersScreen(villageId: vid, canEdit: false)));
  }

  void _addLandmark() => setState(() => _landmarks.add(_LandmarkDraft(_nextSide(), 'stream', '', '')));
  void _removeLandmark(int i) => setState(() => _landmarks.removeAt(i));
  void _addVillage() => setState(() => _villages.add(_VillageDraft('', false, '')));
  void _removeVillage(int i) => setState(() => _villages.removeAt(i));
  void _addEvidence() => setState(() => _evidence.add(_EvidenceDraft('13(2)(b)', '')));
  void _removeEvidence(int i) => setState(() => _evidence.removeAt(i));

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: context.colors.isDark ? const Color(0xFF16251D) : const Color(0xFFF5FBF7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = _form;
    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'My Claims', 'Form C'],
      bottomNavigationBar: _editable
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: context.colors.cardBg,
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -3))],
                ),
                child: OrangePillButton(
                  label: 'Save draft · जतन करा',
                  icon: Icons.save_rounded,
                  busy: _saving,
                  expand: true,
                  onPressed: _save,
                ),
              ),
            )
          : null,
      body: f == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : VillagerEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load Form C',
                      message: apiErrorText(_error!),
                      actionLabel: 'Try again',
                      actionIcon: Icons.refresh_rounded,
                      onAction: _load,
                    ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                const NatureBanner(height: 78),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _sections(f),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _sections(FormCData f) {
    final c = context.colors;
    return [
      const VmSectionTitle('Form C · सामूहिक वन संसाधन दावा',
          subtitle: 'Claim form for rights to Community Forest Resource [Sec 3(1)(i)]'),
      ChecklistCard(
        title: 'Documentation checklist',
        lines: [
          for (final i in f.completeness)
            ChecklistLine(ok: i.ok, text: kFormCCompletenessText[i.messageKey] ?? i.messageKey, rule: i.rule),
        ],
        footnote: 'Khasra numbers are optional ("if any and if known").',
      ),
      if (!_editable)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: widget.canEdit ? 'Submitted: the form is locked' : 'View only',
              color: const Color(0xFF607D8B),
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ),
      _section(1, 'Village / Gram Sabha', 'Items 1–4, from the village registry', [
        _readOnly('Village', '${f.header['village_name_mr']} (${f.header['village_name_en']})'),
        _readOnly('Gram Panchayat', f.header['gram_panchayat'] ?? ''),
        _readOnly('Tehsil / Taluka', f.header['taluka'] ?? ''),
        _readOnly('District', f.header['district'] ?? ''),
      ]),
      _section(5, 'Gram Sabha members', 'Separate sheet with ST / OTFD status, kept by the Gram Sabha', [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _countPill('${f.memberTotal}', 'members', const Color(0xFF143526)),
            _countPill('${f.memberSt}', 'ST', const Color(0xFF00838F)),
            _countPill('${f.memberOtfd}', 'OTFD', const Color(0xFF6B4BB8)),
          ],
        ),
        const SizedBox(height: 8),
        Text('The presence of a few ST / OTFD members is sufficient to make the claim.',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        const SizedBox(height: 6),
        for (final m in f.members.take(6))
          Text('• ${m.key}  (${kMemberCategories[m.value] ?? m.value})',
              style: TextStyle(color: c.textPrimary, fontSize: 13)),
        if (f.members.length > 6)
          Text('… and ${f.members.length - 6} more', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        if (widget.villageId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openMembers,
              icon: const Icon(Icons.people_alt_rounded),
              label: const Text('Manage member list'),
            ),
          ),
      ]),
      _section(null, '5a. Resolving statement', 'Section 3(1)(i) · may be edited or written in Marathi', [
        TextField(controller: _statement, enabled: _editable, minLines: 3, maxLines: 8, decoration: _dec('Statement')),
        if (_editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _restoreStatement,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore printed text'),
            ),
          ),
      ]),
      _section(null, '5b. The community forest resource', 'Location, landmarks and the four boundaries · Rule 12(1)(g)', [
        TextField(
          controller: _area,
          enabled: _editable,
          minLines: 2,
          maxLines: 6,
          decoration: _dec('Describe the area', hint: 'Traditional / customary boundary; need not match legal boundaries'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _areaHa,
          enabled: _editable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _dec('Approximate area in hectares (optional)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pastoral,
          activeThumbColor: const Color(0xFFFF7A00),
          onChanged: _editable ? (v) => setState(() => _pastoral = v) : null,
          title: Text('Seasonal use of landscape (pastoral community)',
              style: TextStyle(color: c.textPrimary, fontSize: 14)),
        ),
        if (_pastoral)
          TextField(controller: _seasonal, enabled: _editable, minLines: 2, maxLines: 4, decoration: _dec('Seasons and routes')),
        const SizedBox(height: 12),
        Text('Landmarks · चतु:सीमा (one or more for each boundary)',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < _landmarks.length; i++) _landmarkRow(i),
        if (_editable) _addButton('Add landmark', Icons.add_location_alt_rounded, _addLandmark),
        Text('The mapped boundary (GPS walk) is added in Step 3 · Boundary.',
            style: TextStyle(fontSize: 12, color: c.textTertiary)),
      ]),
      _section(6, 'Khasra / Compartment No.(s)', 'Only if any and if known', [
        TextField(controller: _khasra, enabled: _editable, decoration: _dec('Numbers, comma separated', hint: 'e.g. 156, 157')),
      ]),
      _section(7, 'Bordering villages', 'Including sharing of resources and responsibilities', [
        for (var i = 0; i < _villages.length; i++) _villageRow(i),
        if (_editable) _addButton('Add bordering village', Icons.holiday_village_rounded, _addVillage),
      ]),
      _section(8, 'List of evidence in support', 'Rule 13 · two or more under 13(1), one or more under 13(2)', [
        for (var i = 0; i < _evidence.length; i++) _evidenceRow(i),
        if (_editable) _addButton('Add evidence', Icons.playlist_add_rounded, _addEvidence),
        Text('Photos of the evidence are added in Step 2 · Evidence.',
            style: TextStyle(fontSize: 12, color: c.textTertiary)),
      ]),
      const SizedBox(height: 14),
      Text(
        'Signature / thumb impression of the claimant(s) is given on the printed form.\n'
        'Community record prepared with VanMitra. Not a government document.',
        style: TextStyle(fontSize: 12, color: c.textTertiary),
      ),
    ];
  }

  String _nextSide() {
    const order = ['east', 'west', 'north', 'south'];
    for (final s in order) {
      if (!_landmarks.any((l) => l.side == s)) return s;
    }
    return 'within';
  }

  Widget _countPill(String n, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: '$n ', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
            TextSpan(text: label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _addButton(String label, IconData icon, VoidCallback onTap) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE07A00)),
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  Widget _section(int? number, String title, String? subtitle, List<Widget> children) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: VmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFF2E705B), shape: BoxShape.circle),
                    child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _readOnly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary, fontSize: 13.5)),
          ),
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
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed),
          onPressed: onPressed,
        )
      : const SizedBox.shrink();

  Widget _rowCard(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.isDark ? const Color(0xFF132219) : const Color(0xFFFAFDFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(children: children),
      );

  Widget _landmarkRow(int i) {
    final l = _landmarks[i];
    return _rowCard([
      Row(children: [
        Expanded(child: _dropdown('Boundary', l.side, kBoundarySides, (v) => l.side = v)),
        const SizedBox(width: 8),
        Expanded(child: _dropdown('Type', l.kind, kLandmarkKinds, (v) => l.kind = v)),
        _removeButton(() => _removeLandmark(i)),
      ]),
      const SizedBox(height: 8),
      TextField(controller: l.name, enabled: _editable, decoration: _dec('Landmark name', hint: 'e.g. नागदेवता नाला')),
      const SizedBox(height: 8),
      TextField(controller: l.description, enabled: _editable, decoration: _dec('Where exactly? (optional)')),
    ]);
  }

  Widget _villageRow(int i) {
    final v = _villages[i];
    return _rowCard([
      Row(children: [
        Text('(${i + 1})', style: TextStyle(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: v.name, enabled: _editable, decoration: _dec('Village name'))),
        _removeButton(() => _removeVillage(i)),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: v.sharesResources,
        activeThumbColor: const Color(0xFFFF7A00),
        onChanged: _editable ? (x) => setState(() => v.sharesResources = x) : null,
        title: Text('Shares resources or responsibilities',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 13.5)),
      ),
      if (v.sharesResources) TextField(controller: v.details, enabled: _editable, decoration: _dec('What is shared?')),
    ]);
  }

  Widget _evidenceRow(int i) {
    final e = _evidence[i];
    return _rowCard([
      Row(children: [
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdown(
            'Rule 13 category',
            e.ruleRef,
            {for (final r in kEvidenceRules.entries) r.key: '${r.key}  ${r.value}'},
            (v) => e.ruleRef = v,
          ),
        ),
        _removeButton(() => _removeEvidence(i)),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: e.description,
        enabled: _editable,
        decoration: _dec('What is it? (issuing office, reference, date)'),
      ),
    ]);
  }
}
