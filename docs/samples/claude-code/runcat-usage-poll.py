#!/usr/bin/env python3
"""
RunCat Neo — out-of-band Claude usage poller (UNOFFICIAL / EXPERIMENTAL).

Fetches subscription rate-limit runway from Claude Code's own (undocumented)
usage endpoint and writes the RunCat Custom Metrics card WITHOUT a running
Claude Code session:

    GET https://api.anthropic.com/api/oauth/usage
    Authorization: Bearer <token from login Keychain "Claude Code-credentials">
    anthropic-beta: oauth-2025-04-20

Response shape (observed):
    {"five_hour": {"utilization": <0-100>, "resets_at": "<ISO-8601>"},
     "seven_day": {"utilization": ..., "resets_at": ...},
     "limits": [{"kind": "weekly_scoped", "percent": ..., "resets_at": ...,
                 "scope": {"model": {"display_name": "..."}}}, ...], ...}

⚠️  This is NOT a supported integration. The endpoint is undocumented (it backs
Claude Code's `/usage` command) and can change or vanish on any Claude Code
update; automated calls to a non-public endpoint may run against Anthropic's
terms of service. The token is read from the Keychain at runtime and is never
logged or printed. Use at your own risk. See USAGE-OUT-OF-BAND.md.

  runcat-usage-poll.py                fetch + write the card
  runcat-usage-poll.py --debug        also dump the raw response to runcat-usage-raw.json
  runcat-usage-poll.py --from PATH    build from a saved JSON file (no network / no keychain)
  runcat-usage-poll.py --selftest     check the parsing logic

CUSTOMIZING THE CARD: edit build() below — it's the single place rows, title, SF Symbol, and
the menu-bar value are assembled. The payload carries far more than 5h/7d (per-model weekly
caps, pay-as-you-go credits, money spend); every field and a copy-paste recipe are in
USAGE-OUT-OF-BAND.md -> "Payload reference — build any card row you want".

# No token refresh: on 401 the poller skips the update and waits for Claude Code
# to refresh the Keychain token next time you use it. If idle-expiry bites, add
# a refresh: POST https://platform.claude.com/v1/oauth/token with
# grant_type=refresh_token & client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e
# (Claude Code's public OAuth client id).
"""

import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# These three are the usual things to tweak if you're adapting the poller.
OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".claude" / "runcat-usage.json")))
RAW = OUT.with_name("runcat-usage-raw.json")  # where --debug dumps the raw response
KEYCHAIN_ITEM = "Claude Code-credentials"     # login-Keychain item Claude Code stores its token in
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"


def read_token():
    """OAuth access token from the login Keychain. Returned to the caller, never printed."""
    raw = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_ITEM, "-w"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    oauth = json.loads(raw)
    oauth = oauth.get("claudeAiOauth", oauth)  # Claude Code nests creds under this key
    tok = oauth.get("accessToken") or oauth.get("access_token")
    if not tok:
        raise SystemExit("keychain item has no access token")
    return tok


def fetch_usage(token):
    req = urllib.request.Request(USAGE_URL, headers={
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
        "anthropic-version": "2023-06-01",
        "User-Agent": "runcat-usage-poll/1",
    })
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def _to_epoch(resets_at):
    """Accept an ISO-8601 string or a unix-epoch number; return epoch seconds or None."""
    if isinstance(resets_at, (int, float)):
        return float(resets_at)
    if isinstance(resets_at, str):
        try:
            return datetime.fromisoformat(resets_at).timestamp()
        except ValueError:
            return None
    return None


def fmt_reset(resets_at, now):
    """Human 'resets 2h11m' / 'resets 5d3h' / 'resets now' from a reset time, or None."""
    epoch = _to_epoch(resets_at)
    if epoch is None:
        return None
    secs = int(epoch - now)
    if secs <= 0:
        return "resets now"
    mins, _ = divmod(secs, 60)
    hrs, mins = divmod(mins, 60)
    days, hrs = divmod(hrs, 24)
    if days:
        return f"resets {days}d{hrs}h"
    if hrs:
        return f"resets {hrs}h{mins:02d}m"
    return f"resets {mins}m"


def _row(title, pct, resets_at, now):
    """Build one RunCat card row from a 0-100 percentage.

    A row is {"title", "formattedValue", "normalizedValue"}; normalizedValue (0-1) drives the
    gauge fill/color. Returns None if `pct` isn't a number. Reuse this for any payload field
    (see USAGE-OUT-OF-BAND.md for the full field list).
    """
    if not isinstance(pct, (int, float)):
        return None
    reset = fmt_reset(resets_at, now)
    text = f"{pct:g}%" + (f" · {reset}" if reset else "")
    return {"title": title, "formattedValue": text, "normalizedValue": round(pct / 100, 4)}


def find_window(node, name):
    """Recursively locate a dict carrying a utilization figure under a key containing `name`
    (e.g. name="five_hour" / "seven_day" / "seven_day_opus")."""
    if isinstance(node, dict):
        for k, v in node.items():
            if name in k and isinstance(v, dict) and ("utilization" in v or "used_percentage" in v):
                return v
        for v in node.values():
            hit = find_window(v, name)
            if hit:
                return hit
    elif isinstance(node, list):
        for v in node:
            hit = find_window(v, name)
            if hit:
                return hit
    return None


def window_row(title, window, now):
    """Row for a top-level rolling window (five_hour, seven_day, seven_day_opus, …)."""
    if not window:
        return None
    pct = window.get("utilization")
    if pct is None:
        pct = window.get("used_percentage")
    return _row(title, pct, window.get("resets_at"), now)


def scoped_row(data, now):
    """The per-model weekly cap, if the response carries one (limits[].kind == weekly_scoped)."""
    for lim in (data.get("limits") or []):
        if isinstance(lim, dict) and lim.get("kind") == "weekly_scoped":
            model = ((lim.get("scope") or {}).get("model") or {}).get("display_name")
            return _row(f"7d {model}" if model else "7d model", lim.get("percent"), lim.get("resets_at"), now)
    return None


def build(data, now):
    """Assemble the RunCat card from the usage payload — EDIT HERE to customize the card.

    Returns the snapshot dict, or None if nothing is parseable (the caller then leaves the
    existing card untouched instead of blanking it).

    Card knobs:
      metrics         - the rows; each is {"title", "formattedValue", "normalizedValue"} and
                        normalizedValue (0-1) drives the gauge fill/color
      title           - card heading
      symbol          - any SF Symbol name, e.g. "gauge.medium", "bolt.fill"
      metricsBarValue - the single value shown in the collapsed menu bar

    Add rows with the _row() / find_window() helpers. The payload holds far more than the three
    windows below (per-model weekly caps, credits, money spend) — see USAGE-OUT-OF-BAND.md ->
    "Payload reference" for every field and a copy-paste recipe.
    """
    # Choose which windows to show — add, remove, or reorder these rows to taste.
    five = window_row("5h", find_window(data, "five_hour"), now)
    seven = window_row("7d", find_window(data, "seven_day"), now)
    scoped = scoped_row(data, now)          # per-model weekly cap (e.g. "7d Fable"), if the plan has one
    rows = [r for r in [five, seven, scoped] if r]
    # e.g. to add credits, build a row from data["spend"] here — recipe in USAGE-OUT-OF-BAND.md
    if not rows:
        return None
    snap = {
        "title": "Claude Code",             # card heading
        "symbol": "gauge.medium",           # SF Symbol name — swap to taste
        "metrics": rows,
        "lastUpdatedDate": datetime.fromtimestamp(now, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if five:
        # value shown in the collapsed menu bar (strip the reset-countdown suffix)
        snap["metricsBarValue"] = five["formattedValue"].split(" · ")[0]
    return snap


def write_atomic(snap):
    """Write the card to OUT atomically (temp file + rename) so RunCat never reads a half-written file."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(snap, f, ensure_ascii=False)
        os.replace(tmp, OUT)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def selftest():
    now = datetime(2026, 7, 15, 15, 33, 0, tzinfo=timezone.utc).timestamp()  # 4h37m before the 5h reset
    data = {
        "five_hour": {"utilization": 41.0, "resets_at": "2026-07-15T20:10:00.261036+00:00"},
        "seven_day": {"utilization": 29.0, "resets_at": "2026-07-20T19:00:00+00:00"},
        "seven_day_opus": None,  # null siblings must be ignored
        "limits": [
            {"kind": "session", "percent": 41, "resets_at": "2026-07-15T20:10:00+00:00"},
            {"kind": "weekly_scoped", "percent": 40, "resets_at": "2026-07-20T19:00:00+00:00",
             "scope": {"model": {"display_name": "Fable"}}},
        ],
    }
    snap = build(data, now)
    assert [m["title"] for m in snap["metrics"]] == ["5h", "7d", "7d Fable"], snap
    assert snap["metrics"][0]["formattedValue"] == "41% · resets 4h37m", snap["metrics"][0]
    assert snap["metrics"][0]["normalizedValue"] == 0.41
    assert snap["metrics"][2]["formattedValue"] == "40% · resets 5d3h", snap["metrics"][2]
    assert snap["metricsBarValue"] == "41%", snap.get("metricsBarValue")

    assert fmt_reset(now + 45 * 60, now) == "resets 45m"          # numeric epoch still works
    assert fmt_reset("2026-07-15T15:00:00+00:00", now) == "resets now"  # ISO in the past
    assert build({"unrelated": 1}, now) is None                  # nothing parseable -> None
    print("selftest ok")


def main():
    if "--selftest" in sys.argv:
        selftest()
        return
    now = datetime.now(timezone.utc).timestamp()

    src = None
    if "--from" in sys.argv:
        src = sys.argv[sys.argv.index("--from") + 1]

    if src:
        data = json.loads(Path(src).read_text())
    else:
        try:
            data = fetch_usage(read_token())
        except subprocess.CalledProcessError:
            sys.exit("keychain read failed (locked, denied, or item missing) — card left unchanged")
        except urllib.error.HTTPError as e:
            if e.code == 401:
                sys.exit("401 unauthorized: token expired — open Claude Code once to refresh, or add refresh support")
            sys.exit(f"HTTP {e.code} from usage endpoint — card left unchanged")
        except urllib.error.URLError as e:
            sys.exit(f"network error: {e.reason} — card left unchanged")

    if "--debug" in sys.argv and not src:
        RAW.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        print(f"raw response saved to {RAW}")

    snap = build(data, now)
    if snap is None:
        hint = "" if ("--debug" in sys.argv or src) else f"; re-run with --debug to dump the shape to {RAW}"
        sys.exit("no rate-limit windows found in response — card left unchanged" + hint)
    write_atomic(snap)
    print("card updated: " + " · ".join(m["formattedValue"] for m in snap["metrics"]))


if __name__ == "__main__":
    main()
