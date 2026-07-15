#!/usr/bin/env python3
"""
RunCat Neo — Claude Code statusLine sample.

Writes ~/.claude/runcat-usage.json shaped like:

    {
      "title": "Claude Code",
      "symbol": "circle.lefthalf.filled",
      "metricsBarValue": "67%",
      "metrics": [
        {"title": "Model",   "formattedValue": "Opus 4.7"},
        {"title": "Context", "formattedValue": "67%", "normalizedValue": 0.67},
        {"title": "5h",      "formattedValue": "3%",  "normalizedValue": 0.03},
        {"title": "7d",      "formattedValue": "3%",  "normalizedValue": 0.03}
      ],
      "lastUpdatedDate": "2026-06-07T05:55:36Z"
    }

The card icon reflects how close you are to your plan limit: an empty circle
fills up as the 5h / 7d usage rises, and becomes a warning triangle once you
are near the cap. RunCat renders the menu-bar icon monochrome, so the level is
conveyed by SHAPE rather than colour.
"""

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".claude" / "runcat-usage.json")))


def pct(title, value):
    if value is None:
        return None
    return {"title": title, "formattedValue": f"{value:g}%", "normalizedValue": round(value / 100, 4)}


def limit_symbol(value):
    """SF Symbol whose shape reflects how full the plan limit is."""
    if value is None:
        return "staroflife"
    if value >= 85:
        return "exclamationmark.triangle.fill"
    if value >= 66:
        return "circle.fill"
    if value >= 33:
        return "circle.lefthalf.filled"
    return "circle"


try:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        payload = {}
except Exception:
    payload = {}

model = (payload.get("model") or {}).get("display_name") or "Claude Code"
ctx = (payload.get("context_window") or {}).get("used_percentage")
rate_limits = payload.get("rate_limits") or {}
five = (rate_limits.get("five_hour") or {}).get("used_percentage")
seven = (rate_limits.get("seven_day") or {}).get("used_percentage")

# icon warns as you approach whichever plan limit is closest to its cap
limit_level = max([v for v in (five, seven) if v is not None], default=None)

snapshot = {
    "title": "Claude Code",
    "symbol": limit_symbol(limit_level),
    "metrics": [m for m in [
        {"title": "Model", "formattedValue": model},
        pct("Context", ctx),
        pct("5h", five),
        pct("7d", seven),
    ] if m is not None],
    "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if ctx is not None:
    snapshot["metricsBarValue"] = f"{ctx:g}%"

OUT.parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(snapshot, f, ensure_ascii=False)
os.replace(tmp, OUT)

print(model)
