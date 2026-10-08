// Data shapes returned by the backend Form B API (docs/API_FORM_B.md).

class RoleGrant {
  RoleGrant({required this.villageId, required this.villageNameMr, required this.villageNameEn, required this.role});

  factory RoleGrant.fromJson(Map<String, dynamic> j) => RoleGrant(
        villageId: j['village_id'] as String?,
        villageNameMr: j['village_name_mr'] as String? ?? '',
        villageNameEn: j['village_name_en'] as String? ?? '',
        role: j['role'] as String,
      );

  /// Empty for the SDO, whose role covers a whole taluka.
  final String? villageId;
  final String villageNameMr;
  final String villageNameEn;
  final String role; // villager | gram_sabha | sdo
}

class Me {
  Me({required this.name, required this.roles});

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        name: j['name'] as String,
        roles: (j['roles'] as List<dynamic>).map((e) => RoleGrant.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final String name;
  final List<RoleGrant> roles;

  bool _has(String villageId, Set<String> wanted) =>
      roles.any((r) => r.villageId == villageId && wanted.contains(r.role));

  /// Form B (community rights) is filed by a villager or by the Gram Sabha.
  bool canEditFormB(String villageId) => _has(villageId, {'villager', 'gram_sabha'});

  /// Form C (community forest resource) is the Gram Sabha's own claim.
  bool canEditFormC(String villageId) => _has(villageId, {'gram_sabha'});

  /// The Gram Sabha keeps its member roster.
  bool canEditRoster(String villageId) => _has(villageId, {'gram_sabha'});
}

/// Why a claim was sent back to the villager, and how long is left to resubmit it.
class ReturnedInfo {
  ReturnedInfo({
    required this.byRole,
    required this.byName,
    required this.remarks,
    required this.resubmitBy,
    required this.daysLeft,
  });

  factory ReturnedInfo.fromJson(Map<String, dynamic> j) => ReturnedInfo(
        byRole: j['by_role'] as String,
        byName: j['by_name'] as String,
        remarks: j['remarks'] as String,
        resubmitBy: DateTime.parse(j['resubmit_by'] as String),
        daysLeft: j['days_left'] as int,
      );

  final String byRole; // gram_sabha | sdo
  final String byName;
  final String remarks;
  final DateTime resubmitBy;
  final int daysLeft;
}

class CaseSummary {
  CaseSummary({
    required this.id,
    required this.claimType,
    required this.state,
    required this.createdAt,
    this.returned,
  });

  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
        id: j['id'] as String,
        claimType: j['claim_type'] as String,
        state: j['state'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        returned: j['returned'] == null ? null : ReturnedInfo.fromJson(j['returned'] as Map<String, dynamic>),
      );

  final String id;
  final String claimType;
  final String state;
  final DateTime createdAt;

  /// Set while the claim waits for the villager to correct and resubmit it.
  final ReturnedInfo? returned;
}

/// A message for the signed-in user (also sent to the phone as a push message).
class AppNotification {
  AppNotification({
    required this.id,
    required this.caseId,
    required this.kind,
    required this.titleEn,
    required this.bodyEn,
    required this.titleMr,
    required this.bodyMr,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        caseId: j['case_id'] as String?,
        kind: j['kind'] as String,
        titleEn: j['title_en'] as String,
        bodyEn: j['body_en'] as String,
        titleMr: j['title_mr'] as String,
        bodyMr: j['body_mr'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        read: j['read'] as bool,
      );

  final String id;
  final String? caseId;
  final String kind;
  final String titleEn;
  final String bodyEn;
  final String titleMr;
  final String bodyMr;
  final DateTime createdAt;
  final bool read;
}

class NotificationsPage {
  NotificationsPage({required this.unread, required this.items});

  factory NotificationsPage.fromJson(Map<String, dynamic> j) => NotificationsPage(
        unread: j['unread'] as int,
        items: (j['items'] as List<dynamic>)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int unread;
  final List<AppNotification> items;
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
