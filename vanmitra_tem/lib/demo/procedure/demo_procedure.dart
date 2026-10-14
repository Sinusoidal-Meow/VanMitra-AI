import '../core/demo_core.dart';
import 'demo_claim_calls.dart';
import 'demo_followup.dart';
import 'demo_villages.dart';

/// Claim calls, the village registry and Forest Rights Committee, claimants, letters, post-title
/// follow-up and the clocks timeline (backend api/v1/claim_calls.py, villages.py, followup.py).
///
/// Rules: lib/demo/procedure/procedure_domain.dart. Tables (named as the backend's collections):
/// `claim_call`, `correspondence`, `village`, `gram_sabha`, `frc`, `case_claimant`,
/// `title_followup`.
class DemoProcedure {
  DemoProcedure._();

  static void register(DemoRouter r) {
    DemoClaimCalls.register(r);
    DemoVillages.register(r);
    DemoFollowup.register(r);
  }
}
