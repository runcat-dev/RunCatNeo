#!/usr/bin/env python3
"""
RunCat Neo — Claude rate-limit sample.

Asks Anthropic's OAuth usage endpoint how much of your Claude subscription's
rate-limit windows (5-hour, 7-day, 7-day Opus) is left and writes a Custom
Metrics JSON snapshot shaped like:

    {
      "title": "Claude Limits",
      "symbol": "asterisk",
      "metricsBarValue": "84%",
      "metrics": [
        {"title": "Plan",     "formattedValue": "Max"},
        {"title": "5h",       "formattedValue": "84% left", "normalizedValue": 0.84},
        {"title": "5h resets","formattedValue": "14:00"},
        {"title": "7d",       "formattedValue": "99% left", "normalizedValue": 0.99},
        {"title": "7d Opus",  "formattedValue": "97% left", "normalizedValue": 0.97}
      ],
      "lastUpdatedDate": "2026-07-17T05:55:36Z"
    }

The access token is read from the credentials Claude Code already maintains
(macOS Keychain item "Claude Code-credentials", falling back to
`~/.claude/.credentials.json`). The script itself never rewrites those
credentials — but if it finds the token expired, it runs `claude -p "hi"`
once to make Claude Code rotate it, then re-reads and retries. If that
doesn't recover a valid token (e.g. the `claude` CLI isn't installed or you
were never signed in), the script exits without touching the previous
snapshot and recovers on its own after your next Claude Code session.

Environment overrides:
  RUNCAT_OUT_FILE      Where to write the snapshot.
                       Default: ~/.claude/runcat-claude-limits.json
  RUNCAT_LIMITS_SHOW   "remaining" (default) or "used" — whether rows and
                       bars show what is left or what is consumed.
  RUNCAT_CLAUDE_CLI    Path to the `claude` binary used to refresh an
                       expired token. Default: auto-detected from PATH and
                       common install locations (needed because launchd
                       jobs run with a minimal PATH that usually omits it).
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

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".claude" / "runcat-claude-limits.json")))
SHOW_USED = os.environ.get("RUNCAT_LIMITS_SHOW", "remaining").strip().lower() == "used"
CLAUDE_CLI_OVERRIDE = os.environ.get("RUNCAT_CLAUDE_CLI", "").strip()

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
KEYCHAIN_SERVICE = "Claude Code-credentials"
CREDENTIALS_FILE = Path.home() / ".claude" / ".credentials.json"
WINDOWS = [("five_hour", "5h"), ("seven_day", "7d"), ("seven_day_opus", "7d Opus")]


def fail(message):
    # Leave the previous snapshot in place; RunCat keeps showing it and the
    # card recovers on the next successful run.
    print(f"update-claude-rate-limits: {message}", file=sys.stderr)
    sys.exit(1)


def read_credentials():
    """Return the `claudeAiOauth` dict from Claude Code's stored credentials, or {} if unavailable."""
    raw = None
    try:
        raw = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    if not raw:
        try:
            raw = CREDENTIALS_FILE.read_text(encoding="utf-8")
        except OSError:
            return {}
    try:
        return json.loads(raw).get("claudeAiOauth") or {}
    except json.JSONDecodeError:
        return {}


def is_expired(oauth):
    expires_at = oauth.get("expiresAt")
    return isinstance(expires_at, (int, float)) and expires_at / 1000 < datetime.now(timezone.utc).timestamp()


def find_claude_cli():
    """Locate the `claude` binary even under launchd's minimal PATH."""
    if CLAUDE_CLI_OVERRIDE:
        return CLAUDE_CLI_OVERRIDE if os.access(CLAUDE_CLI_OVERRIDE, os.X_OK) else None
    found = shutil.which("claude")
    if found:
        return found
    for candidate in (
        Path.home() / ".local" / "bin" / "claude",
        Path.home() / ".claude" / "local" / "claude",
        Path("/opt/homebrew/bin/claude"),
        Path("/usr/local/bin/claude"),
    ):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def refresh_token():
    """Ask Claude Code to rotate its stored access token with a trivial, non-interactive turn."""
    claude_cli = find_claude_cli()
    if not claude_cli:
        return
    try:
        subprocess.run([claude_cli, "-p", "hi"], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        pass


def load_oauth():
    """Return the `claudeAiOauth` dict from Claude Code's stored credentials, refreshing an expired token first."""
    oauth = read_credentials()
    if oauth and is_expired(oauth):
        refresh_token()
        oauth = read_credentials() or oauth
    if not oauth:
        fail("no credentials found (Keychain item or ~/.claude/.credentials.json) — is Claude Code installed and signed in?")
    if not oauth.get("accessToken"):
        fail("credentials contain no access token")
    if is_expired(oauth):
        fail("access token has expired and automatic refresh via `claude -p \"hi\"` didn't recover it — "
             "run `claude` by hand once, or check that the `claude` CLI is installed and on PATH "
             "(set RUNCAT_CLAUDE_CLI to its full path if needed)")
    return oauth


def fetch_usage(token):
    request = urllib.request.Request(USAGE_URL, headers={
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except Exception as error:  # HTTP error, network down, bad JSON — all leave the old snapshot.
        fail(f"usage request failed: {error}")


def local_clock(iso):
    """'2026-07-17T14:00:00Z' -> '14:00' (or 'Jul 20 14:00' when not today)."""
    try:
        moment = datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    except (TypeError, ValueError):
        return None
    if moment.date() == datetime.now().astimezone().date():
        return moment.strftime("%H:%M")
    return moment.strftime("%b %-d %H:%M")


def collect_windows(usage):
    """Return [(label, used_percent, resets_at, is_session)] from the response.

    Prefers the `limits` array, which is where model-scoped weekly windows
    (e.g. a per-Opus limit) live; falls back to the older top-level keys.
    """
    windows = []
    for limit in usage.get("limits") or []:
        if not isinstance(limit, dict) or not isinstance(limit.get("percent"), (int, float)):
            continue
        kind = limit.get("kind")
        if kind == "session":
            label = "5h"
        elif kind == "weekly_all":
            label = "7d"
        elif kind == "weekly_scoped":
            model = (((limit.get("scope") or {}).get("model")) or {}).get("display_name")
            label = f"7d {model}" if model else "7d (scoped)"
        else:
            label = kind or "Other"
        windows.append((label, limit["percent"], limit.get("resets_at"), kind == "session"))
    if windows:
        return windows
    for key, label in WINDOWS:
        window = usage.get(key)
        if isinstance(window, dict) and isinstance(window.get("utilization"), (int, float)):
            windows.append((label, window["utilization"], window.get("resets_at"), key == "five_hour"))
    return windows


def window_rows(usage):
    rows = []
    bar_value = None
    for label, used, resets_at, is_session in collect_windows(usage):
        used = min(max(used, 0), 100)
        shown = used if SHOW_USED else 100 - used
        suffix = "used" if SHOW_USED else "left"
        rows.append({
            "title": label,
            "formattedValue": f"{shown:.0f}% {suffix}",
            "normalizedValue": round(shown / 100, 4),
        })
        if is_session:
            bar_value = f"{shown:.0f}%"
            resets = local_clock(resets_at)
            if resets:
                rows.append({"title": f"{label} resets", "formattedValue": resets})
    return rows, bar_value


def build_snapshot(oauth, usage):
    rows, bar_value = window_rows(usage)
    plan = (oauth.get("subscriptionType") or "").capitalize()
    if plan:
        rows.insert(0, {"title": "Plan", "formattedValue": plan})
    snapshot = {
        "title": "Claude Limits",
        "symbol": "asterisk",
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
    oauth = load_oauth()
    write_atomically(build_snapshot(oauth, fetch_usage(oauth["accessToken"])))
