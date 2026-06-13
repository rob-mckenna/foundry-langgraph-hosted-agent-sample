from langchain_core.tools import tool

from claims_agent.data_access import (
    get_benefit_by_plan_code,
    get_claim_by_id,
    get_claims_by_member_id,
    get_member_by_id,
    get_prior_authorization_by_id,
)


@tool
def lookup_claim_status(claim_id: str) -> dict:
    """Look up a claim by claim ID and return its current processing status details."""
    claim = get_claim_by_id(claim_id)
    if claim is None:
        return {
            "claim_id": claim_id,
            "found": False,
            "message": "No claim was found for that claim ID.",
        }
    return {"found": True, **claim.model_dump(mode="json")}


@tool
def search_claims_by_member(member_id: str) -> dict:
    """Return all claims associated with a member ID."""
    claims = get_claims_by_member_id(member_id)
    if not claims:
        return {
            "member_id": member_id,
            "found": False,
            "message": "No claims were found for that member ID.",
        }
    return {
        "member_id": member_id,
        "found": True,
        "claim_count": len(claims),
        "claims": [claim.model_dump(mode="json") for claim in claims],
    }


@tool
def check_member_eligibility(member_id: str) -> dict:
    """Check member eligibility status using a member ID."""
    member = get_member_by_id(member_id)
    if member is None:
        return {
            "member_id": member_id,
            "found": False,
            "message": "No member was found for that member ID.",
        }
    return {"found": True, **member.model_dump(mode="json")}


@tool
def get_benefit_summary(plan_code: str) -> dict:
    """Retrieve a benefit summary for a plan code."""
    benefit = get_benefit_by_plan_code(plan_code)
    if benefit is None:
        return {
            "plan_code": plan_code,
            "found": False,
            "message": "No benefit summary was found for that plan code.",
        }
    return {"found": True, **benefit.model_dump(mode="json")}


@tool
def get_prior_authorization_status(auth_id: str) -> dict:
    """Look up a prior authorization by authorization ID and return its status details."""
    prior_authorization = get_prior_authorization_by_id(auth_id)
    if prior_authorization is None:
        return {
            "auth_id": auth_id,
            "found": False,
            "message": "No prior authorization was found for that authorization ID.",
        }
    return {"found": True, **prior_authorization.model_dump(mode="json")}


CLAIMS_TOOLS = [
    lookup_claim_status,
    search_claims_by_member,
    check_member_eligibility,
    get_benefit_summary,
    get_prior_authorization_status,
]
