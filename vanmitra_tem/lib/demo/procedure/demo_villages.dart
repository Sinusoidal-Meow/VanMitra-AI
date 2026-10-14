import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'procedure_domain.dart';
import 'procedure_support.dart';

/// Village registry [Rule 2A], the Forest Rights Committee [Rule 3] and case claimants, ported
/// from the backend's api/v1/villages.py.
///
/// - Villages and hamlets are created by the admin (master data, not free text).
/// - The FRC is constituted by the Gram Sabha; the Rule 3(1) arithmetic is checked and stored
///   with the committee (BR-01).
/// - Claimants of a case are Gram Sabha members; they drive recusal (BR-02).
///
/// Tables: `village`, `gram_sabha`, `frc` (members embedded as `{gs_member_id, is_chair,
/// is_secretary}`), `case_claimant`; reads `gs_member`.
class DemoVillages {
  DemoVillages._();

  static const Set<String> consolidationStatuses = {
    'recognised',
    'listed',
    'consolidated',
    'finalised',
  };

  // ── outputs ─────────────────────────────────────────────────────────────────

  /// The backend's `VillageOut`.
  static Map<String, dynamic> villageOut(DemoDb db, Map<String, dynamic> v) {
    final gs = db.findOne('gram_sabha', (g) => g['village_id'] == v['id']);
    return {
      'id': v['id'],
      'name_mr': v['name_mr'],
      'name_en': v['name_en'],
      'gram_panchayat': v['gram_panchayat'],
      'taluka': v['taluka'],
      'district': v['district'],
      'state': v['state'],
      'lgd_code': v['lgd_code'],
      'parent_village_id': v['parent_village_id'],
      'consolidation_status': v['consolidation_status'],
      'gram_sabha_id': gs?['id'],
    };
  }

  static Map<String, dynamic> _memberOut(Map<String, dynamic> m) => {
        'gs_member_id': m['id'],
        'name': m['name'],
        'gender': m['gender'],
        'category': m['category'],
      };

  /// The backend's `FrcOut`.
  static Map<String, dynamic> frcOut(DemoDb db, Map<String, dynamic> frc) {
    final fms = ProcedureGuards.stableSorted<Map<String, dynamic>>(
      ((frc['members'] as List?) ?? const []).cast<Map<String, dynamic>>(),
      (a, b) {
        final byChair = (a['is_chair'] == true ? 0 : 1).compareTo(b['is_chair'] == true ? 0 : 1);
        if (byChair != 0) return byChair;
        return (a['is_secretary'] == true ? 0 : 1).compareTo(b['is_secretary'] == true ? 0 : 1);
      },
    );
    final members = <Map<String, dynamic>>[];
    for (final fm in fms) {
      final m = db.byId('gs_member', fm['gs_member_id'] as String?);
      if (m == null) continue;
      members.add({
        ..._memberOut(m),
        'is_chair': fm['is_chair'] == true,
        'is_secretary': fm['is_secretary'] == true,
      });
    }
    return {
      'id': frc['id'],
      'constituted_on': frc['constituted_on'],
      'resolution_ref': frc['resolution_ref'],
      'sdlc_intimated_on': frc['sdlc_intimated_on'],
      'is_current': frc['is_current'],
      'composition': Map<String, dynamic>.from(frc['composition_proof'] as Map),
      'members': members,
    };
  }

  // ── the FRC check ───────────────────────────────────────────────────────────

  /// Read the common FRC body (`FrcCheckIn`): the members chosen and the two office-bearers.
  static ({List<String> ids, String? chair, String? secretary}) _readCheckIn(Input input) => (
        ids: input.uuidList('member_ids', max: 30) ?? <String>[],
        chair: input.uuid('chair_id', required: false, nullable: true),
        secretary: input.uuid('secretary_id', required: false, nullable: true),
      );

  /// The Rule 3(1) arithmetic for the chosen members, and the members as found in the roster.
  static (FrcCheck, List<Map<String, dynamic>>) _check(
    DemoDb db,
    Map<String, dynamic> gs,
    List<String> memberIds,
    String? chairId,
    String? secretaryId,
  ) {
    final wanted = memberIds.toSet();
    final members = memberIds.isEmpty
        ? <Map<String, dynamic>>[]
        : db.where('gs_member', (m) => wanted.contains(m['id']) && m['active'] == true);
    final foreign = members.where((m) => m['gram_sabha_id'] != gs['id']);
    if (foreign.isNotEmpty || members.length != wanted.length) {
      throw DemoError(422, 'FRC_MEMBER_NOT_IN_ROSTER', 'frc.member_not_in_roster',
          details: {'known': members.length, 'given': wanted.length});
    }
    final hasSt = db.findOne(
          'gs_member',
          (m) => m['gram_sabha_id'] == gs['id'] && m['active'] == true && m['category'] == 'st',
        ) !=
        null;
    final byId = {for (final m in members) m['id'] as String: m};
    final result = FrcRules.check(
      [
        for (final id in memberIds)
          FrcCandidate(id, byId[id]!['gender'] as String, byId[id]!['category'] as String),
      ],
      gramSabhaHasSt: hasSt,
      chairId: chairId,
      secretaryId: secretaryId,
    );
    return (result, members);
  }

  static Map<String, dynamic> _currentFrc(DemoDb db, Map<String, dynamic> gs) {
    final frc = db.findOne('frc', (f) => f['gram_sabha_id'] == gs['id'] && f['is_current'] == true);
    if (frc == null) throw DemoError(404, 'FRC_NOT_CONSTITUTED', 'frc.not_constituted');
    return frc;
  }

  static List<Map<String, dynamic>> _claimantsOut(DemoDb db, String caseId) {
    final ids = {
      for (final c in db.where('case_claimant', (c) => c['case_id'] == caseId))
        c['gs_member_id'] as String,
    };
    if (ids.isEmpty) return <Map<String, dynamic>>[];
    final members = ProcedureGuards.stableSorted(
      db.where('gs_member', (m) => ids.contains(m['id'])),
      (a, b) => '${a['name']}'.compareTo('${b['name']}'),
    );
    return [for (final m in members) _memberOut(m)];
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    // ── village registry ──

    // admin adds a village or hamlet; its Gram Sabha is created with it
    r.post('/admin/villages', (req) {
      final db = req.db;
      ProcedureGuards.admin(req);
      final input = Input(req.body);
      final nameMr = input.text('name_mr', max: 200);
      final nameEn = input.text('name_en', max: 200);
      final panchayat = input.text('gram_panchayat', max: 200);
      final taluka = input.text('taluka', max: 100);
      final district = input.text('district', max: 100);
      final state = input.text('state', required: false, max: 100) ?? 'Maharashtra';
      final lgd = input.text('lgd_code', required: false, nullable: true, min: 0, max: 20);
      final parentId = input.uuid('parent_village_id', required: false, nullable: true);
      final status =
          input.choice('consolidation_status', consolidationStatuses, defaultValue: 'recognised');
      input.done();

      if (parentId != null && db.byId('village', parentId) == null) {
        throw DemoError(422, 'PARENT_VILLAGE_NOT_FOUND', 'village.parent_not_found');
      }
      if (lgd != null && lgd.isNotEmpty && db.findOne('village', (v) => v['lgd_code'] == lgd) != null) {
        throw DemoError(409, 'LGD_CODE_TAKEN', 'village.lgd_code_taken');
      }
      final village = db.add('village', {
        'name_mr': nameMr,
        'name_en': nameEn,
        'gram_panchayat': panchayat,
        'taluka': taluka,
        'district': district,
        'state': state,
        'lgd_code': lgd,
        'parent_village_id': parentId,
        'consolidation_status': status,
      });
      db.add('gram_sabha', {
        'village_id': village['id'],
        'chain_head_hash': null,
        'chain_length': 0,
      });
      return villageOut(db, village);
    });

    r.patch('/admin/villages/{village_id}', (req) {
      final db = req.db;
      ProcedureGuards.admin(req);
      final input = Input(req.body);
      final updates = <String, Object?>{};
      void keep(String field, Object? value) {
        if (input.has(field) && value != null) updates[field] = value;
      }

      keep('name_mr', input.text('name_mr', required: false, nullable: true, max: 200));
      keep('name_en', input.text('name_en', required: false, nullable: true, max: 200));
      keep('gram_panchayat', input.text('gram_panchayat', required: false, nullable: true, max: 200));
      keep('taluka', input.text('taluka', required: false, nullable: true, max: 100));
      keep('district', input.text('district', required: false, nullable: true, max: 100));
      keep('lgd_code',
          input.text('lgd_code', required: false, nullable: true, min: 0, max: 20, strip: false));
      if (input.raw('consolidation_status') != null) {
        keep('consolidation_status', input.choice('consolidation_status', consolidationStatuses));
      }
      input.done();

      final village = db.byId('village', req.params['village_id']);
      if (village == null) throw DemoError(404, 'VILLAGE_NOT_FOUND', 'village.not_found');
      village.addAll(updates);
      db.touch(village);
      return villageOut(db, village);
    });

    r.get('/villages/{village_id}', (req) =>
        villageOut(req.db, ProcedureGuards.village(req)));

    // hamlets, padas and habitations listed under this village [Rule 2A]
    r.get('/villages/{village_id}/hamlets', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req);
      final rows = ProcedureGuards.stableSorted(
        db.where('village', (v) => v['parent_village_id'] == village['id']),
        (a, b) => '${a['name_en']}'.compareTo('${b['name_en']}'),
      );
      return [for (final v in rows) villageOut(db, v)];
    });

    // ── Forest Rights Committee ──

    // live composition check while the FRC is being chosen (nothing is saved)
    r.post('/villages/{village_id}/frc/check', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final body = _readCheckIn(input);
      input.done();
      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      final (result, _) = _check(db, gs, body.ids, body.chair, body.secretary);
      return result.proof();
    });

    // record the FRC elected by the Gram Sabha; refused unless Rule 3(1) is met (BR-01)
    r.post('/villages/{village_id}/frc', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final body = _readCheckIn(input);
      final constitutedOn = input.date('constituted_on');
      final resolutionRef = input.text('resolution_ref', required: false, nullable: true, max: 200);
      input.done();

      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      final (result, members) = _check(db, gs, body.ids, body.chair, body.secretary);
      if (!result.ok) {
        throw DemoError(
          409,
          'FRC_COMPOSITION_INVALID',
          result.failures.first,
          rule: 'Rule 3(1)',
          details: {'failures': List<String>.from(result.failures), ...result.proof()},
        );
      }
      for (final old in db.where(
        'frc',
        (f) => f['gram_sabha_id'] == gs['id'] && f['is_current'] == true,
      )) {
        old['is_current'] = false;
        db.touch(old);
      }
      final frc = db.add('frc', {
        'gram_sabha_id': gs['id'],
        'constituted_on': constitutedOn,
        'resolution_ref': resolutionRef,
        'sdlc_intimated_on': null,
        'composition_proof': result.proof(),
        'is_current': true,
        'created_by_user_id': req.who.userId,
        'members': [
          for (final m in members)
            {
              'gs_member_id': m['id'],
              'is_chair': m['id'] == body.chair,
              'is_secretary': m['id'] == body.secretary,
            },
        ],
      });
      return frcOut(db, frc);
    });

    // the current FRC with its stored composition proof (data for the G3 certificate)
    r.get('/villages/{village_id}/frc', (req) {
      final village = ProcedureGuards.village(req);
      final gs = ProcedureGuards.gramSabha(req.db, village['id'] as String);
      return frcOut(req.db, _currentFrc(req.db, gs));
    });

    r.get('/villages/{village_id}/frc/history', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req);
      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      final rows = ProcedureGuards.stableSorted(
        db.where('frc', (f) => f['gram_sabha_id'] == gs['id']).reversed,
        (a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'),
      );
      return [for (final f in rows) frcOut(db, f)];
    });

    // the date the chairperson and secretary were intimated to the SDLC [Rule 3(1)]
    r.post('/villages/{village_id}/frc/intimation', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final on = input.date('sdlc_intimated_on');
      input.done();

      final frc = _currentFrc(db, ProcedureGuards.gramSabha(db, village['id'] as String));
      if (on!.compareTo(frc['constituted_on'] as String) < 0) {
        throw DemoError(
            422, 'INTIMATION_BEFORE_CONSTITUTION', 'frc.intimation_before_constitution');
      }
      frc['sdlc_intimated_on'] = on;
      db.touch(frc);
      return frcOut(db, frc);
    });

    // ── claimants per case ──

    r.get('/cases/{case_id}/claimants', (req) {
      final p = req.who;
      DemoCases.load(req.db, p, req.params['case_id']!);
      return _claimantsOut(req.db, req.params['case_id']!);
    });

    // the Gram Sabha members who are claimants in this case (claimant edits, draft only); used
    // for recusal [Rule 3(3)], the elder-statement check and quorum test 3 [Rule 4(2)]
    r.put('/cases/{case_id}/claimants', (req) {
      final db = req.db;
      final p = req.who;
      final input = Input(req.body);
      final memberIds = input.uuidList('member_ids', max: 500);
      input.done();

      final caseId = req.params['case_id']!;
      final ctx = DemoCases.load(db, p, caseId);
      DemoCases.ensureEditable(ctx);
      final ids = memberIds!.toSet();
      final members = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : db.where(
              'gs_member',
              (m) => ids.contains(m['id']) && m['gram_sabha_id'] == ctx.theCase['gram_sabha_id'],
            );
      if (members.length != ids.length) {
        throw DemoError(422, 'CLAIMANT_NOT_IN_ROSTER', 'case.claimant_not_in_roster');
      }
      db.table('case_claimant').removeWhere((c) => c['case_id'] == caseId);
      for (final m in members) {
        db.add('case_claimant', {'case_id': caseId, 'gs_member_id': m['id']});
      }
      return _claimantsOut(db, caseId);
    });
  }
}
