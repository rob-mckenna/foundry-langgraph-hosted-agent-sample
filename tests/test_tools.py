from claims_agent.tools import (
    check_member_eligibility,
    get_benefit_summary,
    get_prior_authorization_status,
    lookup_claim_status,
    search_claims_by_member,
)


def test_lookup_claim_status_returns_known_claim() -> None:
    result = lookup_claim_status.invoke({"claim_id": "CLM-1001"})
    assert result["found"] is True
    assert result["status"] == "approved"
    assert result["member_id"] == "MBR-2001"


def test_search_claims_by_member_returns_all_member_claims() -> None:
    result = search_claims_by_member.invoke({"member_id": "MBR-2001"})
    assert result["found"] is True
    assert result["claim_count"] == 2
    assert {claim["claim_id"] for claim in result["claims"]} == {"CLM-1001", "CLM-1006"}


def test_check_member_eligibility_returns_not_found_payload() -> None:
    result = check_member_eligibility.invoke({"member_id": "MBR-9999"})
    assert result["found"] is False
    assert "No member" in result["message"]


def test_get_benefit_summary_returns_services() -> None:
    result = get_benefit_summary.invoke({"plan_code": "PLAN-B2"})
    assert result["found"] is True
    assert "outpatient imaging" in result["covered_services"]


def test_get_prior_authorization_status_returns_known_authorization() -> None:
    result = get_prior_authorization_status.invoke({"auth_id": "AUTH-3002"})
    assert result["found"] is True
    assert result["status"] == "pending"
    assert result["decision_date"] is None
