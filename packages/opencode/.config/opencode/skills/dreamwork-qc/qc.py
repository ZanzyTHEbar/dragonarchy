"""Score reviewed Dreamwork listings; the full listing and live employer post must be checked first."""

import argparse
import json
import re
from pathlib import Path


EXCLUDED_EMPLOYERS = ("volkswagen", "cloudflare", "thought machines")
EXCLUDED_TITLE = re.compile(r"\b(senior|sr\.?|staff|principal|lead|manager|director|executive|vp|cto)\b", re.I)
EXCLUDED_LEVELS = {"SENIOR", "STAFF", "PRINCIPAL", "DIRECTOR", "VP", "C_SUITE"}
GEOGRAPHY = {"pt_local": 15, "pt_other": 7, "us_priority": 13, "us_other": 10, "eu_remote_pt": 15}


def evaluate(item, rejected):
    """Return a fail-closed decision and an independently calculated 0–100 score."""
    listing_id = item["id"]

    def decision(status, reason, breakdown=None):
        return {
            "id": listing_id, "status": status, "reason": reason,
            "score": sum(breakdown.values()) if breakdown is not None else None,
            "breakdown": breakdown,
        }

    if listing_id in rejected:
        return decision(rejected[listing_id].get("status", "rejected"), rejected[listing_id]["reason"])
    source_key = item.get("sourceKey")
    prior = next((entry for entry in rejected.values() if source_key and entry.get("sourceKey") == source_key), None)
    if prior:
        return decision(prior.get("status", "rejected"), prior["reason"])
    if not source_key or not item.get("employerEntities"):
        return decision("manual", "Original requisition or hiring employer not identified")
    if any(name in entity.casefold() for name in EXCLUDED_EMPLOYERS for entity in item["employerEntities"]):
        return decision("rejected", "Excluded hiring employer, parent, or intermediary")
    title = item.get("title", "")
    if EXCLUDED_TITLE.search(title) and not re.search(r"\bmember of technical staff\b", title, re.I):
        return decision("rejected", "Excluded seniority or management title")
    if item.get("seniority") in EXCLUDED_LEVELS:
        if item.get("descriptionSeniority") == "senior":
            return decision("rejected", "Senior/Staff metadata confirmed by responsibilities")
        return decision("manual", "Seniority metadata conflicts with a neutral title")
    if item.get("descriptionSeniority") not in {"mid", "ic"}:
        return decision("manual", "Seniority in description is ambiguous")
    if item.get("handsOn") is not True or item.get("explicitMid") is not True:
        return decision("manual", "Substantive Mid-Level individual-contributor work not verified")
    if item.get("degree") == "mandatory" or item.get("clearanceRequired") is True:
        return decision("rejected", "Mandatory unavailable degree/credential or existing clearance")
    if item.get("degree") not in {"none", "equivalent"} or item.get("clearanceRequired") is None:
        return decision("manual", "Degree or clearance requirement not verified")
    if item.get("mandatorySkillGap"):
        return decision("manual", "Required technical qualification needs evidence or employer clarification")
    if item.get("originalOpen") is False:
        return decision("rejected", "Employer requisition is closed")
    if item.get("originalOpen") is not True:
        return decision("manual", "Employer/ATS posting not independently verified open")

    geography = item.get("geography")
    setting = item.get("workSetting")
    region = item.get("region")
    if geography not in GEOGRAPHY or setting not in {"onsite", "hybrid", "remote"}:
        return decision("manual", "Work arrangement or Portugal/US eligibility is unclear")
    if geography.startswith("us_") and (region != "US" or item.get("workCountry") != "US"):
        return decision("manual", "US workplace not independently confirmed")
    if geography.startswith("pt_") and (region != "PT" or item.get("workCountry") != "PT"):
        return decision("manual", "Portugal workplace not independently confirmed")
    if geography == "eu_remote_pt" and "PT" not in item.get("remoteCountries", []):
        return decision("manual", "EU remote does not explicitly include Portugal")
    if setting == "remote" and "PT" not in item.get("remoteCountries", []):
        return decision("manual", "Remote listing does not authorize working from Portugal now")

    pay = item.get("pay") or {}
    pay_source = pay.get("source")
    if region == "US" and pay_source == "employer":
        if pay.get("currency") != "USD":
            return decision("manual", "US employer base-pay currency is unclear")
        if pay.get("max") is not None and pay["max"] < 100000:
            return decision("rejected", "US employer base-pay ceiling is below $100,000")
        minimum = pay.get("min")
        compensation = 15 if minimum is not None and minimum >= 120000 else 12 if minimum is not None and minimum >= 100000 else 5 if pay.get("max") is not None else 4
    else:
        compensation = 10 if region != "US" and pay_source == "employer" else 4

    primary = len(set(item.get("primary", [])) & {"go", "backend", "platform", "linux"}) * 5
    systems = len(set(item.get("systems", [])) & {"distributed", "infra", "data", "embedded"}) * 3
    secondary = len(set(item.get("secondary", [])) & {"kubernetes", "sql", "networking", "cicd"}) * 2
    breakdown = {
        "technical": min(primary, 20) + min(systems, 12) + min(secondary, 8),
        "engineering": (12 if item.get("handsOn") else 0) + (8 if item.get("explicitMid") else 0),
        "geography": GEOGRAPHY[geography],
        "compensation": compensation,
        "evidence": min(6, 3 * len(set(item.get("resumeExamples", []))))
        + min(4, 2 * len(set(item.get("publicProjects", [])))),
    }
    status = "conditional" if region == "US" and compensation == 5 else "eligible"
    return decision(status, "Pay band crosses US floor" if status == "conditional" else "Verified screening passed", breakdown)


def evaluate_all(reviews, rejected):
    """Hold duplicate postings even when their Dreamwork listing IDs differ."""
    seen = {}
    results = []
    for item in reviews:
        keys = [item.get("sourceKey"), item.get("duplicateGroup")]
        previous = next((seen[key] for key in keys if key and key in seen), None)
        if previous:
            results.append({"id": item["id"], "status": "rejected" if previous[1] == "rejected" else "manual", "reason": f"Duplicate of {previous[0]}", "score": None, "breakdown": None})
            continue
        result = evaluate(item, rejected)
        for key in keys:
            if key:
                seen[key] = (item["id"], result["status"])
        results.append(result)
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reviews", type=Path)
    parser.add_argument("rejections", type=Path)
    args = parser.parse_args()
    results = evaluate_all(json.loads(args.reviews.read_text()), json.loads(args.rejections.read_text()))
    print(json.dumps(sorted(results, key=lambda result: result["score"] or -1, reverse=True), indent=2))
