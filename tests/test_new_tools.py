try:
    from claims_agent.tools import get_prior_authorization_status, search_claims_by_member
except ImportError:
    get_prior_authorization_status = None
    search_claims_by_member = None



def test_search_claims_by_member_returns_known_member_claims() -> None:
    assert search_claims_by_member is not None

    result = search_claims_by_member.invoke({"member_id": "MBR-2001"})

    assert result["found"] is True
    assert result["member_id"] == "MBR-2001"
    assert [claim["claim_id"] for claim in result["claims"]] == ["CLM-1001", "CLM-1006"]
    assert all(claim["member_id"] == "MBR-2001" for claim in result["claims"])
    assert {claim["status"] for claim in result["claims"]} == {"approved", "pending"}



def test_search_claims_by_member_returns_not_found_payload_for_unknown_member() -> None:
    assert search_claims_by_member is not None

    result = search_claims_by_member.invoke({"member_id": "MBR-9999"})

    assert result["member_id"] == "MBR-9999"
    assert result["found"] is False
    assert set(result) == {"member_id", "found", "message"}
    assert result["message"]



def test_get_prior_authorization_status_returns_known_authorization() -> None:
    assert get_prior_authorization_status is not None

    result = get_prior_authorization_status.invoke({"auth_id": "AUTH-3001"})

    assert result["found"] is True
    assert result["auth_id"] == "AUTH-3001"
    assert result["member_id"]
    assert result["procedure_code"]
    assert result["status"]
    assert result["requested_date"]
    assert "decision_date" in result



def test_get_prior_authorization_status_returns_not_found_payload() -> None:
    assert get_prior_authorization_status is not None

    result = get_prior_authorization_status.invoke({"auth_id": "AUTH-9999"})

    assert result["auth_id"] == "AUTH-9999"
    assert result["found"] is False
    assert set(result) == {"auth_id", "found", "message"}
    assert result["message"]
