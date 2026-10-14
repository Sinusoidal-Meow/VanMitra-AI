import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'demo_fields.dart';
import 'demo_ledger.dart';
import 'demo_quorum.dart';

/// The Gram Sabha: meetings, attendance, quorum, resolutions, members, field verification, the
/// approval check and the tamper-evident ledger. Ported from the backend: api/v1/gramsabha.py,
/// members.py, services/gramsabha.py, services/ledger.py, domain/quorum.py.
///
/// Tables (named like the backend's collections): `gs_meeting` (attendance embedded),
/// `resolution`, `verification_proceeding`, `recusal`, `ledger_entry`, and `gs_member`.
/// Read from others: `case_claimant`, `correspondence`, `media`, `cfr_boundary` (segments and
/// landmarks embedded), `dispute`, `app_user`.
class DemoGramSabha {
  DemoGramSabha._();

  static const Set<String> _closed = {CaseStates.rejected, CaseStates.expired};
  static const List<String> _genders = ['female', 'male', 'other'];
  static const List<String> _categories = ['st', 'otfd', 'other'];

  // ── facts (services/gramsabha.py) ──────────────────────────────────────────

  static Map<String, dynamic>? latestVerification(DemoDb db, String caseId) {
    Map<String, dynamic>? best;
    for (final v in db.where('verification_proceeding', (v) => v['case_id'] == caseId)) {
      if (best == null || (v['attempt_no'] as int) > (best['attempt_no'] as int)) best = v;
    }
    return best;
  }

  /// Both departments signed, or their absence is recorded (BR-07).
  static bool verificationComplete(Map<String, dynamic>? v) {
    if (v == null) return false;
    final forest = v['forest_signed'] == true || v['forest_absence_recorded'] == true;
    final revenue = v['revenue_signed'] == true || v['revenue_absence_recorded'] == true;
    return forest && revenue;
  }

  /// Absent on a second visit: the Gram Sabha decision stands [Rule 12A(2)].
  static bool finalityNote(Map<String, dynamic>? v) =>
      v != null &&
      (v['attempt_no'] as int) >= 2 &&
      (v['forest_absence_recorded'] == true || v['revenue_absence_recorded'] == true) &&
      verificationComplete(v);

  /// The newest resolution on the claim that no later one replaced.
  static Map<String, dynamic>? currentResolution(DemoDb db, String caseId) {
    final rows = db.where('resolution', (r) => r['case_id'] == caseId);
    final superseded = {
      for (final r in rows)
        if (r['supersedes_id'] != null) r['supersedes_id']
    };
    final live = [
      for (final r in rows)
        if (!superseded.contains(r['id'])) r
    ];
    return live.isEmpty ? null : live.last;
  }

  static List<Map<String, dynamic>> _attendance(Map<String, dynamic> meeting) =>
      ((meeting['attendance'] as List?) ?? const []).cast<Map<String, dynamic>>();

  /// (present, women present) from the attendance register.
  static (int, int) meetingCounts(DemoDb db, Map<String, dynamic> meeting) {
    final present = [
      for (final a in _attendance(meeting))
        if (a['present'] == true) a['gs_member_id'] as String,
    ];
    if (present.isEmpty) return (0, 0);
    final women = present.where((id) => db.byId('gs_member', id)?['gender'] == 'female').length;
    return (present.length, women);
  }

  /// (claimants in the case, of whom present at the meeting).
  static (int, int) claimantCounts(DemoDb db, Map<String, dynamic> meeting, String caseId) {
    final claimants = {
      for (final c in db.where('case_claimant', (c) => c['case_id'] == caseId))
        c['gs_member_id'] as String,
    };
    if (claimants.isEmpty) return (0, 0);
    final present = {
      for (final a in _attendance(meeting))
        if (a['present'] == true) a['gs_member_id'] as String,
    };
    return (claimants.length, claimants.intersection(present).length);
  }

  // ── the boundary, as the Gram Sabha sees it (services/boundary.py) ─────────

  static Map<String, dynamic>? currentBoundary(DemoDb db, String caseId) => db.findOne(
        'cfr_boundary',
        (b) => b['case_id'] == caseId && b['is_current'] == true,
      );

  static int _segmentsWithoutLandmark(Map<String, dynamic> b) {
    final marked = {
      for (final l in ((b['landmarks'] as List?) ?? const []).cast<Map>()) l['segment_seq'],
    };
    return ((b['segments'] as List?) ?? const [])
        .cast<Map>()
        .where((s) => !marked.contains(s['seq']))
        .length;
  }

  static bool _isOpen(Map<String, dynamic> d) {
    if (d['sdlc_referral_on'] != null) return false;
    final ha = num.tryParse('${d['overlap_ha'] ?? 0}') ?? 0;
    if (ha <= 0) return false;
    final outcome = d['outcome'];
    return outcome == null || outcome == 'not_resolved';
  }

  /// Open overlaps of this claim with a neighbour's claim that still stands.
  static int openDisputes(DemoDb db, String caseId) {
    var count = 0;
    final involving =
        db.where('dispute', (d) => d['case_id'] == caseId || d['neighbour_case_id'] == caseId);
    for (final d in involving) {
      if (!_isOpen(d)) continue;
      final c1 = db.byId('claim_case', d['case_id'] as String?);
      final c2 = db.byId('claim_case', d['neighbour_case_id'] as String?);
      if (c1 != null &&
          !_closed.contains(c1['state']) &&
          c2 != null &&
          !_closed.contains(c2['state'])) {
        count++;
      }
    }
    return count;
  }

  /// Freeze the version the Gram Sabha approved: a hash of its geometry and landmarks.
  static void seal(DemoDb db, Map<String, dynamic> b) {
    final landmarks = ((b['landmarks'] as List?) ?? const []).cast<Map>().toList()
      ..sort((a, c) {
        final bySeq = (a['segment_seq'] as int).compareTo(c['segment_seq'] as int);
        return bySeq != 0 ? bySeq : '${a['name']}'.compareTo('${c['name']}');
      });
    final marks = [
      for (final l in landmarks) [l['segment_seq'], l['name'], l['point']],
    ];
    b['sealed_hash'] =
        DemoLedger.sha256Hex(DemoLedger.canonicalPayload([b['geom'], marks], asciiOnly: true));
    b['status'] = 'gs_approved';
    b['approved_on'] = db.todayIst();
  }

  // ── the approval check (services/gramsabha.py `approval_check`) ────────────

  /// Everything a Gram Sabha needs before forwarding [theCase], each `{id, ok, rule,
  /// message_key}`. Form A and Form B claims have no prerequisites; a Form C (CFR) claim needs a
  /// resolution that passed quorum, an approved boundary, a closed field verification and no
  /// open overlap [Sec 6(1), Rule 12(1)(g), Rule 12A(1)(2), Rule 12(3)].
  static List<Map<String, dynamic>> approvalItems(DemoDb db, Map<String, dynamic> theCase) {
    if (theCase['claim_type'] != ClaimTypes.cfr) return [];
    final caseId = theCase['id'] as String;
    final b = currentBoundary(db, caseId);
    final approved = b != null && (b['status'] == 'gs_approved' || b['status'] == 'titled');
    final res = currentResolution(db, caseId);
    final proof = res?['quorum_proof'];
    return [
      {
        'id': 'resolution',
        'ok': res != null && proof is Map && proof['passed'] == true,
        'rule': 'Sec 6(1), Rule 4(2)',
        'message_key': 'approval.resolution_needed',
      },
      {
        'id': 'boundary',
        'ok': approved,
        'rule': 'Rule 12(1)(g)',
        'message_key': 'approval.boundary_not_approved',
      },
      {
        'id': 'verification',
        'ok': verificationComplete(latestVerification(db, caseId)),
        'rule': 'Rule 12A(1)(2)',
        'message_key': 'approval.verification_open',
      },
      {
        'id': 'disputes',
        'ok': openDisputes(db, caseId) == 0,
        'rule': 'Rule 12(3)',
        'message_key': 'approval.dispute_open',
      },
    ];
  }

  /// The backend's `ApprovalCheckOut`.
  static Map<String, dynamic> approvalCheck(DemoDb db, Map<String, dynamic> theCase) {
    final items = approvalItems(db, theCase);
    return {
      'case_id': theCase['id'],
      'ready': items.every((i) => i['ok'] == true),
      'items': items,
    };
  }

  // ── guards ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _gs(DemoDb db, String villageId) {
    final gs = db.findOne('gram_sabha', (g) => g['village_id'] == villageId);
    if (gs == null) throw DemoError(409, 'GRAM_SABHA_MISSING', 'village.gram_sabha_missing');
    return gs;
  }

  /// The village in the path, for a caller holding one of [roles] there (any role when null).
  static (Principal, Map<String, dynamic>) _scope(DemoRequest req, [List<String>? roles]) {
    final p = req.who;
    final id = requireUuid('path', 'village_id', req.params['village_id']!);
    final village = req.db.byId('village', id);
    if (village == null) throw DemoError(404, 'VILLAGE_NOT_FOUND', 'village.not_found');
    if (!p.has(village, roles)) {
      throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village', details: {
        'village_id': id,
        'required_roles': roles ?? const <String>[],
      });
    }
    return (p, village);
  }

  static CaseCtx _gsCase(DemoDb db, Principal p, String caseId) {
    final ctx = DemoCases.load(db, p, caseId);
    if (!ctx.roles.contains(Roles.gramSabha)) {
      throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');
    }
    return ctx;
  }

  /// A Gram Sabha member who is a claimant takes no part in deciding the claim (BR-02).
  static void _recuseIfClaimant(DemoDb db, Principal p, String caseId) {
    final memberId = db.byId('app_user', p.userId)?['gs_member_id'] as String?;
    if (memberId == null) return;
    final isClaimant = db.findOne(
            'case_claimant', (c) => c['case_id'] == caseId && c['gs_member_id'] == memberId) !=
        null;
    if (!isClaimant) return;
    final recused =
        db.findOne('recusal', (c) => c['case_id'] == caseId && c['gs_member_id'] == memberId) !=
            null;
    if (!recused) {
      db.add('recusal', {
        'case_id': caseId,
        'gs_member_id': memberId,
        'reason': 'Claimant in this case; may not decide it [Rule 3(3)]',
        'recorded_at': db.nowIso(),
      });
    }
    throw DemoError(409, 'CLAIMANT_RECUSED', 'case.claimant_recused', rule: 'Rule 3(3)');
  }

  static void _ownMedia(DemoDb db, Principal p, String? mediaId) {
    if (mediaId == null) return;
    final media = db.byId('media', mediaId);
    if (media == null || media['uploaded_by_user_id'] != p.userId) {
      throw DemoError(422, 'MEDIA_NOT_YOURS', 'evidence.media_not_yours',
          details: {'media_id': mediaId});
    }
  }

  static Map<String, dynamic> _meeting(DemoDb db, Principal p, String meetingId,
      {required bool write}) {
    final m = db.byId('gs_meeting', meetingId);
    if (m == null) throw DemoError(404, 'MEETING_NOT_FOUND', 'meeting.not_found');
    final gs = db.byId('gram_sabha', m['gram_sabha_id'] as String?);
    final village = gs == null ? null : db.byId('village', gs['village_id'] as String?);
    if (village == null || !p.has(village)) {
      throw DemoError(404, 'MEETING_NOT_FOUND', 'meeting.not_found');
    }
    if (write && !p.has(village, const [Roles.gramSabha])) {
      throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village');
    }
    return m;
  }

  // ── outputs ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _meetingOut(DemoDb db, Map<String, dynamic> m) {
    final (present, women) = meetingCounts(db, m);
    return {
      'id': m['id'],
      'held_on': m['held_on'],
      'place': m['place'],
      'notice_on': m['notice_on'],
      'agenda': m['agenda'],
      'registered_count': m['registered_count'],
      'present_count': present,
      'women_present': women,
      'attendance_recorded': _attendance(m).isNotEmpty,
      'resolutions': db.where('resolution', (r) => r['meeting_id'] == m['id']).length,
    };
  }

  static Map<String, dynamic> _quorum(DemoDb db, Map<String, dynamic> meeting, String? caseId) {
    final (present, women) = meetingCounts(db, meeting);
    final (total, there) = caseId == null ? (0, 0) : claimantCounts(db, meeting, caseId);
    return quorum(
      registered: meeting['registered_count'] as int,
      present: present,
      womenPresent: women,
      claimantsTotal: total,
      claimantsPresent: there,
    ).proof();
  }

  static Map<String, dynamic> _resolutionOut(Map<String, dynamic> r) => {
        'id': r['id'],
        'meeting_id': r['meeting_id'],
        'case_id': r['case_id'],
        'number': r['number'],
        'decision_text': r['decision_text'],
        'votes_for': r['votes_for'],
        'votes_against': r['votes_against'],
        'boundary_id': r['boundary_id'],
        'quorum_proof': r['quorum_proof'],
        'signed_scan_media_id': r['signed_scan_media_id'],
        'created_at': r['created_at'],
      };

  static Map<String, dynamic> _verificationOut(Map<String, dynamic> v) => {
        'id': v['id'],
        'attempt_no': v['attempt_no'],
        'visit_on': v['visit_on'],
        'intimation_id': v['intimation_id'],
        'observations': v['observations'],
        'presence': [
          for (final p in ((v['presence'] as List?) ?? const []).cast<Map>())
            {
              'name': p['name'],
              'designation': p['designation'],
              'department': p['department'],
            },
        ],
        'forest_signed': v['forest_signed'],
        'forest_absence_recorded': v['forest_absence_recorded'],
        'revenue_signed': v['revenue_signed'],
        'revenue_absence_recorded': v['revenue_absence_recorded'],
        'signed_scan_media_id': v['signed_scan_media_id'],
        'complete': verificationComplete(v),
        'finality_note': finalityNote(v),
        'created_at': v['created_at'],
      };

  static Map<String, dynamic> _memberOut(Map<String, dynamic> m) => {
        'id': m['id'],
        'name': m['name'],
        'gender': m['gender'],
        'category': m['category'],
        'active': m['active'],
      };

  static int _nextNumber(DemoDb db, String key) {
    final counters = db.section('counters');
    final next = ((counters[key] as int?) ?? 0) + 1;
    counters[key] = next;
    return next;
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    DemoHooks.approvalMissing = (db, theCase) => [
          for (final i in approvalItems(db, theCase))
            if (i['ok'] != true) i,
        ];
    DemoHooks.ledgerAppend = (db, gramSabhaId, event) =>
        DemoLedger.append(db, gramSabhaId, DemoLedger.entityOf(event), event);

    _registerVerification(r);
    _registerMeetings(r);
    _registerResolutions(r);
    _registerMembers(r);

    r.get('/cases/{case_id}/approval-check', (req) {
      final p = req.who;
      final caseId = requireUuid('path', 'case_id', req.params['case_id']!);
      final ctx = DemoCases.load(req.db, p, caseId);
      return approvalCheck(req.db, ctx.theCase);
    });

    r.get('/villages/{village_id}/ledger/verify', (req) {
      final (_, village) = _scope(req);
      final gs = _gs(req.db, village['id'] as String);
      return DemoLedger.verify(req.db, gs['id'] as String).toJson();
    });
  }

  // ── field verification [Rule 12(1), 12A(1)(2)] ─────────────────────────────

  static void _registerVerification(DemoRouter r) {
    r.post('/cases/{case_id}/verification', (req) {
      final db = req.db;
      final p = req.who;
      final caseId = requireUuid('path', 'case_id', req.params['case_id']!);
      final f = Fields.body(req.body);
      final visitOn = f.date('visit_on');
      final observations = f.text('observations');
      final presence = f.objects<Map<String, dynamic>>('presence', (i) {
        return {
          'name': i.line('name'),
          'designation': i.line('designation', required: false),
          'department':
              i.choice('department', ['forest', 'revenue', 'frc', 'other'], literal: true),
        };
      });
      final intimationId = f.uuid('intimation_id', required: false);
      final forestSigned = f.boolean('forest_signed');
      final forestAbsent = f.boolean('forest_absence_recorded');
      final revenueSigned = f.boolean('revenue_signed');
      final revenueAbsent = f.boolean('revenue_absence_recorded');
      final scanId = f.uuid('signed_scan_media_id', required: false);
      f.check();

      final ctx = _gsCase(db, p, caseId);
      final c = ctx.theCase;
      if (ctx.state != CaseStates.gsReview) {
        throw DemoError(409, 'NOT_UNDER_GS_REVIEW', 'evidence.not_under_gs_review');
      }
      _recuseIfClaimant(db, p, caseId);
      _ownMedia(db, p, scanId);
      for (final (dept, signed, absent) in [
        ('forest', forestSigned, forestAbsent),
        ('revenue', revenueSigned, revenueAbsent),
      ]) {
        if (signed && absent) {
          throw DemoError(422, 'SIGNED_AND_ABSENT', 'verification.signed_and_absent',
              details: {'dept': dept});
        }
      }
      final absence = forestAbsent || revenueAbsent;
      final signedAny = forestSigned || revenueSigned;
      if (signedAny && scanId == null) {
        throw DemoError(422, 'SIGNED_SHEET_MISSING', 'verification.signed_sheet_missing');
      }
      if (intimationId != null || absence) {
        final letter = intimationId == null ? null : db.byId('correspondence', intimationId);
        final dispatched = letter?['dispatched_on'] as String?;
        if (letter == null ||
            letter['gram_sabha_id'] != c['gram_sabha_id'] ||
            letter['template'] != 'g7_site_visit' ||
            dispatched == null ||
            dispatched.compareTo(visitOn!) > 0) {
          throw DemoError(
            409,
            'INTIMATION_REQUIRED',
            'verification.intimation_required',
            rule: 'Rule 12A(1)(2)',
            details: {'needs': 'a dispatched G7 letter sent before the visit'},
          );
        }
      }
      final latest = latestVerification(db, caseId);
      final row = db.add('verification_proceeding', {
        'case_id': caseId,
        'attempt_no': ((latest?['attempt_no'] as int?) ?? 0) + 1,
        'visit_on': visitOn,
        'intimation_id': intimationId,
        'observations': observations,
        'presence': presence,
        'forest_signed': forestSigned,
        'forest_absence_recorded': forestAbsent,
        'revenue_signed': revenueSigned,
        'revenue_absence_recorded': revenueAbsent,
        'signed_scan_media_id': scanId,
        'recorded_by_user_id': p.userId,
      });
      DemoLedger.append(db, c['gram_sabha_id'] as String, 'verification_proceeding', row);
      return _verificationOut(row);
    });

    r.get('/cases/{case_id}/verification', (req) {
      final p = req.who;
      final caseId = requireUuid('path', 'case_id', req.params['case_id']!);
      DemoCases.load(req.db, p, caseId);
      final rows = req.db.where('verification_proceeding', (v) => v['case_id'] == caseId)
        ..sort((a, b) => (a['attempt_no'] as int).compareTo(b['attempt_no'] as int));
      return [for (final v in rows) _verificationOut(v)];
    });
  }

  // ── meetings and attendance ────────────────────────────────────────────────

  static void _registerMeetings(DemoRouter r) {
    r.post('/villages/{village_id}/meetings', (req) {
      final db = req.db;
      final (p, village) = _scope(req, const [Roles.gramSabha]);
      final f = Fields.body(req.body);
      final heldOn = f.date('held_on');
      final place = f.line('place');
      final noticeOn = f.date('notice_on', required: false);
      final agenda = f.text('agenda');
      f.check();

      final gs = _gs(db, village['id'] as String);
      if (noticeOn != null && noticeOn.compareTo(heldOn!) > 0) {
        throw DemoError(422, 'NOTICE_AFTER_MEETING', 'meeting.notice_after_meeting');
      }
      final registered = db
          .where('gs_member', (m) => m['gram_sabha_id'] == gs['id'] && m['active'] == true)
          .length;
      final meeting = db.add('gs_meeting', {
        'gram_sabha_id': gs['id'],
        'held_on': heldOn,
        'place': place,
        'notice_on': noticeOn,
        'agenda': agenda,
        'registered_count': registered,
        'created_by_user_id': p.userId,
        'attendance': <dynamic>[],
      });
      return _meetingOut(db, meeting);
    });

    r.get('/villages/{village_id}/meetings', (req) {
      final db = req.db;
      final (_, village) = _scope(req);
      final gs = _gs(db, village['id'] as String);
      final rows = db.where('gs_meeting', (m) => m['gram_sabha_id'] == gs['id']).reversed.toList()
        ..sort((a, b) => '${b['held_on']}'.compareTo('${a['held_on']}'));
      return [for (final m in rows) _meetingOut(db, m)];
    });

    r.get('/meetings/{meeting_id}', (req) {
      final p = req.who;
      final id = requireUuid('path', 'meeting_id', req.params['meeting_id']!);
      return _meetingOut(req.db, _meeting(req.db, p, id, write: false));
    });

    // The manual attendance register: everyone on the active roster is marked present or absent.
    // It can be corrected until a resolution has been recorded at this meeting.
    r.put('/meetings/{meeting_id}/attendance', (req) {
      final db = req.db;
      final p = req.who;
      final id = requireUuid('path', 'meeting_id', req.params['meeting_id']!);
      final f = Fields.body(req.body);
      final presentIds = f.uuidList('present_member_ids');
      f.check();

      final meeting = _meeting(db, p, id, write: true);
      if (db.findOne('resolution', (x) => x['meeting_id'] == meeting['id']) != null) {
        throw DemoError(409, 'ATTENDANCE_LOCKED', 'meeting.attendance_locked');
      }
      final roster = [
        for (final m in db.where('gs_member',
            (m) => m['gram_sabha_id'] == meeting['gram_sabha_id'] && m['active'] == true))
          m['id'] as String,
      ];
      final present = presentIds!.toSet();
      if (!roster.toSet().containsAll(present)) {
        throw DemoError(422, 'MEMBER_NOT_IN_ROSTER', 'meeting.member_not_in_roster');
      }
      meeting['attendance'] = [
        for (final mid in roster)
          {
            'id': db.newId(),
            'gs_member_id': mid,
            'present': present.contains(mid),
            'method': 'manual'
          },
      ];
      return _meetingOut(db, meeting);
    });

    // Live preview of the three quorum tests [Rule 4(2)]; give `case_id` for a claim.
    r.get('/meetings/{meeting_id}/quorum', (req) {
      final p = req.who;
      final id = requireUuid('path', 'meeting_id', req.params['meeting_id']!);
      final rawCase = req.q('case_id');
      final caseId = rawCase == null ? null : requireUuid('query', 'case_id', rawCase);
      return _quorum(req.db, _meeting(req.db, p, id, write: false), caseId);
    });
  }

  // ── resolutions ────────────────────────────────────────────────────────────

  static void _registerResolutions(DemoRouter r) {
    // Record the resolution on a claim under review. All three quorum tests must pass (BR-03)
    // and the motion must carry by a simple majority of those voting. For a CFR claim the
    // resolution approves the current boundary: every segment needs a landmark (BR-08) and no
    // overlap may be open (BR-09); the boundary is then frozen.
    r.post('/meetings/{meeting_id}/resolutions', (req) {
      final db = req.db;
      final p = req.who;
      final meetingId = requireUuid('path', 'meeting_id', req.params['meeting_id']!);
      final f = Fields.body(req.body);
      final caseId = f.uuid('case_id');
      final decision = f.text('decision_text');
      final votesFor = f.integer('votes_for');
      final votesAgainst = f.integer('votes_against');
      final scanId = f.uuid('signed_scan_media_id', required: false);
      f.check();

      final meeting = _meeting(db, p, meetingId, write: true);
      final c = db.byId('claim_case', caseId);
      if (c == null || c['gram_sabha_id'] != meeting['gram_sabha_id']) {
        throw DemoError(404, 'CASE_NOT_FOUND', 'case.not_found');
      }
      _gsCase(db, p, c['id'] as String);
      if (c['state'] != CaseStates.gsReview) {
        throw DemoError(409, 'NOT_UNDER_GS_REVIEW', 'evidence.not_under_gs_review');
      }
      _recuseIfClaimant(db, p, c['id'] as String);
      _ownMedia(db, p, scanId);

      final (present, _) = meetingCounts(db, meeting);
      if (votesFor! + votesAgainst! > present) {
        throw DemoError(422, 'MORE_VOTES_THAN_PRESENT', 'resolution.more_votes_than_present');
      }
      if (votesFor <= votesAgainst) {
        throw DemoError(409, 'MOTION_NOT_CARRIED', 'resolution.not_carried', rule: 'Rule 4(2)');
      }
      final q = _quorum(db, meeting, c['id'] as String);
      if (q['passed'] != true) {
        throw DemoError(409, 'QUORUM_FAILED', 'resolution.quorum_failed',
            rule: 'Rule 4(2)', details: {'failures': q['failures'], ...q});
      }

      String? boundaryId;
      if (c['claim_type'] == ClaimTypes.cfr) {
        final b = currentBoundary(db, c['id'] as String);
        if (b == null) throw DemoError(409, 'NO_BOUNDARY', 'boundary.none');
        if (_segmentsWithoutLandmark(b) > 0) {
          throw DemoError(409, 'LANDMARK_PER_SEGMENT', 'boundary.landmark_per_segment',
              rule: 'Rule 12(1)(g)');
        }
        if (openDisputes(db, c['id'] as String) > 0) {
          throw DemoError(409, 'OPEN_DISPUTE', 'boundary.open_dispute', rule: 'Rule 12(3)');
        }
        if (b['status'] == 'draft') seal(db, b);
        boundaryId = b['id'] as String;
      }

      final year = db.todayIst().substring(0, 4);
      final number = _nextNumber(db, 'resolution/${c['gram_sabha_id']}/$year');
      final previous = currentResolution(db, c['id'] as String);
      final row = db.add('resolution', {
        'gram_sabha_id': c['gram_sabha_id'],
        'meeting_id': meeting['id'],
        'case_id': c['id'],
        'number': '$number/$year',
        'decision_text': decision,
        'votes_for': votesFor,
        'votes_against': votesAgainst,
        'boundary_id': boundaryId,
        'quorum_proof': q,
        'signed_scan_media_id': scanId,
        'supersedes_id': previous?['id'],
        'correction_reason': null,
        'created_by_user_id': p.userId,
      });
      DemoLedger.append(db, c['gram_sabha_id'] as String, 'resolution', row);
      return _resolutionOut(row);
    });

    r.get('/cases/{case_id}/resolutions', (req) {
      final p = req.who;
      final caseId = requireUuid('path', 'case_id', req.params['case_id']!);
      DemoCases.load(req.db, p, caseId);
      return [
        for (final x in req.db.where('resolution', (x) => x['case_id'] == caseId))
          _resolutionOut(x),
      ];
    });
  }

  // ── members (api/v1/members.py) ────────────────────────────────────────────

  static void _registerMembers(DemoRouter r) {
    r.get('/villages/{village_id}/members', (req) {
      final db = req.db;
      final (_, village) = _scope(req);
      final raw = req.q('include_inactive');
      var includeInactive = false;
      if (raw != null) {
        final parsed = parseBool(raw);
        if (parsed == null) {
          throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
            'errors': [
              {
                'type': 'bool_parsing',
                'loc': ['query', 'include_inactive'],
                'msg': 'Input should be a valid boolean, unable to interpret input',
                'input': raw,
              },
            ],
          });
        }
        includeInactive = parsed;
      }
      final gs = _gs(db, village['id'] as String);
      final rows = db
          .where('gs_member',
              (m) => m['gram_sabha_id'] == gs['id'] && (includeInactive || m['active'] == true))
          .toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      return [for (final m in rows) _memberOut(m)];
    });

    r.post('/villages/{village_id}/members', (req) {
      final db = req.db;
      final (_, village) = _scope(req, const [Roles.gramSabha]);
      final f = Fields.body(req.body);
      final name = f.text('name', max: 200);
      final gender = f.choice('gender', _genders);
      final category = f.choice('category', _categories);
      f.check();
      final gs = _gs(db, village['id'] as String);
      final member = db.add('gs_member', {
        'gram_sabha_id': gs['id'],
        'name': name,
        'gender': gender,
        'category': category,
        'active': true,
      });
      return _memberOut(member);
    });

    r.patch('/members/{member_id}', (req) {
      final db = req.db;
      final p = req.who;
      final id = requireUuid('path', 'member_id', req.params['member_id']!);
      final f = Fields.body(req.body);
      final name = f.has('name') ? f.text('name', max: 200, required: false) : null;
      final gender = f.has('gender') ? f.choice('gender', _genders, required: false) : null;
      final category =
          f.has('category') ? f.choice('category', _categories, required: false) : null;
      final active = f.optionalBoolean('active');
      f.check();

      final member = db.byId('gs_member', id);
      if (member == null) throw DemoError(404, 'MEMBER_NOT_FOUND', 'member.not_found');
      final gs = db.byId('gram_sabha', member['gram_sabha_id'] as String?);
      final village = gs == null ? null : db.byId('village', gs['village_id'] as String?);
      if (village == null || !p.has(village)) {
        throw DemoError(404, 'MEMBER_NOT_FOUND', 'member.not_found');
      }
      if (!p.has(village, const [Roles.gramSabha])) {
        throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village',
            details: {'village_id': village['id']});
      }
      if (name != null) member['name'] = name;
      if (gender != null) member['gender'] = gender;
      if (category != null) member['category'] = category;
      if (active != null) member['active'] = active;
      db.touch(member);
      return _memberOut(member);
    });
  }
}
