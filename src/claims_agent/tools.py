from langchain_core.tools import tool

from claims_agent.data_access import get_benefit_by_plan_code, get_claim_by_id, get_member_by_id


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


CLAIMS_TOOLS = [lookup_claim_status, check_member_eligibility, get_benefit_summary]
