#!/usr/bin/env python3
"""
RunCat Neo - Apple Silicon GPU sample.

Reads GPU statistics from the IOKit registry (no sudo, no network) and writes
~/.runcat/gpu.json shaped like:

    {
      "title": "GPU",
      "symbol": "memorychip.fill",
      "metricsBarValue": "24%",
      "metrics": [
        {"title": "Utilization",    "formattedValue": "24%",     "normalizedValue": 0.24},
        {"title": "Renderer",       "formattedValue": "23%",     "normalizedValue": 0.23},
        {"title": "Tiler",          "formattedValue": "24%",     "normalizedValue": 0.24},
        {"title": "VRAM in use",    "formattedValue": "0.46 GB", "normalizedValue": 0.0285},
        {"title": "VRAM allocated", "formattedValue": "2.25 GB"}
      ],
      "lastUpdatedDate": "2026-08-12T18:25:08Z"
    }

Usage:
    runcat-gpu.py             write one snapshot and exit
    runcat-gpu.py --watch 2   rewrite the snapshot every 2 seconds
"""

import argparse
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(os.environ.get("RUNCAT_OUT_FILE", str(Path.home() / ".runcat" / "gpu.json")))


def gpu_statistics():
    """Return PerformanceStatistics from the first AGXAccelerator node."""
    raw = subprocess.run(
        ["ioreg", "-r", "-d", "1", "-w", "0", "-c", "AGXAccelerator", "-a"],
        capture_output=True,
        check=True,
    ).stdout
    for node in plistlib.loads(raw) if raw else []:
        statistics = node.get("PerformanceStatistics")
        if statistics:
            return statistics
    raise RuntimeError("no AGXAccelerator PerformanceStatistics found")


def total_memory():
    output = subprocess.run(
        ["sysctl", "-n", "hw.memsize"], capture_output=True, text=True, check=True
    ).stdout
    return int(output.strip())


def percent(title, value):
    return {
        "title": title,
        "formattedValue": f"{value:g}%",
        "normalizedValue": round(value / 100, 4),
    }


def gigabytes(title, value, total=None):
    metric = {"title": title, "formattedValue": f"{value / (1024 ** 3):.2f} GB"}
    if total:
        metric["normalizedValue"] = round(value / total, 4)
    return metric


def build_snapshot():
    statistics = gpu_statistics()
    utilization = int(statistics.get("Device Utilization %", 0))
    total = total_memory()

    return {
        "title": "GPU",
        "symbol": "memorychip.fill",
        "metricsBarValue": f"{utilization:g}%",
        "metrics": [
            percent("Utilization", utilization),
            percent("Renderer", int(statistics.get("Renderer Utilization %", 0))),
            percent("Tiler", int(statistics.get("Tiler Utilization %", 0))),
            gigabytes("VRAM in use", int(statistics.get("In use system memory", 0)), total),
            gigabytes("VRAM allocated", int(statistics.get("Alloc system memory", 0))),
        ],
        "lastUpdatedDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def write(snapshot):
    """Write via a temporary file so RunCat Neo never reads a partial snapshot."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".runcat-", dir=str(OUT.parent))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, ensure_ascii=False)
    os.replace(tmp, OUT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--watch", type=float, metavar="SECONDS")
    arguments = parser.parse_args()

    while True:
        try:
            write(build_snapshot())
        except Exception as error:
            print(f"runcat-gpu: {error}", file=sys.stderr)
            if not arguments.watch:
                return 1
        if not arguments.watch:
            return 0
        time.sleep(arguments.watch)


if __name__ == "__main__":
    sys.exit(main())
