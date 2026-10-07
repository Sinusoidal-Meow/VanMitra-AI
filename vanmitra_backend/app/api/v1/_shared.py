"""Response builders shared by the case, form and workflow routers."""

from ...domain.dates import today_ist
from ...domain.form_b import Completeness
from ...domain.workflow import allowed_actions
from ...models import ClaimCase, ClaimType, Village
from ...schemas.cases import CaseOut, ReturnedOut
from ...schemas.form_b import CompletenessItemOut, CompletenessOut, VillageHeader
from ...services.cases import CaseContext, returned_info

FORM_LETTER = {ClaimType.IFR: "A", ClaimType.CR: "B", ClaimType.CFR: "C"}


def village_header(village: Village) -> VillageHeader:
    return VillageHeader(
        village_id=village.id,
        village_name_mr=village.name_mr,
        village_name_en=village.name_en,
        gram_panchayat=village.gram_panchayat,
        taluka=village.taluka,
        district=village.district,
    )


def completeness_out(c: Completeness) -> CompletenessOut:
    return CompletenessOut(
        done=c.done,
        total=c.total,
        items=[
            CompletenessItemOut(
                id=i.id, ok=i.ok, form_item=i.form_item, rule=i.rule, message_key=i.message_key
            )
            for i in c.items
        ],
    )


def claimant_label(case: ClaimCase, village: Village) -> str:
    if case.claim_type is ClaimType.IFR and case.form_a and case.form_a.claimant_names:
        return ", ".join(case.form_a.claimant_names)
    if case.claim_type is ClaimType.CR and case.form_b and case.form_b.claimant_names:
        return ", ".join(case.form_b.claimant_names)
    return f"Gram Sabha, {village.name_en}"


def case_out(ctx: CaseContext) -> CaseOut:
    case, village = ctx.case, ctx.village
    back = returned_info(case)
    returned = (
        ReturnedOut(
            by_role=back.by_role,
            by_name=back.by_name,
            remarks=back.remarks,
            returned_on=back.returned_on,
            resubmit_by=back.resubmit_by,
            days_left=max((back.resubmit_by - today_ist()).days, 0),
        )
        if back
        else None
    )
    return CaseOut(
        id=case.id,
        claim_type=case.claim_type,
        form=FORM_LETTER[case.claim_type],
        state=case.state,
        village_id=village.id,
        village_name_en=village.name_en,
        village_name_mr=village.name_mr,
        taluka=village.taluka,
        district=village.district,
        claimant_label=claimant_label(case, village),
        created_by_user_id=case.created_by_user_id,
        is_mine=ctx.is_creator,
        allowed_actions=allowed_actions(
            state=case.state,
            actor_roles=ctx.roles,
            is_creator=ctx.is_creator,
            resubmit_by=back.resubmit_by if back else None,
        ),
        returned=returned,
        created_at=case.created_at,
        updated_at=case.updated_at,
    )
