// Data shapes returned by the backend Form B API (docs/API_FORM_B.md).

class RoleGrant {
  RoleGrant({required this.villageId, required this.villageNameMr, required this.villageNameEn, required this.role});

  factory RoleGrant.fromJson(Map<String, dynamic> j) => RoleGrant(
        villageId: j['village_id'] as String,
        villageNameMr: j['village_name_mr'] as String,
        villageNameEn: j['village_name_en'] as String,
        role: j['role'] as String,
      );

  final String villageId;
  final String villageNameMr;
  final String villageNameEn;
  final String role; // facilitator | frc_member | gs_secretary
}

class Me {
  Me({required this.name, required this.roles});

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        name: j['name'] as String,
        roles: (j['roles'] as List<dynamic>).map((e) => RoleGrant.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final String name;
  final List<RoleGrant> roles;

  /// Form B is prepared by the FRC [Rule 11(4)]; the NGO facilitator may draft it.
  bool canEditFormB(String villageId) =>
      roles.any((r) => r.villageId == villageId && (r.role == 'frc_member' || r.role == 'facilitator'));
}

class CaseSummary {
  CaseSummary({required this.id, required this.claimType, required this.state, required this.createdAt});

  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
        id: j['id'] as String,
        claimType: j['claim_type'] as String,
        state: j['state'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  final String id;
  final String claimType;
  final String state;
  final DateTime createdAt;
}

class FormBRight {
  FormBRight({
    required this.code,
    required this.formItem,
    required this.labelEn,
    required this.section,
    required this.claimed,
    required this.details,
    required this.items,
  });

  factory FormBRight.fromJson(Map<String, dynamic> j) => FormBRight(
        code: j['code'] as String,
        formItem: j['form_item'] as String,
        labelEn: j['label_en'] as String,
        section: j['section'] as String,
        claimed: j['claimed'] as bool,
        details: j['details'] as String?,
        items: (j['items'] as List<dynamic>).cast<String>(),
      );

  final String code;
  final String formItem;
  final String labelEn;
  final String section;
  final bool claimed;
  final String? details;
  final List<String> items;
}

class FormBEvidence {
  FormBEvidence({required this.ruleRef, required this.description});

  factory FormBEvidence.fromJson(Map<String, dynamic> j) =>
      FormBEvidence(ruleRef: j['rule_ref'] as String, description: j['description'] as String);

  final String ruleRef;
  final String description;
}

class CompletenessItem {
  CompletenessItem({required this.id, required this.ok, required this.formItem, required this.rule, required this.messageKey});

  factory CompletenessItem.fromJson(Map<String, dynamic> j) => CompletenessItem(
        id: j['id'] as String,
        ok: j['ok'] as bool,
        formItem: j['form_item'] as String,
        rule: j['rule'] as String,
        messageKey: j['message_key'] as String,
      );

  final String id;
  final bool ok;
  final String formItem;
  final String rule;
  final String messageKey;
}

class FormBData {
  FormBData({
    required this.caseId,
    required this.state,
    required this.editable,
    required this.header,
    required this.claimantNames,
    required this.isFdstCommunity,
    required this.isOtfdCommunity,
    required this.rights,
    required this.evidence,
    required this.otherInformation,
    required this.done,
    required this.total,
    required this.completeness,
  });

  factory FormBData.fromJson(Map<String, dynamic> j) {
    final c = j['completeness'] as Map<String, dynamic>;
    return FormBData(
      caseId: j['case_id'] as String,
      state: j['state'] as String,
      editable: j['editable'] as bool,
      header: (j['header'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString())),
      claimantNames: (j['claimant_names'] as List<dynamic>).cast<String>(),
      isFdstCommunity: j['is_fdst_community'] as bool?,
      isOtfdCommunity: j['is_otfd_community'] as bool?,
      rights: (j['rights'] as List<dynamic>).map((e) => FormBRight.fromJson(e as Map<String, dynamic>)).toList(),
      evidence: (j['evidence'] as List<dynamic>).map((e) => FormBEvidence.fromJson(e as Map<String, dynamic>)).toList(),
      otherInformation: j['other_information'] as String?,
      done: c['done'] as int,
      total: c['total'] as int,
      completeness: (c['items'] as List<dynamic>).map((e) => CompletenessItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final String caseId;
  final String state;
  final bool editable;
  final Map<String, String> header;
  final List<String> claimantNames;
  final bool? isFdstCommunity;
  final bool? isOtfdCommunity;
  final List<FormBRight> rights;
  final List<FormBEvidence> evidence;
  final String? otherInformation;
  final int done;
  final int total;
  final List<CompletenessItem> completeness;
}

/// Rule 13 sub-clauses with a short description for the picker.
const Map<String, String> kEvidenceRules = {
  '13(1)(a)': 'Public documents / Government records',
  '13(1)(b)': 'Govt. documents (voter ID, ration card…)',
  '13(1)(c)': 'Physical attributes (houses, bunds, check dams)',
  '13(1)(d)': 'Court / quasi-judicial records',
  '13(1)(e)': 'Research studies, customs & traditions',
  '13(1)(f)': 'Records of princely States / intermediaries',
  '13(1)(g)': 'Traditional structures (wells, burial grounds, sacred places)',
  '13(1)(h)': 'Genealogy',
  '13(1)(i)': 'Statement of elders (not claimants)',
  '13(2)(a)': 'Community rights such as nistar',
  '13(2)(b)': 'Grazing grounds, MFP areas, fishing, water sources',
  '13(2)(c)': 'Community structures, sacred groves, burial grounds',
  '13(2)(d)': 'Earlier classification (protected forest, gochar, nistari)',
  '13(2)(e)': 'Traditional agriculture',
};

/// Plain-language text for the completeness message keys (to move into the ARB files).
const Map<String, String> kCompletenessText = {
  'form_b.claimant_names_missing': 'Add the name of the claimant(s)',
  'form_b.community_status_unanswered': 'Answer both: FDST community? OTFD community?',
  'form_b.village_details_incomplete': 'Village details are incomplete in the registry',
  'form_b.no_right_described': 'Describe at least one community right',
  'form_b.fewer_than_two_evidences': 'List at least two pieces of evidence (Rule 13)',
};
