import io
import json
import unittest

from intake import api_page, source_status, review_seed


def response(body):
    return io.BytesIO(body.encode() if isinstance(body, str) else json.dumps(body).encode())


class IntakeTests(unittest.TestCase):
    def test_greenhouse_active_requisition_and_employer(self):
        listing = {"id": "a", "sourceUrl": "https://careers.feedzai.com/job_description?gh_jid=7882365", "companyDomain": "feedzai.com", "title": "Platform Engineer - Compute"}
        calls = []

        def open_url(url, timeout):
            calls.append(url)
            return response({"id": 7882365, "title": "Platform Engineer - Compute", "company_name": "Feedzai", "absolute_url": listing["sourceUrl"]})

        result = source_status(listing, open_url)
        self.assertEqual(result["open"], True)
        self.assertEqual(result["employer"], "Feedzai")
        self.assertEqual(result["sourceKey"], "greenhouse:7882365")
        self.assertEqual(calls, ["https://boards-api.greenhouse.io/v1/boards/feedzai/jobs/7882365"])

    def test_ashby_open_and_closed_are_independent_of_dreamwork(self):
        listing = {"sourceUrl": "https://jobs.ashbyhq.com/dedalus-labs/abc", "title": "Engineer"}

        def ashby(is_listed):
            return lambda url, timeout: response('<script>window.__appData = ' + json.dumps({"organization": {"name": "Dedalus Labs"}, "posting": {"id": "abc", "title": "Engineer", "isListed": is_listed, "workplaceType": "OnSite"}}) + ';</script>')

        self.assertTrue(source_status(listing, ashby(True))["open"])
        self.assertFalse(source_status(listing, ashby(False))["open"])
        self.assertEqual(source_status(listing, ashby(True))["workSetting"], "onsite")

    def test_workday_requires_posted_and_can_apply(self):
        listing = {"sourceUrl": "https://cboe.wd1.myworkdayjobs.com/External/job/Chicago/Engineer_R-4705-1", "title": "Engineer"}
        calls = []

        def open_url(url, timeout):
            calls.append(url)
            return response({"jobPostingInfo": {"title": "Engineer", "posted": True, "canApply": True, "jobReqId": "R-4705", "hiringOrganization": {"name": "Cboe"}}})

        self.assertTrue(source_status(listing, open_url)["open"])
        self.assertEqual(calls, ["https://cboe.wd1.myworkdayjobs.com/wday/cxs/cboe/External/job/Chicago/Engineer_R-4705-1"])

    def test_unreachable_and_unknown_sources_fail_closed(self):
        listing = {"sourceUrl": "https://untrusted.example/job/1", "title": "Engineer"}
        self.assertIsNone(source_status(listing, lambda url, timeout: self.fail("Untrusted host was fetched"))["open"])
        listing["sourceUrl"] = "https://jobs.ashbyhq.com/dedalus-labs/abc"
        self.assertIsNone(source_status(listing, lambda url, timeout: response("Not a job page"))["open"])

    def test_removed_related_job_does_not_close_active_employer_role(self):
        listing = {"sourceUrl": "https://www.amazon.jobs/en/jobs/1/engineer", "title": "Engineer"}
        page = "Engineer Apply now Related positions: Other job Job removed"
        self.assertTrue(source_status(listing, lambda url, timeout: response(page))["open"])
        self.assertFalse(source_status(listing, lambda url, timeout: response("Engineer Job removed"))["open"])

    def test_review_seed_never_invents_degree_or_remote_eligibility(self):
        listing = {"id": "x", "title": "Engineer", "seniorityLevel": "MID", "sourceUrl": "https://example.com", "remoteType": "remote", "remoteEligibilityCountries": ["US"], "publicSalary": {"min": 120000, "max": 150000, "currency": "USD", "period": "year", "disclosure": "estimate"}}
        seed = review_seed(listing, {"open": True, "sourceKey": "example:x", "employer": "Example"})
        self.assertEqual(seed["degree"], "unknown")
        self.assertIsNone(seed["clearanceRequired"])
        self.assertEqual(seed["workSetting"], "unknown")
        self.assertEqual(seed["remoteCountries"], [])
        self.assertEqual(seed["pay"]["source"], "estimate")

    def test_portugal_api_fallback_flags_wrong_country_and_invalid_rows(self):
        calls = []

        def open_url(request, timeout):
            calls.append(request.full_url)
            return response({"total": 3, "pageSize": 3, "listings": [
                {"id": "ok", "title": "Platform Engineer", "companyName": "Feedzai", "location": "Portugal", "locationCountryCode": "PT", "remoteEligibilityCountries": None, "remoteType": "hybrid", "salary": None, "salaryMin": None, "salaryMax": None, "postedAt": "2026-10-01", "firstSeenAt": "2026-10-02", "sourceUrl": "https://feedzai.com/jobs"},
                {"id": "wrong", "title": "Platform Engineer", "companyName": "Recruiter", "location": "New Zealand", "locationCountryCode": "NZ", "remoteEligibilityCountries": [], "remoteType": "remote", "salary": None, "salaryMin": None, "salaryMax": None, "postedAt": "2026-10-01", "firstSeenAt": "2026-10-02", "sourceUrl": "https://example.com/jobs"},
                {"id": "invalid", "title": 1},
            ]})

        result = api_page("key", "Portugal", "Platform", 3, 0, open_url)
        self.assertEqual(len(result["listings"]), 2)
        self.assertEqual(result["invalidIds"], ["invalid"])
        self.assertEqual(result["listings"][1]["locationWarning"], "Portugal eligibility not established")
        self.assertIn("offset=0", calls[0])
        api_page("key", "Europe", "Backend", 3, 0, open_url, remote=True)
        self.assertIn("workType=remote", calls[-1])


if __name__ == "__main__":
    unittest.main()
