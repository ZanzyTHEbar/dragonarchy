import json
import unittest
from pathlib import Path

from qc import evaluate, evaluate_all


def role(**patch):
    item = {
        "id": "listing-1",
        "sourceKey": "ashby:role-1",
        "title": "Software Engineer II",
        "seniority": "MID",
        "descriptionSeniority": "mid",
        "employerEntities": ["Example Inc"],
        "originalOpen": True,
        "degree": "equivalent",
        "clearanceRequired": False,
        "region": "US",
        "workSetting": "onsite",
        "workCountry": "US",
        "geography": "us_priority",
        "remoteCountries": [],
        "pay": {"source": "employer", "currency": "USD", "min": 120000, "max": 160000},
        "primary": ["go", "backend", "platform"],
        "systems": ["distributed", "infra"],
        "secondary": ["kubernetes", "sql"],
        "handsOn": True,
        "explicitMid": True,
        "resumeExamples": ["Avular platform delivery"],
        "publicProjects": ["mcp-edge-gateway"],
    }
    item.update(patch)
    return item


class QualityControlTests(unittest.TestCase):
    def test_rejects_senior_before_scoring(self):
        result = evaluate(role(title="Senior Engineer"), {})
        self.assertEqual((result["status"], result["score"]), ("rejected", None))

    def test_rejects_alias_and_reused_requisition(self):
        self.assertEqual(
            evaluate(role(employerEntities=["Intermediary", "Cloudflare"]), {})["status"],
            "rejected",
        )
        ledger = {"old-id": {"sourceKey": "ashby:role-1", "reason": "senior"}}
        self.assertEqual(evaluate(role(), ledger)["status"], "rejected")

    def test_unavailable_original_source_is_held_not_permanently_rejected(self):
        ledger = {"listing-1": {"sourceKey": "ashby:role-1", "reason": "ATS unavailable", "status": "manual"}}
        self.assertEqual(evaluate(role(), ledger)["status"], "manual")
        self.assertEqual(evaluate(role(id="alias"), ledger)["status"], "manual")

    def test_holds_unverified_and_ambiguous_seniority(self):
        self.assertEqual(evaluate(role(originalOpen=None), {})["status"], "manual")
        self.assertEqual(
            evaluate(role(title="Member of Technical Staff", seniority="SENIOR", descriptionSeniority="unknown"), {})["status"],
            "manual",
        )

    def test_holds_us_only_remote_while_residing_in_portugal(self):
        result = evaluate(role(workSetting="remote", remoteCountries=["US"], geography="us_only_remote"), {})
        self.assertEqual((result["status"], result["score"]), ("manual", None))

    def test_holds_unverified_required_technical_qualification(self):
        self.assertEqual(evaluate(role(mandatorySkillGap=["Databricks administration"]), {})["status"], "manual")

    def test_crossing_salary_is_conditional_but_cap_below_floor_rejects(self):
        crossing = evaluate(role(pay={"source": "employer", "currency": "USD", "min": 88000, "max": 144000}), {})
        self.assertEqual((crossing["status"], crossing["breakdown"]["compensation"]), ("conditional", 5))
        low = evaluate(role(pay={"source": "employer", "currency": "USD", "min": 60000, "max": 99000}), {})
        self.assertEqual((low["status"], low["score"]), ("rejected", None))

    def test_estimate_is_not_employer_pay(self):
        result = evaluate(role(pay={"source": "estimate", "currency": "USD", "min": 130000, "max": 200000}), {})
        self.assertEqual(result["breakdown"]["compensation"], 4)

    def test_unknown_salary_is_not_a_rejection(self):
        self.assertEqual(evaluate(role(pay={"source": "unknown"}), {})["breakdown"]["compensation"], 4)
        self.assertEqual(evaluate(role(pay={"source": "employer", "currency": "USD", "min": 125000}), {})["status"], "eligible")

    def test_duplicate_source_and_identical_reposted_role_are_held(self):
        reviews = [role(), role(id="listing-2"), role(id="listing-3", sourceKey="ashby:role-2", duplicateGroup="same-job")]
        reviews[0]["duplicateGroup"] = "same-job"
        results = evaluate_all(reviews, {})
        self.assertEqual([item["status"] for item in results], ["eligible", "manual", "manual"])

    def test_score_is_sum_of_capped_components(self):
        result = evaluate(role(), {})
        self.assertEqual(result["status"], "eligible")
        self.assertEqual(result["score"], sum(result["breakdown"].values()))
        self.assertEqual(result["breakdown"], {
            "technical": 25, "engineering": 20, "geography": 13, "compensation": 15, "evidence": 5,
        })

    def test_verified_shortlist_has_no_known_hard_failures(self):
        directory = Path(__file__).parent
        reviews = json.loads((directory / "reviews.json").read_text())
        rejected = json.loads((directory / "rejections.json").read_text())
        eligible = [item for item in reviews if evaluate(item, rejected)["status"] == "eligible"]
        self.assertGreaterEqual(len(eligible), 20)
        self.assertEqual(len({item["sourceKey"] for item in eligible}), len(eligible))
        self.assertTrue(all(item["originalOpen"] and item["seniority"] == "MID" for item in eligible))
        self.assertGreater(len({evaluate(item, rejected)["score"] for item in eligible}), 5)
        self.assertTrue(any(evaluate(item, rejected)["status"] == "conditional" for item in reviews))
        feedzai = next(item for item in reviews if item["id"] == "3145752c-3b0b-4175-8add-078c6249fc82")
        self.assertEqual((evaluate(feedzai, rejected)["status"], feedzai["remoteCountries"]), ("eligible", ["PT"]))


if __name__ == "__main__":
    unittest.main()
