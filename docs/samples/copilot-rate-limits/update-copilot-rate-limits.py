#!/usr/bin/env python3
"""
RunCat Neo — GitHub Copilot rate-limit sample.

Asks GitHub's Copilot user endpoint how much of your Copilot plan's quotas
(premium requests, chat, completions) is left and writes a Custom Metrics
JSON snapshot shaped like:

    {
      "title": "Copilot Limits",
      "symbol": "cat.circle.fill",
      "metricsBarValue": "17%",
      "metrics": [
        {"title": "Plan",        "formattedValue": "Business"},
        {"title": "Premium",     "formattedValue": "17% left", "normalizedValue": 0.169},
        {"title": "Resets",      "formattedValue": "Aug 1"},
        {"title": "Chat",        "formattedValue": "Unlimited"},
        {"title": "Completions", "formattedValue": "Unlimited"}
      ],
      "lastUpdatedDate": "2026-07-21T05:00:00Z"
    }

The access token comes from the `gh` CLI (`gh auth token`), so you must be
signed in with `gh auth login`. The token is sent only to api.github.com.
Note that the endpoint (`/copilot_internal/user`) is what Copilot's own
clients use but is not officially documented, so its response shape may
change without notice.

Environment overrides:
  RUNCAT_OUT_FILE      Where to write the snapshot.
                       Default: ~/.copilot/runcat-copilot-limits.json
  RUNCAT_LIMITS_SHOW   "remaining" (default) or "used" — whether rows and
                       bars show what is left or what is consumed.
  RUNCAT_GH_CLI        Path to the `gh` binary. Default: auto-detected from
                       PATH and common install locations (needed because
                       launchd jobs run with a minimal PATH that usually
                       omits Homebrew).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".copilot" / "runcat-copilot-limits.json")))
SHOW_USED = os.environ.get("RUNCAT_LIMITS_SHOW", "remaining").strip().lower() == "used"
GH_CLI_OVERRIDE = os.environ.get("RUNCAT_GH_CLI", "").strip()

USAGE_URL = "https://api.github.com/copilot_internal/user"
QUOTA_LABELS = {"premium_interactions": "Premium", "chat": "Chat", "completions": "Completions"}
QUOTA_ORDER = ["premium_interactions", "chat", "completions"]


def fail(message):
    # Leave the previous snapshot in place; RunCat keeps showing it and the
    # card recovers on the next successful run.
    print(f"update-copilot-rate-limits: {message}", file=sys.stderr)
    sys.exit(1)


def find_gh_cli():
    """Locate the `gh` binary even under launchd's minimal PATH."""
    if GH_CLI_OVERRIDE:
        return GH_CLI_OVERRIDE if os.access(GH_CLI_OVERRIDE, os.X_OK) else None
    found = shutil.which("gh")
    if found:
        return found
    for candidate in (
        Path("/opt/homebrew/bin/gh"),
        Path("/usr/local/bin/gh"),
        Path.home() / ".local" / "bin" / "gh",
    ):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def load_token():
    """Return the GitHub access token the `gh` CLI is signed in with."""
    gh_cli = find_gh_cli()
    if not gh_cli:
        fail("`gh` CLI not found — install it (brew install gh) or set RUNCAT_GH_CLI to its full path")
    try:
        result = subprocess.run([gh_cli, "auth", "token"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        fail(f"`gh auth token` failed to run: {error}")
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        fail(f"`gh auth token` returned no token — sign in with `gh auth login` ({result.stderr.strip()})")
    return token


def fetch_usage(token):
    request = urllib.request.Request(USAGE_URL, headers={
        "Authorization": f"token {token}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except Exception as error:  # HTTP error, network down, bad JSON — all leave the old snapshot.
        fail(f"usage request failed: {error}")


def reset_day(iso_date):
    """'2026-08-01' -> 'Aug 1'."""
    try:
        return datetime.strptime(iso_date, "%Y-%m-%d").strftime("%b %-d")
    except (TypeError, ValueError):
        return None


def quota_rows(usage):
    snapshots = usage.get("quota_snapshots")
    if not isinstance(snapshots, dict) or not snapshots:
        fail("response contains no quota snapshots — does this account have a Copilot plan?")
    rows = []
    bar_value = None
    ordered = [key for key in QUOTA_ORDER if key in snapshots]
    ordered += [key for key in sorted(snapshots) if key not in QUOTA_ORDER]
    for key in ordered:
        snapshot = snapshots[key]
        if not isinstance(snapshot, dict):
            continue
        label = QUOTA_LABELS.get(key, key.replace("_", " ").title())
        if snapshot.get("unlimited"):
            rows.append({"title": label, "formattedValue": "Unlimited"})
            continue
        left = snapshot.get("percent_remaining")
        if not isinstance(left, (int, float)):
            continue
        left = min(max(left, 0), 100)
        shown = 100 - left if SHOW_USED else left
        suffix = "used" if SHOW_USED else "left"
        rows.append({
            "title": label,
            "formattedValue": f"{shown:.0f}% {suffix}",
            "normalizedValue": round(shown / 100, 4),
        })
        overage = snapshot.get("overage_count")
        if isinstance(overage, (int, float)) and overage > 0:
            rows.append({"title": f"{label} overage", "formattedValue": f"{overage:.0f} reqs"})
        if key == "premium_interactions":
            bar_value = f"{shown:.0f}%"
            resets = reset_day(usage.get("quota_reset_date"))
            if resets:
                rows.append({"title": "Resets", "formattedValue": resets})
    return rows, bar_value


def build_snapshot(usage):
    rows, bar_value = quota_rows(usage)
    plan = (usage.get("copilot_plan") or "").replace("_", " ").title()
    if plan:
        rows.insert(0, {"title": "Plan", "formattedValue": plan})
    snapshot = {
        "title": "Copilot Limits",
        "symbol": "cat.circle.fill",
        "metrics": rows,
        "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if bar_value is not None:
        snapshot["metricsBarValue"] = bar_value
    return snapshot


def write_atomically(snapshot):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(snapshot, handle, ensure_ascii=False)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    write_atomically(build_snapshot(fetch_usage(load_token())))
