#!/usr/bin/env python3
"""Read-only deployment smoke test. Credentials are prompted, never passed in CLI args."""
import argparse
import base64
import getpass
import urllib.error
import urllib.request
p = argparse.ArgumentParser()
p.add_argument("--app-url", required=True)
p.add_argument("--static-url", required=True)
a = p.parse_args()
username = input("Demo username: ")
password = getpass.getpass("Demo password: ")
auth = "Basic " + base64.b64encode(f"{username}:{password}".encode()).decode()
def check(url, expected=200, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            status, result = r.status, r.headers
    except urllib.error.HTTPError as e:
        status, result = e.code, e.headers
    assert status == expected, f"{url}: expected {expected}; got {status}"
    print(f"PASS HTTP {status}: {url}")
    return result
check(a.app_url.rstrip("/") + "/health")
check(a.app_url.rstrip("/") + "/ready")
check(a.app_url, 401)
check(a.app_url, headers={"Authorization": auth})
check(a.app_url, 403, {"x-lab-waf-test": "block-me"})
check(a.static_url)
headers = check(a.static_url)
print("CloudFront cache observation:", headers.get("X-Cache", "not returned"))
print("Capture actual X-Cache/Age evidence; a miss alone is not a failure on a new cache node.")
