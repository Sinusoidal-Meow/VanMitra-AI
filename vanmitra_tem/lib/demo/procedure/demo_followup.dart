import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'procedure_domain.dart';
import 'procedure_support.dart';

/// Legal clocks for a case, and the record after the title is issued (Stage 5): the certified
/// copy, the survey request and the entry in the record of rights. A case cannot be closed
/// without the certified copy and the record entry (BR-13) [Rule 8(i), 12A(9)]. Ported from the
/// backend's api/v1/followup.py.
///
/// Table: `title_followup` (one row per case). Reads `workflow_event`, `claim_call`,
/// `resolution`, `dispute`, `media`, `correspondence`.
class DemoFollowup {
  DemoFollowup._();

  static const Set<String> _officials = {Roles.gramSabha, Roles.sdo};

  static String _utcDateOf(String moment) => dateOnly(DateTime.parse(moment).toUtc());

  /// The day the title was issued (the day of the last event that moved the case there).
  static String? titleIssuedOn(DemoDb db, String caseId) {
    for (final ev in DemoCases.events(db, caseId).reversed) {
      if (ev['to_state'] == CaseStates.titleIssued) return _utcDateOf(ev['created_at'] as String);
    }
    return null;
  }

  static Map<String, dynamic>? followup(DemoDb db, String caseId) =>
      db.findOne('title_followup', (f) => f['case_id'] == caseId);

  /// The backend's `FollowupOut`.
  static Map<String, dynamic> followupOut(DemoDb db, CaseCtx ctx, Map<String, dynamic>? f) {
    final issued = titleIssuedOn(db, ctx.theCase['id'] as String);
    final missing = <String>[
      if (f == null || f['certified_copy_media_id'] == null) 'certified_copy',
      if (f == null || f['record_entry_on'] == null) 'record_entry',
    ];
    final issuedNow = ctx.state == CaseStates.titleIssued;
    return {
      'certified_copy_media_id': f?['certified_copy_media_id'],
      'certified_copy_on': f?['certified_copy_on'],
      'survey_letter_id': f?['survey_letter_id'],
      'survey_done_on': f?['survey_done_on'],
      'record_entry_on': f?['record_entry_on'],
      'record_entry_ref': f?['record_entry_ref'],
      'record_entry_media_id': f?['record_entry_media_id'],
      'case_id': ctx.theCase['id'],
      'title_issued_on': issued,
      'record_update_due_on': issued == null
          ? null
          : dateOnly(ProcedureClocks.recordUpdateDue(parseDate(issued))),
      'survey_pending': issuedNow && !(f != null && f['survey_done_on'] != null),
      'can_close': issuedNow && missing.isEmpty,
      'missing': missing,
      'closed_on': f?['closed_on'],
    };
  }

  static void _ensureOfficial(CaseCtx ctx) {
    if (ctx.roles.intersection(_officials).isEmpty) {
      throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');
    }
    if (ctx.state != CaseStates.titleIssued) {
      throw DemoError(409, 'TITLE_NOT_ISSUED', 'followup.title_not_issued');
    }
  }

  // ── the clocks of a case ────────────────────────────────────────────────────

  static num _hectares(Object? v) => v is num ? v : (num.tryParse('$v') ?? 0);

  /// The running statutory periods of a case (the backend's `case_clocks`).
  static List<StatutoryClock> caseClocks(DemoDb db, CaseCtx ctx, String today) {
    final c = ctx.theCase;
    final caseId = c['id'] as String;
    final now = parseDate(today);
    final out = <StatutoryClock>[];

    final call = db.byId('claim_call', c['claim_call_id'] as String?);
    if (call != null) {
      final closes = (call['extended_to'] ?? call['window_ends_on']) as String;
      final acknowledged = c['acknowledged_on'] as String?;
      out.add(ProcedureClocks.clock(
        'claim_window',
        'Rule 11(1)(a)',
        parseDate(call['called_on'] as String),
        parseDate(closes),
        now,
        metOn: c['filed_within_window'] == true && acknowledged != null
            ? parseDate(acknowledged)
            : null,
      ));
    }

    final resolution = _currentResolution(db, caseId);
    if (resolution != null) {
      final start = parseDate(_utcDateOf(resolution['created_at'] as String));
      out.add(ProcedureClocks.clock(
        'petition_against_resolution',
        'Sec 6(2), Rule 14(1)',
        start,
        ProcedureClocks.petitionDue(start),
        now,
        alerts: ProcedureClocks.alertDays,
      ));
    }

    final disputes = db.where(
      'dispute',
      (d) => d['case_id'] == caseId || d['neighbour_case_id'] == caseId,
    );
    for (final d in disputes) {
      if (_hectares(d['overlap_ha']) <= 0) continue;
      final detected = parseDate(d['detected_on'] as String);
      final met = (d['joint_meeting_on'] ?? d['sdlc_referral_on']) as String?;
      out.add(ProcedureClocks.clock(
        'mutual_solution',
        'Rule 14(7)',
        detected,
        ProcedureClocks.mutualSolutionDue(detected),
        now,
        metOn: met == null ? null : parseDate(met),
      ));
    }

    final issued = titleIssuedOn(db, caseId);
    if (issued != null) {
      final f = followup(db, caseId);
      final entry = f?['record_entry_on'] as String?;
      final start = parseDate(issued);
      out.add(ProcedureClocks.clock(
        'record_update',
        'Rule 12A(9)',
        start,
        ProcedureClocks.recordUpdateDue(start),
        now,
        metOn: entry == null ? null : parseDate(entry),
      ));
    }
    return out;
  }

  /// The resolution in force for a case (the newest one that nothing replaced).
  static Map<String, dynamic>? _currentResolution(DemoDb db, String caseId) {
    final rows = ProcedureGuards.stableSorted(
      db.where('resolution', (r) => r['case_id'] == caseId),
      (a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'),
    );
    final replaced = {
      for (final r in rows)
        if (r['supersedes_id'] != null) r['supersedes_id'],
    };
    final live = rows.where((r) => !replaced.contains(r['id'])).toList();
    return live.isEmpty ? null : live.last;
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    r.get('/cases/{case_id}/post-title', (req) {
      final ctx = DemoCases.load(req.db, req.who, req.params['case_id']!);
      return followupOut(req.db, ctx, followup(req.db, req.params['case_id']!));
    });

    // certified title copy, survey request and record-of-rights entry [Rule 8(i), 12A(9)]
    r.put('/cases/{case_id}/post-title', (req) {
      final db = req.db;
      final p = req.who;
      final input = Input(req.body);
      final fields = <String, Object?>{};
      void read(String field, Object? Function() parse) {
        if (!input.has(field)) return;
        fields[field] = parse();
      }

      read('certified_copy_media_id',
          () => input.uuid('certified_copy_media_id', required: false, nullable: true));
      read('certified_copy_on',
          () => input.date('certified_copy_on', required: false, nullable: true));
      read('survey_letter_id',
          () => input.uuid('survey_letter_id', required: false, nullable: true));
      read('survey_done_on', () => input.date('survey_done_on', required: false, nullable: true));
      read('record_entry_on',
          () => input.date('record_entry_on', required: false, nullable: true));
      read('record_entry_ref',
          () => input.text('record_entry_ref', required: false, nullable: true, max: 200));
      read('record_entry_media_id',
          () => input.uuid('record_entry_media_id', required: false, nullable: true));
      input.done();

      final caseId = req.params['case_id']!;
      final ctx = DemoCases.load(db, p, caseId);
      _ensureOfficial(ctx);
      var f = followup(db, caseId);
      if (f != null && f['closed_on'] != null) {
        throw DemoError(409, 'CASE_CLOSED', 'followup.closed');
      }
      for (final field in const ['certified_copy_media_id', 'record_entry_media_id']) {
        final id = fields[field] as String?;
        if (id == null) continue;
        final media = db.byId('media', id);
        if (media == null || media['uploaded_by_user_id'] != p.userId) {
          throw DemoError(422, 'MEDIA_NOT_YOURS', 'evidence.media_not_yours');
        }
      }
      final letterId = fields['survey_letter_id'] as String?;
      if (letterId != null) {
        final letter = db.byId('correspondence', letterId);
        if (letter == null || letter['gram_sabha_id'] != ctx.theCase['gram_sabha_id']) {
          throw DemoError(422, 'LETTER_NOT_IN_VILLAGE', 'letter.not_found');
        }
      }
      f ??= db.add('title_followup', {
        'case_id': caseId,
        'certified_copy_media_id': null,
        'certified_copy_on': null,
        'survey_letter_id': null,
        'survey_done_on': null,
        'record_entry_on': null,
        'record_entry_ref': null,
        'record_entry_media_id': null,
        'closed_on': null,
        'updated_by_user_id': p.userId,
      });
      f.addAll(fields);
      f['updated_by_user_id'] = p.userId;
      db.touch(f);
      return followupOut(db, ctx, f);
    });

    // close the file: needs the certified title copy and the record entry (BR-13)
    r.post('/cases/{case_id}/close', (req) {
      final db = req.db;
      final p = req.who;
      final caseId = req.params['case_id']!;
      final ctx = DemoCases.load(db, p, caseId);
      _ensureOfficial(ctx);
      final f = followup(db, caseId);
      final out = followupOut(db, ctx, f);
      final missing = out['missing'] as List;
      if (missing.isNotEmpty) {
        throw DemoError(
          409,
          'CANNOT_CLOSE',
          'followup.cannot_close',
          rule: 'Rule 8(i), 12A(9)',
          details: {'missing': missing},
        );
      }
      if (f!['closed_on'] == null) {
        f['closed_on'] = db.todayIst();
        f['updated_by_user_id'] = p.userId;
        db.touch(f);
      }
      return followupOut(db, ctx, f);
    });

    // running statutory periods of this case, with days left and the next reminder date
    r.get('/cases/{case_id}/timeline', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      return [for (final c in caseClocks(db, ctx, db.todayIst())) c.toJson()];
    });
  }
}
