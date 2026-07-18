#!/usr/bin/env python3
"""RunCat Neo custom metrics producer for Codex lifecycle hooks."""

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".codex" / "runcat-usage.json")))


def percentage_metric(title, used_percentage):
    if not isinstance(used_percentage, (int, float)):
        return None
    clamped_percentage = max(0.0, min(float(used_percentage), 100.0))
    normalized_value = clamped_percentage / 100
    formatted_percentage = f"{clamped_percentage:.1f}".rstrip("0").rstrip(".")
    return {
        "title": title,
        "formattedValue": f"{formatted_percentage}%",
        "normalizedValue": round(normalized_value, 4),
    }


def window_title(window_minutes):
    if not isinstance(window_minutes, (int, float)):
        return None
    if window_minutes % 1440 == 0:
        return f"{window_minutes / 1440:g}d"
    if window_minutes % 60 == 0:
        return f"{window_minutes / 60:g}h"
    return f"{window_minutes:g}m"


def latest_token_count(transcript_path):
    if not transcript_path:
        return None
    latest = None
    try:
        with Path(transcript_path).open(encoding="utf-8") as transcript:
            for line in transcript:
                try:
                    event = json.loads(line)
                except (json.JSONDecodeError, TypeError):
                    continue
                payload = event.get("payload") or {}
                if payload.get("type") == "token_count":
                    latest = payload
    except OSError:
        return None
    return latest


def context_metric(token_count):
    info = (token_count or {}).get("info") or {}
    used_tokens = (info.get("last_token_usage") or {}).get("total_tokens")
    context_window = info.get("model_context_window")
    if not isinstance(used_tokens, (int, float)) or not isinstance(context_window, (int, float)):
        return None
    if context_window <= 0:
        return None
    return percentage_metric("Context", used_tokens / context_window * 100)


def rate_limit_metrics(token_count):
    rate_limits = (token_count or {}).get("rate_limits") or {}
    metrics = []
    titles = set()
    for key in ("primary", "secondary"):
        limit = rate_limits.get(key) or {}
        title = window_title(limit.get("window_minutes"))
        metric = percentage_metric(title, limit.get("used_percent")) if title else None
        if metric is not None and title not in titles:
            metrics.append(metric)
            titles.add(title)
    return metrics


def write_snapshot(hook_input):
    model = hook_input.get("model")
    if isinstance(model, str):
        model = model.strip()
    else:
        model = ""
    if not model:
        model = "Codex"
    token_count = latest_token_count(hook_input.get("transcript_path"))
    rate_metrics = rate_limit_metrics(token_count)
    if OUT.exists() and (token_count is None or not rate_metrics):
        return
    context = context_metric(token_count)
    metrics = [{"title": "Model", "formattedValue": model}]
    if context is not None:
        metrics.append(context)
    metrics.extend(rate_metrics)
    snapshot = {
        "title": "Codex",
        "symbol": "camera.aperture",
        "metrics": metrics,
        "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if context is not None:
        snapshot["metricsBarValue"] = context["formattedValue"]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_path = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as output:
            json.dump(snapshot, output, ensure_ascii=False)
        os.replace(temporary_path, OUT)
    except Exception:
        try:
            os.unlink(temporary_path)
        except OSError:
            pass
        raise


def main():
    try:
        hook_input = json.load(sys.stdin)
        if not isinstance(hook_input, dict):
            hook_input = {}
        write_snapshot(hook_input)
    except Exception as error:
        print(f"RunCat Codex hook: {error}", file=sys.stderr)
    print("{}")


if __name__ == "__main__":
    main()
