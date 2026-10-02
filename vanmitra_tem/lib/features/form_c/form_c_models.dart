// Data shapes returned by the backend Form C and member APIs (docs/API_FORM_C.md).

import '../form_b/form_b_models.dart';

class GsMember {
  GsMember({required this.id, required this.name, required this.gender, required this.category, required this.active});

  factory GsMember.fromJson(Map<String, dynamic> j) => GsMember(
        id: j['id'] as String,
        name: j['name'] as String,
        gender: j['gender'] as String,
        category: j['category'] as String,
        active: j['active'] as bool,
      );

  final String id;
  final String name;
  final String gender; // female | male | other
  final String category; // st | otfd | other
  final bool active;
}

class FormCLandmark {
  FormCLandmark({required this.side, required this.kind, required this.name, this.description});

  factory FormCLandmark.fromJson(Map<String, dynamic> j) => FormCLandmark(
        side: j['side'] as String,
        kind: j['kind'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
      );

  final String side;
  final String kind;
  final String name;
  final String? description;
}

class FormCBorderingVillage {
  FormCBorderingVillage({required this.name, required this.sharesResources, this.sharingDetails});

  factory FormCBorderingVillage.fromJson(Map<String, dynamic> j) => FormCBorderingVillage(
        name: j['name'] as String,
        sharesResources: j['shares_resources'] as bool,
        sharingDetails: j['sharing_details'] as String?,
      );

  final String name;
  final bool sharesResources;
  final String? sharingDetails;
}

class FormCData {
  FormCData({
    required this.caseId,
    required this.editable,
    required this.header,
    required this.memberTotal,
    required this.memberSt,
    required this.memberOtfd,
    required this.members,
    required this.resolutionStatement,
    required this.areaDescription,
    required this.approxAreaHa,
    required this.pastoralSeasonalUse,
    required this.seasonalUseDetails,
    required this.landmarks,
    required this.khasraNumbers,
    required this.borderingVillages,
    required this.evidence,
    required this.done,
    required this.total,
    required this.completeness,
  });

  factory FormCData.fromJson(Map<String, dynamic> j) {
    final sheet = j['member_sheet'] as Map<String, dynamic>;
    final c = j['completeness'] as Map<String, dynamic>;
    return FormCData(
      caseId: j['case_id'] as String,
      editable: j['editable'] as bool,
      header: (j['header'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString())),
      memberTotal: sheet['total'] as int,
      memberSt: sheet['st'] as int,
      memberOtfd: sheet['otfd'] as int,
      members: (sheet['members'] as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>))
          .map((e) => MapEntry(e['name'] as String, e['category'] as String))
          .toList(),
      resolutionStatement: j['resolution_statement'] as String,
      areaDescription: j['area_description'] as String?,
      approxAreaHa: (j['approx_area_ha'] as num?)?.toDouble(),
      pastoralSeasonalUse: j['pastoral_seasonal_use'] as bool,
      seasonalUseDetails: j['seasonal_use_details'] as String?,
      landmarks: (j['landmarks'] as List<dynamic>).map((e) => FormCLandmark.fromJson(e as Map<String, dynamic>)).toList(),
      khasraNumbers: (j['khasra_compartment_numbers'] as List<dynamic>).cast<String>(),
      borderingVillages: (j['bordering_villages'] as List<dynamic>)
          .map((e) => FormCBorderingVillage.fromJson(e as Map<String, dynamic>))
          .toList(),
      evidence: (j['evidence'] as List<dynamic>).map((e) => FormBEvidence.fromJson(e as Map<String, dynamic>)).toList(),
      done: c['done'] as int,
      total: c['total'] as int,
      completeness: (c['items'] as List<dynamic>).map((e) => CompletenessItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final String caseId;
  final bool editable;
  final Map<String, String> header;
  final int memberTotal;
  final int memberSt;
  final int memberOtfd;
  final List<MapEntry<String, String>> members; // name → category
  final String resolutionStatement;
  final String? areaDescription;
  final double? approxAreaHa;
  final bool pastoralSeasonalUse;
  final String? seasonalUseDetails;
  final List<FormCLandmark> landmarks;
  final List<String> khasraNumbers;
  final List<FormCBorderingVillage> borderingVillages;
  final List<FormBEvidence> evidence;
  final int done;
  final int total;
  final List<CompletenessItem> completeness;
}

/// Boundary sides (चतु:सीमा) with English and Marathi labels.
const Map<String, String> kBoundarySides = {
  'east': 'East · पूर्व',
  'west': 'West · पश्चिम',
  'north': 'North · उत्तर',
  'south': 'South · दक्षिण',
  'within': 'Inside the area',
};

const Map<String, String> kLandmarkKinds = {
  'river': 'River · नदी',
  'stream': 'Stream · नाला',
  'spring': 'Spring · झरा',
  'pond': 'Pond · तलाव',
  'sacred_place': 'Sacred place · देवस्थान',
  'sacred_grove': 'Sacred grove / tree · देवराई',
  'burial_ground': 'Burial / cremation ground',
  'well': 'Well · विहीर',
  'road': 'Road / path · रस्ता',
  'compartment_pillar': 'Compartment pillar',
  'hill': 'Hill · डोंगर',
  'other': 'Other',
};

const Map<String, String> kMemberCategories = {'st': 'ST', 'otfd': 'OTFD', 'other': 'Other'};

/// Plain-language text for the Form C completeness keys (to move into the ARB files).
const Map<String, String> kFormCCompletenessText = {
  'form_c.village_details_incomplete': 'Village details are incomplete in the registry',
  'form_c.member_sheet_missing_st_otfd': 'Gram Sabha member list needs at least one ST or OTFD member',
  'form_c.resolution_statement_missing': 'Add the resolving statement',
  'form_c.area_not_described': 'Describe the community forest resource area',
  'form_c.boundary_landmarks_missing': 'Give a landmark for each of the four boundaries (E, W, N, S)',
  'form_c.no_bordering_village': 'List the bordering villages',
  'form_c.fewer_than_two_general_evidences': 'List at least two Rule 13(1) evidences',
  'form_c.no_cfr_evidence': 'List at least one Rule 13(2) community-forest evidence',
};
