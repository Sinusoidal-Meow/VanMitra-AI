import '../core/demo_core.dart';
import 'procedure_domain.dart';
import 'procedure_support.dart';

/// The call for claims [Rule 11(1)] and tracked letters (G2, G5, G6, G7, G18), ported from the
/// backend's api/v1/claim_calls.py.
///
/// The Gram Sabha calls for claims with a three-month window, extendable only with written
/// reasons and a resolution reference, and fixes the date for initiating the CFR determination.
/// Letters are tracked from drafting to dispatch, reminder and reply.
///
/// Tables: `claim_call`, `correspondence` (the Python models' collection names and fields).
class DemoClaimCalls {
  DemoClaimCalls._();

  static const Set<String> letterTemplates = {
    'g2_intimation_adjoining',
    'g2_intimation_sdlc',
    'g5_maps_request',
    'g6_records_request',
    'g7_site_visit',
    'g18_survey_request',
    'other',
  };

  // ── the call ────────────────────────────────────────────────────────────────

  /// The Gram Sabha's current call (the backend's `current_claim_call`), or null.
  static Map<String, dynamic>? currentFor(DemoDb db, String gramSabhaId) => db.findOne(
        'claim_call',
        (c) => c['gram_sabha_id'] == gramSabhaId && c['is_current'] == true,
      );

  /// The last day for filing: the extension if there is one, else the end of the window.
  static String closesOn(Map<String, dynamic> c) =>
      (c['extended_to'] ?? c['window_ends_on']) as String;

  /// The backend's `ClaimCallOut`.
  static Map<String, dynamic> callOut(Map<String, dynamic> c, String today) {
    final closes = closesOn(c);
    final left = parseDate(closes).difference(parseDate(today)).inDays;
    final calledOn = c['called_on'] as String;
    return {
      'id': c['id'],
      'called_on': calledOn,
      'window_ends_on': c['window_ends_on'],
      'closes_on': closes,
      'days_remaining': left < 0 ? 0 : left,
      'is_open': calledOn.compareTo(today) <= 0 && today.compareTo(closes) <= 0,
      'place_of_filing': c['place_of_filing'],
      'notice_displayed_on': c['notice_displayed_on'],
      'cfr_determination_on': c['cfr_determination_on'],
      'extended_to': c['extended_to'],
      'extension_reason': c['extension_reason'],
      'extension_resolution_ref': c['extension_resolution_ref'],
      'is_current': c['is_current'],
    };
  }

  static Map<String, dynamic> _currentOr404(DemoDb db, String villageId) {
    final call = currentFor(db, ProcedureGuards.gramSabha(db, villageId)['id'] as String);
    if (call == null) throw DemoError(404, 'NO_CLAIM_CALL', 'claim_call.none');
    return call;
  }

  // ── letters ─────────────────────────────────────────────────────────────────

  /// The backend's `LetterOut`.
  static Map<String, dynamic> letterOut(Map<String, dynamic> c, String today) {
    final reminderOn = c['reminder_on'] as String?;
    return {
      'id': c['id'],
      'template': c['template'],
      'addressee': c['addressee'],
      'subject': c['subject'],
      'body': c['body'],
      'case_id': c['case_id'],
      'neighbour_village': c['neighbour_village'],
      'records_requested': List<dynamic>.from((c['records_requested'] as List?) ?? const []),
      'dispatched_on': c['dispatched_on'],
      'reminder_on': reminderOn,
      'reminder_due': reminderOn != null &&
          c['response_received_on'] == null &&
          today.compareTo(reminderOn) >= 0,
      'response_received_on': c['response_received_on'],
      'outcome': c['outcome'],
      'created_at': c['created_at'],
    };
  }

  static Map<String, dynamic> _letterForGramSabha(DemoRequest req, Principal p) {
    final db = req.db;
    final letter = db.byId('correspondence', req.params['letter_id']);
    if (letter == null) throw DemoError(404, 'LETTER_NOT_FOUND', 'letter.not_found');
    final gs = db.byId('gram_sabha', letter['gram_sabha_id'] as String?);
    final village = gs == null ? null : db.byId('village', gs['village_id'] as String?);
    if (village == null || !p.has(village)) {
      throw DemoError(404, 'LETTER_NOT_FOUND', 'letter.not_found');
    }
    if (!p.has(village, [Roles.gramSabha])) {
      throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village');
    }
    return letter;
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    // open a call for claims: the window is three months from the day of calling
    r.post('/villages/{village_id}/claim-calls', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final calledOn = input.date('called_on');
      final place = input.text('place_of_filing', max: 300);
      final displayed = input.date('notice_displayed_on', required: false, nullable: true);
      final cfrOn = input.date('cfr_determination_on', required: false, nullable: true);
      input.done();

      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      if (displayed != null && displayed.compareTo(calledOn!) < 0) {
        throw DemoError(422, 'NOTICE_BEFORE_CALL', 'claim_call.notice_before_call');
      }
      for (final old in db.where(
        'claim_call',
        (c) => c['gram_sabha_id'] == gs['id'] && c['is_current'] == true,
      )) {
        old['is_current'] = false;
        db.touch(old);
      }
      final call = db.add('claim_call', {
        'gram_sabha_id': gs['id'],
        'called_on': calledOn,
        'window_ends_on': dateOnly(ProcedureClocks.claimWindowDue(parseDate(calledOn!))),
        'place_of_filing': place,
        'notice_displayed_on': displayed,
        'cfr_determination_on': cfrOn,
        'extended_to': null,
        'extension_reason': null,
        'extension_resolution_ref': null,
        'is_current': true,
        'created_by_user_id': req.who.userId,
      });
      return callOut(call, db.todayIst());
    });

    r.get('/villages/{village_id}/claim-calls/current', (req) {
      final village = ProcedureGuards.village(req);
      return callOut(_currentOr404(req.db, village['id'] as String), req.db.todayIst());
    });

    // every call the Gram Sabha has made, newest first
    r.get('/villages/{village_id}/claim-calls', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req);
      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      final rows = ProcedureGuards.stableSorted(
        db.where('claim_call', (c) => c['gram_sabha_id'] == gs['id']).reversed,
        (a, b) => (b['called_on'] as String).compareTo(a['called_on'] as String),
      );
      final today = db.todayIst();
      return [for (final c in rows) callOut(c, today)];
    });

    // extend the window: written reasons and the resolution are mandatory [Rule 11(1)(a)]
    r.post('/villages/{village_id}/claim-calls/current/extend', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final extendedTo = input.date('extended_to');
      final reason = input.text('reason', min: 5);
      final resolutionRef = input.text('resolution_ref', max: 200);
      input.done();

      final call = _currentOr404(db, village['id'] as String);
      if (extendedTo!.compareTo(closesOn(call)) <= 0) {
        throw DemoError(
          409,
          'EXTENSION_NOT_LATER',
          'claim_call.extension_not_later',
          rule: 'Rule 11(1)(a)',
          details: {'closes_on': closesOn(call)},
        );
      }
      call['extended_to'] = extendedTo;
      call['extension_reason'] = reason;
      call['extension_resolution_ref'] = resolutionRef;
      db.touch(call);
      return callOut(call, db.todayIst());
    });

    // the date the notice was displayed at the customary public place
    r.post('/villages/{village_id}/claim-calls/current/displayed', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final displayed = input.date('notice_displayed_on');
      input.done();

      final call = _currentOr404(db, village['id'] as String);
      if (displayed!.compareTo(call['called_on'] as String) < 0) {
        throw DemoError(422, 'NOTICE_BEFORE_CALL', 'claim_call.notice_before_call');
      }
      call['notice_displayed_on'] = displayed;
      db.touch(call);
      return callOut(call, db.todayIst());
    });

    // ── letters ──

    r.post('/villages/{village_id}/letters', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req, [Roles.gramSabha]);
      final input = Input(req.body);
      final template = input.choice('template', letterTemplates, required: true);
      final addressee = input.text('addressee', max: 300);
      final subject = input.text('subject', max: 300);
      final body = input.text('body', required: false, nullable: true);
      final caseId = input.uuid('case_id', required: false, nullable: true);
      final neighbour = input.text('neighbour_village', required: false, nullable: true, max: 200);
      final records = input.textList('records_requested', max: 50);
      input.done();

      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      if (template == 'g2_intimation_adjoining' && (neighbour == null || neighbour.isEmpty)) {
        throw DemoError(422, 'NEIGHBOUR_VILLAGE_REQUIRED', 'letter.neighbour_village_required');
      }
      if (caseId != null) {
        final theCase = db.byId('claim_case', caseId);
        if (theCase == null || theCase['gram_sabha_id'] != gs['id']) {
          throw DemoError(422, 'CASE_NOT_IN_VILLAGE', 'letter.case_not_in_village');
        }
      }
      final letter = db.add('correspondence', {
        'gram_sabha_id': gs['id'],
        'case_id': caseId,
        'template': template,
        'addressee': addressee,
        'subject': subject,
        'body': body,
        'neighbour_village': neighbour,
        'records_requested': records,
        'dispatched_on': null,
        'reminder_on': null,
        'response_received_on': null,
        'outcome': null,
        'created_by_user_id': req.who.userId,
      });
      return letterOut(letter, db.todayIst());
    });

    r.get('/villages/{village_id}/letters', (req) {
      final db = req.db;
      final village = ProcedureGuards.village(req);
      final caseId = queryUuid(req, 'case_id');
      final template = req.q('template');
      if (template != null && !letterTemplates.contains(template)) {
        throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
          'errors': [
            {
              'type': 'enum',
              'loc': ['query', 'template'],
              'msg': 'Input should be ${letterTemplates.map((e) => "'$e'").join(', ')}',
              'input': template,
            },
          ],
        });
      }
      final gs = ProcedureGuards.gramSabha(db, village['id'] as String);
      final rows = ProcedureGuards.stableSorted(
        db.where(
          'correspondence',
          (c) =>
              c['gram_sabha_id'] == gs['id'] &&
              (caseId == null || c['case_id'] == caseId) &&
              (template == null || c['template'] == template),
        ),
        (a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'),
      );
      final today = db.todayIst();
      return [for (final c in rows) letterOut(c, today)];
    });

    // sent on a date; the reminder falls due after the given number of days
    r.post('/letters/{letter_id}/dispatch', (req) {
      final db = req.db;
      final p = req.who;
      final input = Input(req.body);
      final dispatchedOn = input.date('dispatched_on');
      final days = input.integer('reminder_after_days', min: 1, max: 365, defaultValue: 30);
      input.done();

      final letter = _letterForGramSabha(req, p);
      letter['dispatched_on'] = dispatchedOn;
      letter['reminder_on'] =
          dateOnly(parseDate(dispatchedOn!).add(Duration(days: days!)));
      db.touch(letter);
      return letterOut(letter, db.todayIst());
    });

    // the reply that came back
    r.post('/letters/{letter_id}/response', (req) {
      final db = req.db;
      final p = req.who;
      final input = Input(req.body);
      final receivedOn = input.date('received_on');
      final outcome = input.text('outcome');
      input.done();

      final letter = _letterForGramSabha(req, p);
      final sent = letter['dispatched_on'] as String?;
      if (sent == null || receivedOn!.compareTo(sent) < 0) {
        throw DemoError(422, 'RESPONSE_BEFORE_DISPATCH', 'letter.response_before_dispatch');
      }
      letter['response_received_on'] = receivedOn;
      letter['outcome'] = outcome;
      db.touch(letter);
      return letterOut(letter, db.todayIst());
    });
  }
}
