# GPU Sample

A Python script that shows Apple Silicon GPU utilization and VRAM usage on RunCat Neo's Custom Metrics card and in the Metrics Bar. It reads the `AGXAccelerator` node of the IOKit registry with `ioreg`, so it needs no `sudo`, no network access, and no third party tools. The snapshot is written to `~/.runcat/gpu.json`, and a `launchd` LaunchAgent keeps the script running so the card refreshes every 2 seconds.

```text
ioreg (IOKit registry) -> runcat-gpu.py -> gpu.json -> RunCat Neo
```

The Bitcoin sample schedules a producer that exits after each run (`StartInterval`). GPU load changes far too quickly for that, so this sample demonstrates the other shape: a long running producer kept alive by `launchd` (`KeepAlive`) that rewrites the snapshot on its own timer.

## Requirements

- Apple Silicon (M series). Intel Macs expose different accelerator classes and are not supported by this sample.
- `python3`, which ships with the Xcode Command Line Tools.

## Setup

1. Copy the script and make it executable:
   ```bash
   mkdir -p ~/.runcat
   cp runcat-gpu.py ~/.runcat/runcat-gpu.py
   chmod +x ~/.runcat/runcat-gpu.py
   ```
2. Run it once by hand and check the output:
   ```bash
   ~/.runcat/runcat-gpu.py && cat ~/.runcat/gpu.json
   ```
3. Register the LaunchAgent so it keeps updating:
   ```bash
   cp dev.runcat.gpu-sample.plist ~/Library/LaunchAgents/dev.runcat.gpu-sample.plist
   ```
   Open the copied plist and replace `/Users/YOU` with your home path, then:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.runcat.gpu-sample.plist
   ```
4. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add Custom Metrics Source**, and choose `~/.runcat/gpu.json`. The folder is hidden in the open panel, so press `⌘⇧.` or `⌘⇧G` and type the path. The card appears on the dashboard immediately.
5. Optional: click the Metrics Bar and flip the source's toggle to show GPU utilization (`metricsBarValue`, for example `24%`) directly in the menu bar.

To stop updating, unload the agent:

```bash
launchctl bootout gui/$(id -u)/dev.runcat.gpu-sample
```

## What the rows mean

`ioreg -r -d 1 -w 0 -c AGXAccelerator` reports a `PerformanceStatistics` dictionary. The sample surfaces five of its entries:

| Row | Source key | Meaning |
|-----|-----------|---------|
| Utilization | `Device Utilization %` | Overall share of time the GPU was busy |
| Renderer | `Renderer Utilization %` | Share spent in the render stage |
| Tiler | `Tiler Utilization %` | Share spent in the tiling stage |
| VRAM in use | `In use system memory` | Memory currently held by the GPU, normalized against `hw.memsize` |
| VRAM allocated | `Alloc system memory` | Memory reserved for the GPU |

Apple Silicon uses unified memory, so the VRAM rows are drawn from the same pool the CPU uses. That is why "VRAM in use" is normalized against total system memory rather than a dedicated card's capacity.

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). `PerformanceStatistics` carries more entries than the five shown here, so adding a row is a one line edit in `build_snapshot`. Inspect what your machine reports with:

```bash
ioreg -r -d 1 -w 0 -c AGXAccelerator | grep PerformanceStatistics
```

`RUNCAT_OUT_FILE` overrides where the snapshot is written (default: `~/.runcat/gpu.json`). The `--watch` argument in the plist controls the update cadence. Without `--watch` the script writes one snapshot and exits, which lets you schedule it with `StartInterval` instead if you prefer the Bitcoin sample's shape.

## Troubleshooting

- File never appears → run the script by hand (step 2). Errors print to stderr.
- `no AGXAccelerator PerformanceStatistics found` → the machine is not Apple Silicon, or the GPU driver exposes no statistics node.
- File exists but stops updating → check the agent is loaded: `launchctl print gui/$(id -u)/dev.runcat.gpu-sample`.
- Card footer shows **Last updated: Failed** in red → the file became unreadable or contains invalid JSON. Re-run the script by hand (step 2); the card recovers on the next successful read.
