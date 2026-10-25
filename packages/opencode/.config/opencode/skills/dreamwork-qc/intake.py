"""Read Dreamwork MCP listings and check original ATS posts without changing the account."""

import argparse
import json
import os
import re
import select
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def source_status(listing, open_url=urllib.request.urlopen):
    """Check an original employer requisition; uncertain responses remain unknown."""
    url = listing.get("sourceUrl") or ""
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or ""
    result = {"open": None, "sourceKey": None, "employer": None, "workSetting": None, "url": url}
    if parsed.scheme != "https":
        return result

    greenhouse = host in {"boards.greenhouse.io", "job-boards.greenhouse.io"} or host == "careers.feedzai.com"
    job_id = re.search(r"/jobs/(\d+)", parsed.path)
    number = None
    tenant = None
    if greenhouse:
        number = job_id.group(1) if job_id else urllib.parse.parse_qs(parsed.query).get("gh_jid", [None])[0]
        board = parsed.path.split("/")[1] if job_id and host != "careers.feedzai.com" else (listing.get("companyDomain") or "").split(".")[0]
        if not number or not board:
            return result
        result["sourceKey"] = f"greenhouse:{number}"
        url = f"https://boards-api.greenhouse.io/v1/boards/{board}/jobs/{number}"
    elif host == "jobs.ashbyhq.com":
        result["sourceKey"] = f"ashby:{parsed.path.rstrip('/').split('/')[-1]}"
    elif host.endswith(".myworkdayjobs.com") and "/job/" in parsed.path:
        tenant = host.split(".")[0]
        site, job_path = parsed.path.lstrip("/").split("/job/", 1)
        url = f"https://{host}/wday/cxs/{tenant}/{site}/job/{job_path}"
    elif host not in {"jobs.lever.co", "www.amazon.jobs", "www.google.com"} and not host.endswith(".teamtailor.com"):
        return result

    try:
        with open_url(url, timeout=20) as page:
            body = page.read().decode("utf-8", errors="replace")
    except (OSError, ValueError, UnicodeError) as exc:
        result["checkError"] = type(exc).__name__
        return result

    if greenhouse:
        try:
            job = json.loads(body)
        except json.JSONDecodeError:
            return result
        if str(job.get("id")) == number and job.get("title"):
            result.update(open=True, employer=job.get("company_name"), title=job["title"])
        return result

    if host == "jobs.ashbyhq.com":
        match = re.search(r"window\.__appData\s*=\s*", body)
        if not match:
            return result
        try:
            data, _ = json.JSONDecoder().raw_decode(body[match.end():])
        except json.JSONDecodeError:
            return result
        posting = data.get("posting") or {}
        if posting.get("id") != parsed.path.rstrip("/").split("/")[-1]:
            return result
        workplace = posting.get("workplaceType")
        setting = {"OnSite": "onsite", "Hybrid": "hybrid", "Remote": "remote"}.get(workplace) if isinstance(workplace, str) else None
        result.update(open=posting.get("isListed"), employer=(data.get("organization") or {}).get("name"), title=posting.get("title"), workSetting=setting)
        return result

    if host.endswith(".myworkdayjobs.com"):
        try:
            posting = json.loads(body)["jobPostingInfo"]
        except (ValueError, KeyError):
            return result
        employer = (posting.get("hiringOrganization") or {}).get("name")
        key_company = "bankofamerica" if employer and employer.casefold().startswith("bank of america") else tenant
        if posting.get("jobReqId"):
            result["sourceKey"] = f"workday:{key_company}:{posting['jobReqId']}"
        setting = {"Mostly On-Site": "hybrid", "Onsite": "onsite", "On-Site": "onsite", "Hybrid": "hybrid", "Partially Remote": "hybrid", "Remote": "remote"}.get(posting.get("remoteType"))
        result.update(open=posting.get("posted") and posting.get("canApply"), employer=employer, title=posting.get("title"), workSetting=setting)
        return result

    title = listing.get("title") or ""
    if title and title.casefold() in body.casefold():
        if re.search(r"apply now|apply for this job", body, re.I):
            result["open"] = True
        elif re.search(re.escape(title) + r".{0,300}(?:job removed|position closed)", body, re.I | re.S):
            result["open"] = False
    return result


def review_seed(listing, source):
    """Output only machine-supported facts; a person must classify the description."""
    pay = listing.get("publicSalary") or {}
    pay_source = "estimate" if pay.get("disclosure") == "estimate" else "unknown"
    return {
        "id": listing["id"], "sourceKey": source.get("sourceKey"), "title": listing.get("title"),
        "seniority": listing.get("seniorityLevel"), "descriptionSeniority": "unknown",
        "employerEntities": [source["employer"]] if source.get("employer") else [],
        "originalOpen": source.get("open"), "degree": "unknown", "clearanceRequired": None,
        "workSetting": source.get("workSetting") or "unknown", "remoteCountries": [],
        "pay": {"source": pay_source, "currency": pay.get("currency"), "min": pay.get("min"), "max": pay.get("max")},
        "primary": [], "systems": [], "secondary": [], "handsOn": None, "explicitMid": None,
        "resumeExamples": [], "publicProjects": [],
    }


def api_page(credential, region, search, limit, offset=0, open_url=urllib.request.urlopen, remote=False):
    """Narrow read-only fallback when Dreamwork MCP rejects a valid listings page."""
    if region not in {"Portugal", "Europe"} or not 1 <= limit <= 25 or not 0 <= offset < 1000:
        raise ValueError("Direct fallback is only for bounded Portugal/Europe searches")
    filters = {"function": "Engineering", "seniority": "Mid-Level", "location": region, "postedWithin": "30", "sort": "newest", "limit": str(limit), "offset": str(offset)}
    if remote:
        filters["workType"] = "remote"
    if search:
        filters["search"] = search
    url = "https://api.dreamworkhq.com/listings?" + urllib.parse.urlencode(filters)
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + credential})
    with open_url(request, timeout=20) as page:
        payload = json.load(page)
    if not isinstance(payload.get("listings"), list) or not isinstance(payload.get("total"), int):
        raise RuntimeError("Dreamwork API returned an invalid inventory response")
    span = payload.get("pageSize")
    if not isinstance(span, int) or span < 1:
        span = limit

    listings = []
    invalid_ids = []
    for row in payload["listings"]:
        if not isinstance(row, dict):
            invalid_ids.append("unknown")
            continue
        fields = ("id", "title", "companyName", "firstSeenAt")
        optional = ("location", "remoteType", "salary", "sourceUrl", "postedAt")
        numeric = ("salaryMin", "salaryMax")
        if (any(not isinstance(row.get(k), str) for k in fields)
                or any(row.get(k) is not None and not isinstance(row[k], str) for k in optional)
                or any(row.get(k) is not None and (not isinstance(row[k], int) or isinstance(row[k], bool)) for k in numeric)):
            invalid_ids.append(str(row.get("id", "unknown")))
            continue
        entry = {
            "id": row["id"], "title": row["title"], "company": row["companyName"],
            "location": row.get("location"), "workSetting": row.get("remoteType"),
            "salary": row.get("salary"), "salaryMin": row.get("salaryMin"), "salaryMax": row.get("salaryMax"),
            "postedAt": row.get("postedAt"), "firstSeenAt": row["firstSeenAt"],
            "url": f"https://www.dreamworkhq.com/job/{row['id']}", "sourceUrl": row.get("sourceUrl"),
        }
        countries = row.get("remoteEligibilityCountries")
        if not isinstance(countries, list) or not all(isinstance(country, str) for country in countries):
            countries = []
        if region == "Portugal" and row.get("locationCountryCode") != "PT" and "PT" not in countries:
            entry["locationWarning"] = "Portugal eligibility not established"
        listings.append(entry)
    return {
        "listings": listings, "invalidIds": invalid_ids, "total": payload["total"],
        "nextOffset": offset + span if offset + span < payload["total"] else None,
        "source": "Direct read-only Dreamwork API fallback; MCP listing contract rejected this page",
        "notes": ["Employer and location are unverified until get_listing and the original ATS are checked."],
    }


class DreamworkReadClient:
    """Small stdio MCP client restricted to read-only Dreamwork tools."""

    TOOLS = {"get_preferences", "get_unread_reminders", "browse_listings", "get_listing", "get_application_readiness", "get_usage"}

    def __enter__(self):
        credential = subprocess.run(["secret-tool", "lookup", "service", "dreamwork", "account", "default"], capture_output=True, check=True).stdout.strip()
        if not credential:
            raise RuntimeError("Dreamwork keyring item is missing")
        env = os.environ.copy()
        self.credential = credential.decode()
        env["DREAMWORK_API_KEY"] = self.credential
        self.process = subprocess.Popen(["npx", "-y", "@dreamworkhq/mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
        self.sequence = 0
        self.buffer = b""
        try:
            self.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "dreamwork-qc", "version": "1.0"}})
            self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except Exception:
            self.__exit__()
            raise
        return self

    def __exit__(self, *_):
        if self.process.stdin:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()

    def send(self, message):
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(message, separators=(",", ":")).encode() + b"\n")
        self.process.stdin.flush()

    def request(self, method, params):
        self.sequence += 1
        request_id = self.sequence
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        deadline = time.monotonic() + 45
        assert self.process.stdout is not None
        fd = self.process.stdout.fileno()
        while time.monotonic() < deadline:
            if b"\n" not in self.buffer:
                ready, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
                if not ready:
                    break
                chunk = os.read(fd, 65536)
                if not chunk:
                    raise RuntimeError("Dreamwork MCP exited before responding")
                self.buffer += chunk
                continue
            line, self.buffer = self.buffer.split(b"\n", 1)
            message = json.loads(line)
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(message["error"].get("message", "Dreamwork MCP request failed"))
            return message["result"]
        raise TimeoutError(f"Dreamwork MCP timed out on {method}")

    def tool(self, name, arguments=None):
        if name not in self.TOOLS:
            raise ValueError("Only explicitly allowed read-only Dreamwork tools may be called")
        result = self.request("tools/call", {"name": name, "arguments": arguments or {}})
        if result.get("isError"):
            raise RuntimeError(result.get("content", [{}])[0].get("text", "Dreamwork tool failed"))
        if result.get("structuredContent"):
            return result["structuredContent"]
        return json.loads(result["content"][0]["text"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    browse = commands.add_parser("browse")
    browse.add_argument("region", choices=["United States", "Portugal", "Europe"])
    browse.add_argument("--search")
    browse.add_argument("--remote", action="store_true", help="Only remote listings; verify the employer accepts residence in Portugal")
    browse.add_argument("--limit", type=int, default=25)
    browse.add_argument("--sort", choices=["newest", "featured", "pay_high", "pay_low"])
    browse.add_argument("--cursor")
    browse.add_argument("--offset", type=int, help="Sorted Portugal/Europe fallback page after an MCP schema error")
    inspect = commands.add_parser("inspect")
    inspect.add_argument("ids", nargs="+")
    inspect.add_argument("--summary", action="store_true", help="Diagnostic view; use the full description before classifying a new role")
    args = parser.parse_args()

    with DreamworkReadClient() as client:
        client.tool("get_unread_reminders")
        client.tool("get_preferences")
        if args.command == "browse":
            query = {"function": ["Engineering"], "seniority": ["Mid-Level"], "location": args.region, "postedWithinDays": 30, "limit": args.limit}
            if args.search:
                query["search"] = args.search
            if args.remote:
                query["workSettings"] = ["remote"]
            if args.sort:
                query["sort"] = args.sort
            if args.cursor:
                query["cursor"] = args.cursor
            if args.offset is not None:
                if args.sort != "newest" or args.cursor:
                    parser.error("--offset requires --sort newest and no --cursor")
                page = api_page(client.credential, args.region, args.search, args.limit, args.offset, remote=args.remote)
            else:
                try:
                    page = client.tool("browse_listings", query)
                except RuntimeError as exc:
                    if "malformed data for listListings" not in str(exc) or args.sort != "newest" or args.cursor:
                        raise
                    page = api_page(client.credential, args.region, args.search, args.limit, remote=args.remote)
            print(json.dumps(page, indent=2))
            return
        ledger = json.loads(Path(__file__).with_name("rejections.json").read_text())
        output = []
        for listing_id in args.ids:
            listing = client.tool("get_listing", {"id": listing_id}).get("listing")
            if not listing:
                output.append({"id": listing_id, "error": "Listing missing"})
                continue
            source = source_status(listing)
            prior = ledger.get(listing_id) or next((entry for entry in ledger.values() if entry.get("sourceKey") == source.get("sourceKey")), None)
            listing.pop("descriptionHtml", None)
            displayed = {key: listing.get(key) for key in ("id", "title", "companyName", "location", "seniorityLevel", "remoteType", "sourceUrl")} if args.summary else listing
            output.append({"listing": displayed, "original": source, "priorDecision": prior, "reviewSeed": review_seed(listing, source)})
        print(json.dumps(output, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, TimeoutError) as exc:
        print(f"Intake failed: {exc}", file=sys.stderr)
        sys.exit(1)
