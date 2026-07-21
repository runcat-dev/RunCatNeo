#!/usr/bin/env python3
"""
RunCat Neo — Claude Code statusLine sample.

Writes ~/.claude/runcat-usage.json shaped like:

    {
      "title": "Claude Code",
      "symbol": "staroflife",
      "metricsBarValue": "67%",
      "metrics": [
        {"title": "Model",   "formattedValue": "Opus 4.7"},
        {"title": "Context", "formattedValue": "67%", "normalizedValue": 0.67},
        {"title": "5h",      "formattedValue": "3% (~14:30)",  "normalizedValue": 0.03},
        {"title": "7d",      "formattedValue": "3% (~7/22 03:00)",  "normalizedValue": 0.03}
      ],
      "lastUpdatedDate": "2026-06-07T05:55:36Z"
    }
"""

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".claude" / "runcat-usage.json")))


def pct(title, value, reset=None):
    if value is None:
        return None
    formatted = f"{value:g}%" + (f" ({reset})" if reset else "")
    return {"title": title, "formattedValue": formatted, "normalizedValue": round(value / 100, 4)}


def format_reset(epoch_seconds):
    if epoch_seconds is None:
        return None
    now = datetime.now().astimezone()
    reset = datetime.fromtimestamp(epoch_seconds).astimezone()
    hm = reset.strftime("%H:%M")
    if reset.date() == now.date():
        return f"~{hm}"
    return f"~{reset.month}/{reset.day} {hm}"


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
five_reset = format_reset((rate_limits.get("five_hour") or {}).get("resets_at"))
seven_reset = format_reset((rate_limits.get("seven_day") or {}).get("resets_at"))

snapshot = {
    "title": "Claude Code",
    "symbol": "staroflife",
    "metrics": [m for m in [
        {"title": "Model", "formattedValue": model},
        pct("Context", ctx),
        pct("5h", five, five_reset),
        pct("7d", seven, seven_reset),
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
