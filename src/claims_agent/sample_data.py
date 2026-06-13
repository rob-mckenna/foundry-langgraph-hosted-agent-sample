from claims_agent.models import BenefitSummary, ClaimRecord, MemberRecord, PriorAuthorizationRecord

CLAIMS = [
    ClaimRecord(claim_id="CLM-1001", member_id="MBR-2001", status="approved", service_date="2026-05-10", provider="Northwind Family Clinic", amount=245.30),
    ClaimRecord(claim_id="CLM-1002", member_id="MBR-2002", status="pending", service_date="2026-05-18", provider="Contoso Imaging Center", amount=1120.00),
    ClaimRecord(claim_id="CLM-1003", member_id="MBR-2003", status="denied", service_date="2026-05-21", provider="Litware Specialty Pharmacy", amount=86.75),
    ClaimRecord(claim_id="CLM-1004", member_id="MBR-2004", status="in_review", service_date="2026-05-28", provider="Fabrikam Orthopedics", amount=3480.50),
    ClaimRecord(claim_id="CLM-1005", member_id="MBR-2005", status="approved", service_date="2026-06-01", provider="Adventure Works Lab Services", amount=164.20),
    ClaimRecord(claim_id="CLM-1006", member_id="MBR-2001", status="pending", service_date="2026-06-03", provider="Northwind Family Clinic", amount=98.40),
]

MEMBERS = [
    MemberRecord(member_id="MBR-2001", name="Avery Patel", plan_code="PLAN-A1", eligibility_status="active"),
    MemberRecord(member_id="MBR-2002", name="Jordan Kim", plan_code="PLAN-B2", eligibility_status="active"),
    MemberRecord(member_id="MBR-2003", name="Taylor Brooks", plan_code="PLAN-C3", eligibility_status="inactive"),
    MemberRecord(member_id="MBR-2004", name="Morgan Lee", plan_code="PLAN-D4", eligibility_status="pending"),
    MemberRecord(member_id="MBR-2005", name="Casey Nguyen", plan_code="PLAN-E5", eligibility_status="active"),
]

BENEFITS = [
    BenefitSummary(plan_code="PLAN-A1", plan_name="Northwind Core PPO", deductible="$500 individual", copay="$30 primary care", out_of_pocket_max="$3,500 individual", covered_services=["preventive care", "primary care visits", "generic prescriptions", "urgent care"]),
    BenefitSummary(plan_code="PLAN-B2", plan_name="Contoso Choice HMO", deductible="$750 individual", copay="$25 primary care", out_of_pocket_max="$4,000 individual", covered_services=["preventive care", "specialist visits with referral", "lab work", "outpatient imaging"]),
    BenefitSummary(plan_code="PLAN-C3", plan_name="Litware Essential HDHP", deductible="$2,000 individual", copay="Plan deductible applies", out_of_pocket_max="$6,850 individual", covered_services=["preventive care", "telehealth", "generic prescriptions after deductible", "emergency services"]),
    BenefitSummary(plan_code="PLAN-D4", plan_name="Fabrikam Premier EPO", deductible="$1,250 individual", copay="$40 specialist", out_of_pocket_max="$5,250 individual", covered_services=["preventive care", "specialist care", "outpatient surgery", "physical therapy"]),
    BenefitSummary(plan_code="PLAN-E5", plan_name="Adventure Works Family PPO", deductible="$1,000 individual / $2,000 family", copay="$35 primary care", out_of_pocket_max="$5,000 individual / $10,000 family", covered_services=["preventive care", "pediatric care", "behavioral health", "mail-order prescriptions"]),
]

PRIOR_AUTHORIZATIONS = [
    PriorAuthorizationRecord(auth_id="AUTH-3001", member_id="MBR-2001", procedure_code="PROC-71020", status="approved", requested_date="2026-06-02", decision_date="2026-06-04"),
    PriorAuthorizationRecord(auth_id="AUTH-3002", member_id="MBR-2003", procedure_code="PROC-99214", status="pending", requested_date="2026-06-05", decision_date=None),
    PriorAuthorizationRecord(auth_id="AUTH-3003", member_id="MBR-2004", procedure_code="PROC-29881", status="denied", requested_date="2026-06-06", decision_date="2026-06-08"),
]
