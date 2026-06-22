#!/usr/bin/env python3
"""Rank the most popular onboarding categories from live dashboard data.

Category picks are not aggregated anywhere server-side — they live only as the
`value` string on each user's "Onboarding-11-Categories" event (a comma-joined
list of topic titles). This pulls every customer's timeline via the dashboard's
authenticated HTTP API and tallies them.

Usage (password never touches the repo — pass it via env):

    DASH_PW='the-dashboard-password' python3 server/category_popularity.py

Options via env:
    BASE_URL   override the server (default: production Render URL)
    ENV_FILTER  'production' | 'sandbox' | 'all'  (default: production)
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter

BASE_URL = os.environ.get("BASE_URL", "https://vocabgenius-vx2s.onrender.com").rstrip("/")
ENV_FILTER = os.environ.get("ENV_FILTER", "production").lower()
PW = os.environ.get("DASH_PW")

if not PW:
    sys.exit("Set DASH_PW to the dashboard password. "
             "e.g.  DASH_PW='...' python3 server/category_popularity.py")

_AUTH = "Basic " + base64.b64encode(f"dashboard:{PW}".encode()).decode()


def get(path):
    req = urllib.request.Request(BASE_URL + path, headers={"Authorization": _AUTH})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 401:
            sys.exit("401 Unauthorized — wrong DASH_PW.")
        raise


def main():
    customers = get("/customers")
    print(f"{len(customers)} customers total. Fetching timelines...", file=sys.stderr)

    cat_counts = Counter()        # topic title -> number of users who picked it
    combo_counts = Counter()      # exact selection set -> users
    users_with_pick = 0
    sizes = []                    # how many topics each user picked

    for i, c in enumerate(customers, 1):
        uid = c["userId"]
        timeline = get(f"/customer?id={urllib.parse.quote(uid)}")
        # Find this user's most recent Categories selection.
        pick = None
        for ev in timeline:  # chronological; last one wins
            if ev.get("event") != "onboarding_step":
                continue
            if "Categories" not in (ev.get("step") or ""):
                continue
            if ENV_FILTER != "all" and ev.get("environment") != ENV_FILTER:
                continue
            if ev.get("value"):
                pick = ev["value"]
        if pick:
            users_with_pick += 1
            topics = [t.strip() for t in pick.split(",") if t.strip()]
            sizes.append(len(topics))
            for t in topics:
                cat_counts[t] += 1
            combo_counts[" + ".join(sorted(topics))] += 1
        if i % 25 == 0:
            print(f"  ...{i}/{len(customers)}", file=sys.stderr)

    print(f"\n=== Category popularity ({ENV_FILTER}) ===")
    print(f"{users_with_pick} users made a category selection "
          f"(avg {sum(sizes)/len(sizes):.1f} topics each)\n" if sizes else "No selections found.\n")
    width = max((len(t) for t in cat_counts), default=10)
    for topic, n in cat_counts.most_common():
        pct = 100 * n / users_with_pick if users_with_pick else 0
        bar = "█" * round(pct / 2)
        print(f"  {topic:<{width}}  {n:4d}  {pct:4.0f}%  {bar}")

    print("\n=== Top 10 exact combinations ===")
    for combo, n in combo_counts.most_common(10):
        print(f"  {n:4d}  {combo}")


if __name__ == "__main__":
    main()
