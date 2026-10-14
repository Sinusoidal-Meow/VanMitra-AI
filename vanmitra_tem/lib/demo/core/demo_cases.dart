import 'demo_accounts.dart';
import 'demo_core.dart';

/// What the caller is allowed to see of a case: the case, its village, their roles there, and
/// whether they opened it.
class CaseCtx {
  CaseCtx(this.theCase, this.village, this.roles, this.isCreator);

  final Map<String, dynamic> theCase;
  final Map<String, dynamic> village;
  final Set<String> roles;
  final bool isCreator;

  String get state => theCase['state'] as String;
  bool get editable => state == CaseStates.draft && isCreator;
}

class CaseStates {
  CaseStates._();
  static const draft = 'draft';
  static const gsReview = 'gs_review';
  static const sdoReview = 'sdo_review';
  static const districtReview = 'district_review';
  static const titleIssued = 'title_issued';
  static const rejected = 'rejected';
  static const expired = 'expired';
}

class ClaimTypes {
  ClaimTypes._();
  static const ifr = 'ifr'; // Form A
  static const cr = 'cr'; // Form B
  static const cfr = 'cfr'; // Form C
  static const letter = {ifr: 'A', cr: 'B', cfr: 'C'};
}

/// Cases and the claim path, ported from the backend (api/v1/cases.py, workflow.py,
/// services/cases.py, domain/workflow.py):
///
///     DRAFT --submit--> GS_REVIEW --approve--> SDO_REVIEW --approve--> DISTRICT_REVIEW
///       ^   return with remarks |                  |
///       +-----------------------+------------------+      reject (reasons) --> REJECTED
///
/// The villager has 60 days from a return to resubmit. Each level is reviewed only by its own
/// role. Return and reject need written remarks (Rule 12A(7) for a rejection).
class DemoCases {
  DemoCases._();

  static const int minRemarksLength = 5;
  static const int resubmitDays = 60;

  static const Map<String, int> stage = {
    CaseStates.draft: 0,
    CaseStates.gsReview: 1,
    CaseStates.sdoReview: 2,
    CaseStates.districtReview: 3,
    CaseStates.titleIssued: 4,
  };

  static const Map<String, Set<String>> reviewers = {
    CaseStates.gsReview: {Roles.gramSabha},
    CaseStates.sdoReview: {Roles.sdo},
  };

  static const Map<String, String> approveTo = {
    CaseStates.gsReview: CaseStates.sdoReview,
    CaseStates.sdoReview: CaseStates.districtReview,
  };

  static const Set<String> finalStates = {
    CaseStates.titleIssued,
    CaseStates.rejected,
    CaseStates.expired,
  };

  static const List<String> actions = ['submit', 'approve', 'return', 'reject', 'expire'];

  /// Who may open which form (the backend's CREATORS). Form C is also opened by the village user
  /// while the app is being tested (`villager_opens_form_c`, on by default).
  static Set<String> creators(String claimType) => switch (claimType) {
        ClaimTypes.ifr => {Roles.villager},
        ClaimTypes.cr => {Roles.villager, Roles.gramSabha},
        _ => {Roles.gramSabha, Roles.villager},
      };

  // ── the rules (domain/workflow.py) ─────────────────────────────────────────

  static String resubmitDeadline(String returnedOn) =>
      dateOnly(parseDate(returnedOn).add(const Duration(days: resubmitDays)));

  /// The outcome of [action] by a user holding [actorRoles]: `(toState, actingRole)`; throws a
  /// [DemoError] when it is not allowed.
  static (String, String) decide({
    required String state,
    required String action,
    required Iterable<String> actorRoles,
    required bool isCreator,
    required String today,
    String? remarks,
    String? resubmitBy,
  }) {
    final roles = actorRoles.toSet();
    if (action == 'expire') throw DemoError(403, 'SYSTEM_ONLY', 'workflow.system_only');
    if (state == CaseStates.districtReview) {
      throw DemoError(409, 'HANDED_TO_DISTRICT', 'workflow.handed_to_district');
    }
    if (finalStates.contains(state)) {
      throw DemoError(409, 'CASE_CLOSED', 'workflow.case_closed');
    }

    if (action == 'submit') {
      if (state != CaseStates.draft) throw DemoError(409, 'NOT_A_DRAFT', 'workflow.not_a_draft');
      final filer = roles.intersection({Roles.villager, Roles.gramSabha});
      if (!isCreator || filer.isEmpty) {
        throw DemoError(403, 'ONLY_CLAIMANT_CAN_SUBMIT', 'workflow.only_claimant_submits');
      }
      if (resubmitBy != null && today.compareTo(resubmitBy) > 0) {
        throw DemoError(409, 'RESUBMIT_WINDOW_PASSED', 'workflow.resubmit_window_passed');
      }
      final acting = filer.contains(Roles.gramSabha) ? Roles.gramSabha : Roles.villager;
      return (CaseStates.gsReview, acting);
    }

    final reviewing = reviewers[state];
    if (reviewing == null) {
      throw DemoError(409, 'NOT_UNDER_REVIEW', 'workflow.not_under_review');
    }
    final held = roles.intersection(reviewing);
    if (held.isEmpty) throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');

    if (action == 'return' || action == 'reject') {
      if (remarks == null || remarks.trim().length < minRemarksLength) {
        throw DemoError(
          422,
          'REMARKS_REQUIRED',
          'workflow.remarks_required',
          rule: action == 'reject' ? 'Rule 12A(7)' : null,
        );
      }
      final acting = _pick(held);
      return action == 'return' ? (CaseStates.draft, acting) : (CaseStates.rejected, acting);
    }
    return (approveTo[state]!, _pick(held)); // approve
  }

  /// What the caller may do now (so the app shows only valid buttons).
  static List<String> allowedActions({
    required String state,
    required Iterable<String> actorRoles,
    required bool isCreator,
    required String today,
    String? resubmitBy,
  }) {
    final out = <String>[];
    for (final action in actions) {
      try {
        decide(
          state: state,
          action: action,
          actorRoles: actorRoles,
          isCreator: isCreator,
          today: today,
          remarks: 'x' * minRemarksLength,
          resubmitBy: resubmitBy,
        );
      } on DemoError {
        continue;
      }
      out.add(action);
    }
    return out;
  }

  /// The claimant always sees their case; the Gram Sabha once it was filed to it; the SDO once
  /// it reached the SDO.
  static bool canView({
    required Set<String> roles,
    required bool isCreator,
    required int reachedStage,
  }) {
    if (isCreator) return true;
    if (roles.contains(Roles.gramSabha) && reachedStage >= stage[CaseStates.gsReview]!) {
      return true;
    }
    return roles.contains(Roles.sdo) && reachedStage >= stage[CaseStates.sdoReview]!;
  }

  static String _pick(Set<String> roles) {
    const order = [
      Roles.villager,
      Roles.gramSabha,
      Roles.sdo,
      'collector',
      'dfo',
      'tribal_welfare_officer',
    ];
    final sorted = roles.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return sorted.first;
  }

  // ── loading and guards (services/cases.py) ─────────────────────────────────

  static Map<String, dynamic> villageOfGramSabha(DemoDb db, String gramSabhaId) {
    final gs = db.byId('gram_sabha', gramSabhaId);
    final village = gs == null ? null : db.byId('village', gs['village_id'] as String?);
    if (village == null) {
      throw DemoError(409, 'GRAM_SABHA_MISSING', 'village.gram_sabha_missing');
    }
    return village;
  }

  /// The case if the caller may see it; otherwise 404 (existence is not revealed).
  static CaseCtx load(DemoDb db, Principal p, String caseId) {
    final c = db.byId('claim_case', caseId);
    if (c == null) throw DemoError(404, 'CASE_NOT_FOUND', 'case.not_found');
    final village = villageOfGramSabha(db, c['gram_sabha_id'] as String);
    final roles = p.rolesFor(village);
    final mine = c['created_by_user_id'] == p.userId;
    if (!canView(roles: roles, isCreator: mine, reachedStage: c['reached_stage'] as int)) {
      throw DemoError(404, 'CASE_NOT_FOUND', 'case.not_found');
    }
    return CaseCtx(c, village, roles, mine);
  }

  /// Forms are edited only by their claimant, and only while the case is a draft.
  static void ensureEditable(CaseCtx ctx) {
    if (!ctx.isCreator) {
      throw DemoError(403, 'ONLY_CLAIMANT_CAN_EDIT', 'case.only_claimant_edits');
    }
    if (ctx.state != CaseStates.draft) {
      throw DemoError(409, 'CASE_NOT_EDITABLE', 'case.not_editable', details: {'state': ctx.state});
    }
  }

  static void ensureClaimType(CaseCtx ctx, String claimType, String error) {
    if (ctx.theCase['claim_type'] != claimType) {
      throw DemoError(409, error, 'case.wrong_form',
          details: {'claim_type': ctx.theCase['claim_type']});
    }
  }

  /// Every action on the case, oldest first.
  static List<Map<String, dynamic>> events(DemoDb db, String caseId) =>
      db.where('workflow_event', (e) => e['case_id'] == caseId);

  /// Set while the claim is a draft that was sent back and not yet resubmitted.
  static Map<String, dynamic>? returnedInfo(DemoDb db, Map<String, dynamic> c) {
    if (c['state'] != CaseStates.draft) return null;
    final ev = events(db, c['id'] as String);
    if (ev.isEmpty) return null;
    final last = ev.last;
    if (last['action'] != 'return' || last['actor_role'] == null) return null;
    final returnedOn = istDateOf(last['created_at'] as String);
    return {
      'by_role': last['actor_role'],
      'by_name': last['actor_name'],
      'remarks': last['remarks'] ?? '',
      'returned_on': returnedOn,
      'resubmit_by': resubmitDeadline(returnedOn),
    };
  }

  static String claimantLabel(Map<String, dynamic> c, Map<String, dynamic> village) {
    List names(String key) => ((c[key] as Map?)?['claimant_names'] as List?) ?? const [];
    if (c['claim_type'] == ClaimTypes.ifr && names('form_a').isNotEmpty) {
      return names('form_a').join(', ');
    }
    if (c['claim_type'] == ClaimTypes.cr && names('form_b').isNotEmpty) {
      return names('form_b').join(', ');
    }
    return 'Gram Sabha, ${village['name_en']}';
  }

  /// The backend's `CaseOut`.
  static Map<String, dynamic> caseOut(DemoDb db, CaseCtx ctx) {
    final c = ctx.theCase;
    final village = ctx.village;
    final back = returnedInfo(db, c);
    final today = db.todayIst();
    final returned = back == null
        ? null
        : {
            ...back,
            'days_left': () {
              final d = parseDate(back['resubmit_by'] as String).difference(parseDate(today)).inDays;
              return d < 0 ? 0 : d;
            }(),
          };
    return {
      'id': c['id'],
      'claim_type': c['claim_type'],
      'form': ClaimTypes.letter[c['claim_type']],
      'state': c['state'],
      'village_id': village['id'],
      'village_name_en': village['name_en'],
      'village_name_mr': village['name_mr'],
      'taluka': village['taluka'],
      'district': village['district'],
      'claimant_label': claimantLabel(c, village),
      'created_by_user_id': c['created_by_user_id'],
      'is_mine': ctx.isCreator,
      'allowed_actions': allowedActions(
        state: c['state'] as String,
        actorRoles: ctx.roles,
        isCreator: ctx.isCreator,
        today: today,
        resubmitBy: back?['resubmit_by'] as String?,
      ),
      'returned': returned,
      'created_at': c['created_at'],
      'updated_at': c['updated_at'],
    };
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _villageFor(DemoRequest req, {Iterable<String>? roles}) {
    final village = req.db.byId('village', req.params['village_id']);
    if (village == null) throw DemoError(404, 'VILLAGE_NOT_FOUND', 'village.not_found');
    if (!req.who.has(village, roles)) {
      throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village', details: {
        'village_id': village['id'],
        'required_roles': roles?.toList() ?? const [],
      });
    }
    return village;
  }

  static Map<String, dynamic> _act(
    DemoRequest req,
    String action, {
    required bool remarksInBody,
  }) {
    final db = req.db;
    final p = req.who;
    final ctx = load(db, p, req.params['case_id']!);
    final c = ctx.theCase;
    final remarks = req.json['remarks'] as String?;
    final back = returnedInfo(db, c);
    final (toState, actingRole) = () {
      try {
        return decide(
          state: c['state'] as String,
          action: action,
          actorRoles: ctx.roles,
          isCreator: ctx.isCreator,
          today: db.todayIst(),
          remarks: remarks,
          resubmitBy: back?['resubmit_by'] as String?,
        );
      } on DemoError catch (e) {
        // the real API adds the current state to the details
        throw DemoError(e.status, e.error, e.messageKey,
            rule: e.rule, details: {'state': c['state']});
      }
    }();

    if (action == 'approve' && c['state'] == CaseStates.gsReview) {
      final missing = DemoHooks.approvalMissing(db, c);
      if (missing.isNotEmpty) {
        throw DemoError(
          409,
          'GS_PREREQUISITES_MISSING',
          'approval.prerequisites_missing',
          rule: missing.first['rule'] as String?,
          details: {'missing': missing},
        );
      }
    }
    if (action == 'submit') DemoHooks.onSubmit(db, c, ctx.village);

    final event = db.add('workflow_event', {
      'case_id': c['id'],
      'action': action,
      'from_state': c['state'],
      'to_state': toState,
      'actor_user_id': p.userId,
      'actor_role': actingRole,
      'actor_name': p.name,
      'remarks': remarks,
    });
    DemoHooks.ledgerAppend(db, c['gram_sabha_id'] as String, event);
    c['state'] = toState;
    final reached = stage[toState] ?? 0;
    if (reached > (c['reached_stage'] as int)) c['reached_stage'] = reached;
    db.touch(c);
    return caseOut(db, ctx);
  }

  static void register(DemoRouter r) {
    r.post('/villages/{village_id}/cases', (req) {
      final db = req.db;
      final village = _villageFor(req, roles: [Roles.villager, Roles.gramSabha]);
      final p = req.who;
      final claimType = '${req.json['claim_type'] ?? ''}';
      if (!ClaimTypes.letter.containsKey(claimType)) {
        throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid');
      }
      final roles = p.rolesFor(village);
      final allowed = creators(claimType);
      if (roles.intersection(allowed).isEmpty) {
        throw DemoError(403, 'NOT_ALLOWED_TO_OPEN_FORM', 'case.not_allowed_to_open_form',
            details: {'claim_type': claimType, 'allowed_roles': allowed.toList()..sort()});
      }
      final gs = db.findOne('gram_sabha', (g) => g['village_id'] == village['id']);
      if (gs == null) throw DemoError(409, 'GRAM_SABHA_MISSING', 'village.gram_sabha_missing');
      final formKey = switch (claimType) {
        ClaimTypes.ifr => 'form_a',
        ClaimTypes.cr => 'form_b',
        _ => 'form_c',
      };
      final c = db.add('claim_case', {
        'gram_sabha_id': gs['id'],
        'claim_type': claimType,
        'state': CaseStates.draft,
        'created_by_user_id': p.userId,
        'reached_stage': 0,
        formKey: DemoHooks.newForm(claimType, p.userId),
      });
      return caseOut(db, CaseCtx(c, village, roles, true));
    });

    r.get('/cases/mine', (req) {
      final db = req.db;
      final p = req.who;
      final mine = db.where('claim_case', (c) => c['created_by_user_id'] == p.userId).reversed;
      return [
        for (final c in mine)
          caseOut(
            db,
            CaseCtx(
              c,
              villageOfGramSabha(db, c['gram_sabha_id'] as String),
              p.rolesFor(villageOfGramSabha(db, c['gram_sabha_id'] as String)),
              true,
            ),
          ),
      ];
    });

    r.get('/villages/{village_id}/cases', (req) {
      final db = req.db;
      final village = _villageFor(req);
      final p = req.who;
      final roles = p.rolesFor(village);
      final gs = db.findOne('gram_sabha', (g) => g['village_id'] == village['id']);
      if (gs == null) return <dynamic>[];
      final out = <Map<String, dynamic>>[];
      for (final c in db.where('claim_case', (c) => c['gram_sabha_id'] == gs['id']).reversed) {
        final mine = c['created_by_user_id'] == p.userId;
        if (canView(roles: roles, isCreator: mine, reachedStage: c['reached_stage'] as int)) {
          out.add(caseOut(db, CaseCtx(c, village, roles, mine)));
        }
      }
      return out;
    });

    r.get('/cases/{case_id}', (req) => caseOut(req.db, load(req.db, req.who, req.params['case_id']!)));

    r.post('/cases/{case_id}/submit', (req) => _act(req, 'submit', remarksInBody: false));
    r.post('/cases/{case_id}/approve', (req) => _act(req, 'approve', remarksInBody: false));
    r.post('/cases/{case_id}/return', (req) => _act(req, 'return', remarksInBody: true));
    r.post('/cases/{case_id}/reject', (req) => _act(req, 'reject', remarksInBody: true));

    r.get('/cases/{case_id}/history', (req) {
      final db = req.db;
      load(db, req.who, req.params['case_id']!);
      return [
        for (final e in events(db, req.params['case_id']!))
          {
            'action': e['action'],
            'from_state': e['from_state'],
            'to_state': e['to_state'],
            'actor_name': e['actor_name'],
            'actor_role': e['actor_role'],
            'remarks': e['remarks'],
            'at': e['created_at'],
          },
      ];
    });

    // cases waiting for the caller's decision, oldest first
    r.get('/review/queue', (req) {
      final db = req.db;
      final p = req.who;
      final waiting = db
          .where('claim_case',
              (c) => c['state'] == CaseStates.gsReview || c['state'] == CaseStates.sdoReview)
          .toList()
        ..sort((a, b) => '${a['updated_at']}'.compareTo('${b['updated_at']}'));
      final out = <Map<String, dynamic>>[];
      for (final c in waiting) {
        final village = db.byId('village', db.byId('gram_sabha', c['gram_sabha_id'] as String?)?['village_id'] as String?);
        if (village == null) continue;
        final roles = p.rolesFor(village);
        if (roles.isEmpty) continue;
        final item = caseOut(db, CaseCtx(c, village, roles, c['created_by_user_id'] == p.userId));
        if ((item['allowed_actions'] as List).contains('approve')) out.add(item);
      }
      return out;
    });
  }

  /// Seeded village id, for slices that need "the" demo village.
  static String get demoVillageId => DemoAccounts.villageId;
}
