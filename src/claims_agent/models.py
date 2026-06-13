from pydantic import BaseModel, Field


class ClaimRecord(BaseModel):
    claim_id: str
    member_id: str
    status: str = Field(description="Claim processing status.")
    service_date: str
    provider: str
    amount: float


class MemberRecord(BaseModel):
    member_id: str
    name: str
    plan_code: str
    eligibility_status: str = Field(description="Member eligibility status.")


class BenefitSummary(BaseModel):
    plan_code: str
    plan_name: str
    deductible: str
    copay: str
    out_of_pocket_max: str
    covered_services: list[str]


class PriorAuthorizationRecord(BaseModel):
    auth_id: str
    member_id: str
    procedure_code: str
    status: str = Field(description="Prior authorization status.")
    requested_date: str
    decision_date: str | None = None
