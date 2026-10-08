// Data shapes returned by the backend Form A API (Rule 11(1)(a)).

import '../form_b/form_b_models.dart';

class FamilyMemberItem {
  final int? seq;
  final String name;
  final int? age;
  final String? relation;

  FamilyMemberItem({
    this.seq,
    required this.name,
    this.age,
    this.relation,
  });

  factory FamilyMemberItem.fromJson(Map<String, dynamic> json) => FamilyMemberItem(
        seq: json['seq'] as int?,
        name: json['name'] as String,
        age: json['age'] as int?,
        relation: json['relation'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (seq != null) 'seq': seq,
        'name': name,
        if (age != null) 'age': age,
        if (relation != null) 'relation': relation,
      };
}

class FormAClaimSpec {
  final String code;
  final String formItem;
  final String labelEn;
  final String labelMr;
  final String section;

  const FormAClaimSpec({
    required this.code,
    required this.formItem,
    required this.labelEn,
    required this.labelMr,
    required this.section,
  });
}

const List<FormAClaimSpec> kFormAClaimSpecs = [
  FormAClaimSpec(
    code: 'habitation',
    formItem: '1(a)',
    labelEn: 'Habitation / House plot',
    labelMr: 'राहते घर / निवारा',
    section: 'Sec. 3(1)(a)',
  ),
  FormAClaimSpec(
    code: 'self_cultivation',
    formItem: '1(b)',
    labelEn: 'Self-cultivation for livelihood',
    labelMr: 'उपजीविकेसाठी स्वतःची शेती',
    section: 'Sec. 3(1)(a)',
  ),
  FormAClaimSpec(
    code: 'disputed_land',
    formItem: '2',
    labelEn: 'Disputed lands under any local law',
    labelMr: 'स्थानिक कायद्यानुसार वादग्रस्त जमीन',
    section: 'Sec. 3(1)(f)',
  ),
  FormAClaimSpec(
    code: 'patta_lease_grant',
    formItem: '3',
    labelEn: 'Pattas, leases or grants issued by Government',
    labelMr: 'शासनाने दिलेले पट्टे, भाडेपट्टे किंवा अनुदाने',
    section: 'Sec. 3(1)(g)',
  ),
  FormAClaimSpec(
    code: 'in_situ_rehabilitation',
    formItem: '4',
    labelEn: 'In-situ rehabilitation / alternative land for displaced persons',
    labelMr: 'विस्थापितांचे मूळ जागी पुनर्वसन / पर्यायी जमीन',
    section: 'Sec. 3(1)(m)',
  ),
  FormAClaimSpec(
    code: 'displaced_without_compensation',
    formItem: '5',
    labelEn: 'Land allocated to persons displaced without compensation before 2005',
    labelMr: '२००५ पूर्वी भरपाईशिवाय विस्थापित झालेल्यांना दिलेली जमीन',
    section: 'Sec. 4(8)',
  ),
  FormAClaimSpec(
    code: 'forest_village',
    formItem: '6',
    labelEn: 'Conversion of forest villages into revenue villages',
    labelMr: 'वनग्राम किंवा जुन्या वसाहतींचे महसूल गावात रूपांतरण',
    section: 'Sec. 3(1)(h)',
  ),
  FormAClaimSpec(
    code: 'other_traditional',
    formItem: '7',
    labelEn: 'Other traditional right excluding hunting',
    labelMr: 'शिकार वगळून इतर पारंपारिक हक्क',
    section: 'Sec. 3(1)(l)',
  ),
];

class FormAClaimItem {
  final String code;
  final String formItem;
  final String labelEn;
  final String section;
  final bool claimed;
  final double? extentHa;
  final String? details;

  FormAClaimItem({
    required this.code,
    required this.formItem,
    required this.labelEn,
    required this.section,
    required this.claimed,
    this.extentHa,
    this.details,
  });

  factory FormAClaimItem.fromJson(Map<String, dynamic> json) => FormAClaimItem(
        code: json['code'] as String,
        formItem: json['form_item'] as String,
        labelEn: json['label_en'] as String,
        section: json['section'] as String,
        claimed: json['claimed'] as bool,
        extentHa: (json['extent_ha'] as num?)?.toDouble(),
        details: json['details'] as String?,
      );
}

class FormAData {
  final String caseId;
  final String state;
  final bool editable;
  final Map<String, String> header;
  final List<String> claimantNames;
  final String? spouseName;
  final String? fatherMotherName;
  final String? address;
  final bool? isScheduledTribe;
  final bool? isOtfd;
  final bool? spouseIsScheduledTribe;
  final List<FamilyMemberItem> familyMembers;
  final List<FormAClaimItem> claims;
  final double totalExtentHa;
  final String? extentNote;
  final List<FormBEvidence> evidence;
  final String? otherInformation;
  final int done;
  final int total;
  final List<CompletenessItem> completeness;
  final DateTime? updatedAt;

  FormAData({
    required this.caseId,
    required this.state,
    required this.editable,
    required this.header,
    required this.claimantNames,
    this.spouseName,
    this.fatherMotherName,
    this.address,
    this.isScheduledTribe,
    this.isOtfd,
    this.spouseIsScheduledTribe,
    required this.familyMembers,
    required this.claims,
    required this.totalExtentHa,
    this.extentNote,
    required this.evidence,
    this.otherInformation,
    required this.done,
    required this.total,
    required this.completeness,
    this.updatedAt,
  });

  factory FormAData.fromJson(Map<String, dynamic> json) {
    final comp = json['completeness'] as Map<String, dynamic>? ?? {'done': 0, 'total': 0, 'items': []};
    return FormAData(
      caseId: json['case_id'] as String,
      state: json['state'] as String,
      editable: json['editable'] as bool? ?? false,
      header: (json['header'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v?.toString() ?? '')),
      claimantNames: (json['claimant_names'] as List<dynamic>? ?? []).cast<String>(),
      spouseName: json['spouse_name'] as String?,
      fatherMotherName: json['father_mother_name'] as String?,
      address: json['address'] as String?,
      isScheduledTribe: json['is_scheduled_tribe'] as bool?,
      isOtfd: json['is_otfd'] as bool?,
      spouseIsScheduledTribe: json['spouse_is_scheduled_tribe'] as bool?,
      familyMembers: (json['family_members'] as List<dynamic>? ?? [])
          .map((e) => FamilyMemberItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      claims: (json['claims'] as List<dynamic>? ?? [])
          .map((e) => FormAClaimItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalExtentHa: (json['total_extent_ha'] as num?)?.toDouble() ?? 0.0,
      extentNote: json['extent_note'] as String?,
      evidence: (json['evidence'] as List<dynamic>? ?? [])
          .map((e) => FormBEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
      otherInformation: json['other_information'] as String?,
      done: comp['done'] as int? ?? 0,
      total: comp['total'] as int? ?? 0,
      completeness: (comp['items'] as List<dynamic>? ?? [])
          .map((e) => CompletenessItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String)?.toLocal() : null,
    );
  }
}
