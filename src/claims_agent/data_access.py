from claims_agent.models import BenefitSummary, ClaimRecord, MemberRecord
from claims_agent.sample_data import BENEFITS, CLAIMS, MEMBERS

_CLAIMS_BY_ID = {claim.claim_id.upper(): claim for claim in CLAIMS}
_MEMBERS_BY_ID = {member.member_id.upper(): member for member in MEMBERS}
_BENEFITS_BY_CODE = {benefit.plan_code.upper(): benefit for benefit in BENEFITS}


def get_claim_by_id(claim_id: str) -> ClaimRecord | None:
    return _CLAIMS_BY_ID.get(claim_id.strip().upper())


def get_member_by_id(member_id: str) -> MemberRecord | None:
    return _MEMBERS_BY_ID.get(member_id.strip().upper())


def get_benefit_by_plan_code(plan_code: str) -> BenefitSummary | None:
    return _BENEFITS_BY_CODE.get(plan_code.strip().upper())
