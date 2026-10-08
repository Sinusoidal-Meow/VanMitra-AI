// Form A draft: Claim form for rights to forest land under occupation [Rule 11(1)(a)].
// Follows statutory items 1 to 10 of FRA Annexure I (Form A).

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../form_b/form_b_models.dart';
import 'form_a_api.dart';
import 'form_a_models.dart';

class FormAScreen extends StatefulWidget {
  final String caseId;
  final bool canEdit;

  const FormAScreen({
    super.key,
    required this.caseId,
    required this.canEdit,
  });

  @override
  State<FormAScreen> createState() => _FormAScreenState();
}

class _ClaimDraft {
  final FormAClaimSpec spec;
  bool claimed;
  final TextEditingController extent;
  final TextEditingController details;

  _ClaimDraft({
    required this.spec,
    this.claimed = false,
    String? initialExtent,
    String? initialDetails,
  })  : extent = TextEditingController(text: initialExtent ?? ''),
        details = TextEditingController(text: initialDetails ?? '');
}

class _EvidenceDraft {
  String ruleRef;
  final TextEditingController description;

  _EvidenceDraft(this.ruleRef, String desc) : description = TextEditingController(text: desc);
}

class _FormAScreenState extends State<FormAScreen> {
  FormAData? _form;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  final _namesCtrl = TextEditingController();
  final _spouseCtrl = TextEditingController();
  final _parentsCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  bool? _isSt;
  bool? _isOtfd;
  bool? _spouseIsSt;

  List<FamilyMemberItem> _familyMembers = [];
  late List<_ClaimDraft> _claimDrafts;
  List<_EvidenceDraft> _evidenceList = [];

  bool get _editable => widget.canEdit && (_form?.editable ?? false);

  @override
  void initState() {
    super.initState();
    _initClaimDrafts();
    _loadData();
  }

  void _initClaimDrafts() {
    _claimDrafts = kFormAClaimSpecs.map((spec) => _ClaimDraft(spec: spec)).toList();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await formAApi.getFormA(widget.caseId);
      _applyData(data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyData(FormAData data) {
    if (!mounted) return;
    setState(() {
      _form = data;
      _error = null;
      _loading = false;

      _namesCtrl.text = data.claimantNames.join('\n');
      _spouseCtrl.text = data.spouseName ?? '';
      _parentsCtrl.text = data.fatherMotherName ?? '';
      _addressCtrl.text = data.address ?? '';
      _otherCtrl.text = data.otherInformation ?? '';

      _isSt = data.isScheduledTribe;
      _isOtfd = data.isOtfd;
      _spouseIsSt = data.spouseIsScheduledTribe;

      _familyMembers = List.from(data.familyMembers);

      // Map claims
      for (final draft in _claimDrafts) {
        final matching = data.claims.where((c) => c.code == draft.spec.code).firstOrNull;
        if (matching != null && matching.claimed) {
          draft.claimed = true;
          draft.extent.text = matching.extentHa != null ? matching.extentHa.toString() : '';
          draft.details.text = matching.details ?? '';
        } else {
          draft.claimed = false;
          draft.extent.clear();
          draft.details.clear();
        }
      }

      _evidenceList = data.evidence
          .map((e) => _EvidenceDraft(e.ruleRef, e.description))
          .toList();
    });
  }

  List<String> _splitLines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  double _calculateTotalExtent() {
    double total = 0.0;
    for (final c in _claimDrafts) {
      if (c.claimed) {
        final val = double.tryParse(c.extent.text.trim()) ?? 0.0;
        total += val;
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  Map<String, dynamic> _buildPayload() {
    final claimsMap = <String, dynamic>{};
    for (final c in _claimDrafts) {
      if (c.claimed) {
        final ext = double.tryParse(c.extent.text.trim());
        claimsMap[c.spec.code] = {
          if (ext != null) 'extent_ha': ext,
          'details': c.details.text.trim().isEmpty ? 'Claimed under ${c.spec.section}' : c.details.text.trim(),
        };
      }
    }

    return {
      'claimant_names': _splitLines(_namesCtrl.text),
      'spouse_name': _spouseCtrl.text.trim().isEmpty ? null : _spouseCtrl.text.trim(),
      'father_mother_name': _parentsCtrl.text.trim().isEmpty ? null : _parentsCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'is_scheduled_tribe': _isSt,
      'is_otfd': _isOtfd,
      'spouse_is_scheduled_tribe': _spouseIsSt,
      'family_members': _familyMembers.map((m) => m.toJson()).toList(),
      'claims': claimsMap,
      'evidence': _evidenceList
          .where((e) => e.description.text.trim().isNotEmpty)
          .map((e) => {'rule_ref': e.ruleRef, 'description': e.description.text.trim()})
          .toList(),
      'other_information': _otherCtrl.text.trim().isEmpty ? null : _otherCtrl.text.trim(),
    };
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      final updated = await formAApi.saveFormA(widget.caseId, payload);
      _applyData(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form A draft saved successfully (मसुदा जतन केला)'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (e.rule != null) ...[
                  Chip(
                    label: Text(e.rule!, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.red.shade700,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text('${e.error}: ${e.messageKey}')),
              ],
            ),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addFamilyMember() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Family Member / कुटुंब सदस्य'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
            const SizedBox(height: 8),
            TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age (वय)')),
            const SizedBox(height: 8),
            TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (उदा. मुलगा, मुलगी)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _familyMembers.add(
                    FamilyMemberItem(
                      name: nameCtrl.text.trim(),
                      age: int.tryParse(ageCtrl.text.trim()),
                      relation: relCtrl.text.trim().isEmpty ? null : relCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addEvidenceItem() {
    String selectedRule = kEvidenceRules.keys.first;
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add Rule 13 Evidence / पुरावा'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRule,
                isExpanded: true,
                items: kEvidenceRules.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDState(() => selectedRule = val);
                },
                decoration: const InputDecoration(labelText: 'Rule 13 Clause'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Evidence Description *',
                  hintText: 'e.g. Voter ID, 7/12 extract, Elder statement...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (descCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _evidenceList.add(_EvidenceDraft(selectedRule, descCtrl.text.trim()));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Evidence'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form A — IFR Claim')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _form == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form A — IFR Claim')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load Form A:\n$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final totalExt = _calculateTotalExtent();
    final exceedsLimit = totalExt > 4.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form A — Individual Claim (नमुना अ)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _editable ? Colors.green.shade700 : Colors.grey.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _editable ? 'EDITABLE DRAFT' : (_form?.state.toUpperCase() ?? 'LOCKED'),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -3))],
          ),
          child: ElevatedButton.icon(
            onPressed: (_editable && !_saving) ? _saveDraft : null,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'जतन करत आहे / Saving...' : 'मसुदा जतन करा / Save Draft', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Village Header Card
          if (_form?.header.isNotEmpty ?? false) _buildVillageHeader(),
          const SizedBox(height: 12),

          // Completeness Checklist
          _buildCompletenessCard(),
          const SizedBox(height: 16),

          // 1. Claimant Information
          _buildCard(
            title: '१-४. दावेदार तपशील / Claimant Details',
            subtitle: 'Annexure I, Items 1-4',
            children: [
              TextField(
                controller: _namesCtrl,
                enabled: _editable,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'दावेदाराचे नाव / Claimant Name(s) *',
                  hintText: 'One name per line',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spouseCtrl,
                enabled: _editable,
                decoration: const InputDecoration(
                  labelText: 'पती / पत्नीचे नाव / Spouse Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _parentsCtrl,
                enabled: _editable,
                decoration: const InputDecoration(
                  labelText: 'आई / वडिलांचे नाव / Father or Mother Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                enabled: _editable,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'पत्ता / Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Social Category (Item 9)
          _buildCard(
            title: '९. सामाजिक प्रवर्ग / Category',
            subtitle: 'Rule 11(1)(a) & Sec. 2(o)',
            children: [
              SwitchListTile(
                value: _isSt ?? false,
                onChanged: _editable ? (v) => setState(() => _isSt = v) : null,
                title: const Text('अनुसूचित जमाती (Scheduled Tribe / ST)'),
                subtitle: const Text('Section 2(o) / FDST'),
                activeColor: AppColors.primary,
              ),
              SwitchListTile(
                value: _isOtfd ?? false,
                onChanged: _editable ? (v) => setState(() => _isOtfd = v) : null,
                title: const Text('इतर पारंपारिक वननिवासी (OTFD)'),
                subtitle: const Text('In occupation for at least 3 generations (75 yrs)'),
                activeColor: AppColors.primary,
              ),
              SwitchListTile(
                value: _spouseIsSt ?? false,
                onChanged: _editable ? (v) => setState(() => _spouseIsSt = v) : null,
                title: const Text('पती/पत्नी अनुसूचित जमाती आहे? (Spouse ST?)'),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Family Members (Item 10)
          _buildCard(
            title: '१०. कुटुंब सदस्य / Family Members',
            subtitle: 'Annexure I, Item 10',
            action: _editable
                ? TextButton.icon(
                    onPressed: _addFamilyMember,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Member'),
                  )
                : null,
            children: [
              if (_familyMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No family members added yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
              else
                ..._familyMembers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final m = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${idx + 1}', style: const TextStyle(fontSize: 12))),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Age: ${m.age ?? '—'} · Relation: ${m.relation ?? '—'}'),
                    trailing: _editable
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => setState(() => _familyMembers.removeAt(idx)),
                          )
                        : null,
                  );
                }),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Claims on Land
          _buildCard(
            title: 'जमिनीवरील हक्काचे स्वरूप / Nature of Claim',
            subtitle: 'Items 1-7 of Form A',
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: exceedsLimit ? Colors.amber.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: exceedsLimit ? Colors.amber.shade400 : Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Claimed Area / एकूण क्षेत्र:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$totalExt ha (हेक्टर)', style: TextStyle(fontWeight: FontWeight.bold, color: exceedsLimit ? Colors.red.shade800 : AppColors.primary)),
                      ],
                    ),
                    if (exceedsLimit) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⚠️ Recognition is limited to land under actual occupation and cannot exceed 4.00 ha [Section 4(6)].',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              ..._claimDrafts.map((c) => _buildClaimTile(c)),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Evidence Pool (Rule 13)
          _buildCard(
            title: '८. पुराव्यांची यादी / Rule 13 Evidence',
            subtitle: 'At least 2 independent pieces of evidence required [Rule 13(1)]',
            action: _editable
                ? TextButton.icon(
                    onPressed: _addEvidenceItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Evidence'),
                  )
                : null,
            children: [
              if (_evidenceList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No evidence attached yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
              else
                ..._evidenceList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ev = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      leading: Chip(
                        label: Text(ev.ruleRef, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.blue.shade100,
                      ),
                      title: Text(ev.description.text),
                      trailing: _editable
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _evidenceList.removeAt(idx)),
                            )
                          : null,
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 16),

          // 6. Other Information
          _buildCard(
            title: 'इतर माहिती / Other Information',
            subtitle: 'Any other relevant details',
            children: [
              TextField(
                controller: _otherCtrl,
                enabled: _editable,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter any additional details or traditional notes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVillageHeader() {
    final h = _form!.header;
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${h['village_name_mr'] ?? h['village_name_en'] ?? '—'} · GP: ${h['gram_panchayat'] ?? '—'} · Taluka: ${h['taluka'] ?? '—'} · Dist: ${h['district'] ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletenessCard() {
    final done = _form?.done ?? 0;
    final total = _form?.total ?? 0;
    final percent = total > 0 ? (done / total) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Documentation Completeness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Chip(
                  label: Text('$done of $total items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: done == total ? Colors.green : AppColors.saffron,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade200,
              color: done == total ? Colors.green : AppColors.primary,
              minHeight: 6,
            ),
            if ((_form?.completeness ?? []).any((c) => !c.ok)) ...[
              const SizedBox(height: 10),
              ...(_form?.completeness ?? []).where((c) => !c.ok).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('[${item.rule}]', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.messageKey,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClaimTile(_ClaimDraft c) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.claimed ? AppColors.primary : Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: c.claimed,
        leading: Checkbox(
          value: c.claimed,
          activeColor: AppColors.primary,
          onChanged: _editable
              ? (val) {
                  setState(() {
                    c.claimed = val ?? false;
                  });
                }
              : null,
        ),
        title: Text(
          '${c.spec.formItem}. ${c.spec.labelMr}',
          style: TextStyle(fontWeight: c.claimed ? FontWeight.bold : FontWeight.normal, fontSize: 14),
        ),
        subtitle: Text('${c.spec.labelEn} (${c.spec.section})', style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: c.extent,
                  enabled: _editable && c.claimed,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Claimed Extent in Hectares (क्षेत्र हेक्टरमध्ये)',
                    hintText: 'e.g. 1.25',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: c.details,
                  enabled: _editable && c.claimed,
                  decoration: const InputDecoration(
                    labelText: 'Details / वर्णन (since when, boundaries, usage)',
                    hintText: 'Location, compartment, since which year...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
