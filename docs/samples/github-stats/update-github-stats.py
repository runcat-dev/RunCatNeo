#!/usr/bin/env python3
"""
RunCat Neo — GitHub Statistics sample.

Fetches GitHub contribution stats and writes ~/.runcat/github-stats.json shaped like:

    {
      "title": "GitHub",
      "symbol": "chevron.left.forwardslash.chevron.right",
      "metricsBarValue": "5",
      "metrics": [
        {"title": "Today", "formattedValue": "5 commits"},
        {"title": "This Week", "formattedValue": "23 commits", "normalizedValue": 0.23},
        {"title": "Streak", "formattedValue": "42 days"},
        {"title": "Best Streak", "formattedValue": "128 days"},
        {"title": "PRs Merged", "formattedValue": "3 this week"}
      ],
      "lastUpdatedDate": "2026-07-18T09:30:00Z"
    }

Setup:
1. Install GitHub CLI if you haven't already:
   brew install gh

2. Authenticate with GitHub:
   gh auth login

3. Run the script manually to test:
   ./update-github-stats.py

4. Set up periodic execution (see launchd plist example)

The script automatically uses your GitHub CLI authentication - no tokens to manage!
"""

import json
import os
import sys
import subprocess
import tempfile
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".runcat" / "github-stats.json")))


def run_gh_command(args):
    """Run a gh command and return its output."""
    try:
        result = subprocess.run(
            ["gh"] + args,
            capture_output=True,
            text=True,
            check=True,
            timeout=15
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"gh command failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print("Error: GitHub CLI (gh) not found. Install it with: brew install gh", file=sys.stderr)
        sys.exit(1)


# Get token and username from GitHub CLI
try:
    GITHUB_TOKEN = run_gh_command(["auth", "token"])
    user_json = run_gh_command(["api", "user"])
    GITHUB_USERNAME = json.loads(user_json)["login"]
except Exception as e:
    print(f"Error getting GitHub credentials: {e}", file=sys.stderr)
    print("Make sure you're logged in with: gh auth login", file=sys.stderr)
    sys.exit(1)


def github_graphql(query):
    """Execute a GitHub GraphQL query."""
    url = "https://api.github.com/graphql"
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Content-Type": "application/json",
    }
    data = json.dumps({"query": query}).encode("utf-8")

    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"GitHub API error: {e}", file=sys.stderr)
        sys.exit(1)


def get_contribution_stats():
    """Fetch contribution statistics from GitHub."""
    today = datetime.now(timezone.utc)
    week_start = today - timedelta(days=today.weekday())

    query = f"""
    {{
      user(login: "{GITHUB_USERNAME}") {{
        contributionsCollection(from: "{week_start.isoformat()}", to: "{today.isoformat()}") {{
          contributionCalendar {{
            totalContributions
            weeks {{
              contributionDays {{
                contributionCount
                date
              }}
            }}
          }}
        }}
      }}
    }}
    """

    result = github_graphql(query)

    if "errors" in result:
        print(f"GraphQL errors: {result['errors']}", file=sys.stderr)
        sys.exit(1)

    user = result["data"]["user"]
    week_data = user["contributionsCollection"]["contributionCalendar"]

    # Calculate today's contributions
    today_str = today.strftime("%Y-%m-%d")
    today_contributions = 0
    week_contributions = 0

    for week in week_data["weeks"]:
        for day in week["contributionDays"]:
            week_contributions += day["contributionCount"]
            if day["date"] == today_str:
                today_contributions = day["contributionCount"]

    return {
        "today": today_contributions,
        "week": week_contributions,
    }


def calculate_streak():
    """Calculate current and best streak from all-time contributions."""
    # Fetch last year of contributions
    today = datetime.now(timezone.utc)
    year_ago = today - timedelta(days=365)

    query = f"""
    {{
      user(login: "{GITHUB_USERNAME}") {{
        contributionsCollection(from: "{year_ago.isoformat()}", to: "{today.isoformat()}") {{
          contributionCalendar {{
            weeks {{
              contributionDays {{
                contributionCount
                date
              }}
            }}
          }}
        }}
      }}
    }}
    """

    result = github_graphql(query)
    weeks = result["data"]["user"]["contributionsCollection"]["contributionCalendar"]["weeks"]

    # Flatten all days
    days = []
    for week in weeks:
        for day in week["contributionDays"]:
            days.append(day)

    # Sort by date descending (newest first)
    days.sort(key=lambda d: d["date"], reverse=True)

    # Calculate current streak
    current_streak = 0
    for day in days:
        if day["contributionCount"] > 0:
            current_streak += 1
        else:
            break

    # Calculate best streak
    best_streak = 0
    temp_streak = 0
    for day in reversed(days):  # Process chronologically for best streak
        if day["contributionCount"] > 0:
            temp_streak += 1
            best_streak = max(best_streak, temp_streak)
        else:
            temp_streak = 0

    return current_streak, max(best_streak, current_streak)


def get_merged_prs():
    """Get count of merged PRs this week."""
    today = datetime.now(timezone.utc)
    week_start = today - timedelta(days=today.weekday())

    query = f"""
    {{
      search(query: "author:{GITHUB_USERNAME} is:pr is:merged merged:>={week_start.strftime('%Y-%m-%d')}", type: ISSUE, first: 100) {{
        issueCount
      }}
    }}
    """

    result = github_graphql(query)
    return result["data"]["search"]["issueCount"]


try:
    stats = get_contribution_stats()
    current_streak, best_streak = calculate_streak()
    merged_prs = get_merged_prs()

    metrics = [
        {"title": "Today", "formattedValue": f"{stats['today']} commits"},
        {
            "title": "This Week",
            "formattedValue": f"{stats['week']} commits",
            "normalizedValue": round(min(stats['week'] / 100, 1.0), 4)  # Normalize to max 100 commits
        },
    ]

    if current_streak > 0:
        metrics.append({"title": "Streak", "formattedValue": f"{current_streak} days"})

    if best_streak > 0:
        metrics.append({"title": "Best Streak", "formattedValue": f"{best_streak} days"})

    if merged_prs > 0:
        metrics.append({"title": "PRs Merged", "formattedValue": f"{merged_prs} this week"})

    snapshot = {
        "title": "GitHub",
        "symbol": "chevron.left.forwardslash.chevron.right",
        "metricsBarValue": str(stats['today']),
        "metrics": metrics,
        "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".github-stats-", dir=str(OUT.parent))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, ensure_ascii=False, indent=2)
    os.replace(tmp, OUT)

    print(f"✓ GitHub stats updated: {stats['today']} commits today, {current_streak} day streak")

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
