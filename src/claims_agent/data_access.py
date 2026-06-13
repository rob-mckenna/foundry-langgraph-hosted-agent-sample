from claims_agent.models import BenefitSummary, ClaimRecord, MemberRecord, PriorAuthorizationRecord
from claims_agent.sample_data import BENEFITS, CLAIMS, MEMBERS, PRIOR_AUTHORIZATIONS

_CLAIMS_BY_ID = {claim.claim_id.upper(): claim for claim in CLAIMS}
_CLAIMS_BY_MEMBER_ID: dict[str, list[ClaimRecord]] = {}
for claim in CLAIMS:
    _CLAIMS_BY_MEMBER_ID.setdefault(claim.member_id.upper(), []).append(claim)

_MEMBERS_BY_ID = {member.member_id.upper(): member for member in MEMBERS}
_BENEFITS_BY_CODE = {benefit.plan_code.upper(): benefit for benefit in BENEFITS}
_PRIOR_AUTHS_BY_ID = {prior_auth.auth_id.upper(): prior_auth for prior_auth in PRIOR_AUTHORIZATIONS}


def get_claim_by_id(claim_id: str) -> ClaimRecord | None:
    return _CLAIMS_BY_ID.get(claim_id.strip().upper())


def get_claims_by_member_id(member_id: str) -> list[ClaimRecord]:
    return list(_CLAIMS_BY_MEMBER_ID.get(member_id.strip().upper(), []))


def get_member_by_id(member_id: str) -> MemberRecord | None:
    return _MEMBERS_BY_ID.get(member_id.strip().upper())


def get_benefit_by_plan_code(plan_code: str) -> BenefitSummary | None:
    return _BENEFITS_BY_CODE.get(plan_code.strip().upper())


def get_prior_authorization_by_id(auth_id: str) -> PriorAuthorizationRecord | None:
    return _PRIOR_AUTHS_BY_ID.get(auth_id.strip().upper())
