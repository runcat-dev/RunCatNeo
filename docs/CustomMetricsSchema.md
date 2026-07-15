# Custom Metrics JSON Schema

RunCat Neo can watch any local JSON file you point it at and render it as a card on the dashboard. This document describes the file format the JSON must follow and how each field is displayed.

## Overview

You decide what to track (Claude Code usage, GPU temperature, GitHub contributions, remaining reminders, anything else). You write a small script or program that keeps a JSON file on disk up to date. RunCat watches the file with a `DispatchSource` file-system event source and updates the card the moment the file changes. RunCat itself never polls the file and never makes network calls — whether your data comes from the network is entirely up to your script.

To add a source: open RunCat's settings, go to **Metrics** → **Custom Metrics**, and click **Add Custom Metrics Source**, then pick the JSON file. The file is bookmarked with a security-scoped bookmark so the access survives sandbox restarts.

## Schema

### Example

A valid file might look like this:

```json
{
  "title": "Claude Code",
  "symbol": "staroflife",
  "metricsBarValue": "5.4%",
  "metrics": [
    { "title": "Model",   "formattedValue": "Opus 4.7" },
    { "title": "Context", "formattedValue": "5.4%",  "normalizedValue": 0.054 },
    { "title": "5h",      "formattedValue": "16.4%", "normalizedValue": 0.164 },
    { "title": "7d",      "formattedValue": "1.0%",  "normalizedValue": 0.01  }
  ],
  "lastUpdatedDate": "2026-06-05T04:50:40Z"
}
```

The values above are illustrative — `title`, `symbol`, and the metric labels are all your choice; pick whatever makes sense for what you're tracking. The `Model` row omits `normalizedValue`, so RunCat renders just the text with no bar; the other three rows include it, so a bar is drawn under the text.

### Top level

| Field             | Type           | Required | Description |
|-------------------|----------------|----------|-------------|
| `title`           | string         | yes      | Card header text. |
| `symbol`          | string         | no       | [SF Symbol](https://developer.apple.com/sf-symbols/) identifier shown next to the title. Defaults to `chart.bar.horizontal.page.fill`. |
| `metricsBarValue` | string         | no       | Short text shown in the Metrics Bar (the dedicated menu-bar item) next to the source's symbol. Displayed verbatim; keep it short — the bar caps the label width and truncates longer strings. Each source is hidden in the bar by default: click the Metrics Bar and flip the source's toggle to show it. When the source is shown but this field is omitted, the bar renders `---`. |
| `metrics`         | array<Metric\> | yes      | Rows displayed inside the card. Empty array is allowed. |
| `lastUpdatedDate` | string         | yes      | ISO 8601 timestamp (e.g. `"2026-06-05T04:50:40Z"`) of when the producer wrote this file. Shown as a relative time (`"3 min ago"`) at the bottom of the card; updates automatically. |

### Metric

| Field             | Type    | Required | Description |
|-------------------|---------|----------|-------------|
| `title`           | string  | yes      | Row label. The row is rendered as `title: formattedValue`. |
| `formattedValue`  | string  | yes      | The completed display string. Include any units, currency symbols, or suffixes (e.g. `"5.4%"`, `"$3.21"`, `"42 days"`). |
| `normalizedValue` | number  | no       | A value between 0 and 1. When present, a horizontal progress bar is drawn under the row. When omitted, only the `title: formattedValue` text is shown. |

## Display rules

- Producer-side formatting is intentional. RunCat does **not** apply units, percent signs, or rounding — whatever you put in `formattedValue` is shown verbatim.
- `normalizedValue` is clamped to `[0, 1]` before the bar is drawn.
- The bar is drawn in the accent color regardless of the value — it does not change color as the value grows. Encode any severity you want to convey in `formattedValue` itself.
- If `metrics` is empty, the card shows only its title and the last-updated line.
- `metricsBarValue` is rendered verbatim in the Metrics Bar with a monospaced digit font, prefixed by the source's `symbol`.

## Failure behavior

If the file becomes unreadable (deleted, moved, permission revoked) or contains invalid JSON, the previous snapshot stays on the dashboard but is flagged as failed:

- **Dashboard**: the card's footer shows `Last updated: Failed` in red instead of the relative time. Once the file becomes readable again, the timestamp returns on the next successful read.
- **Settings → Metrics → Custom Metrics**: a yellow `⚠︎ Error Detected` label appears next to the source's file path.
- **Metrics Bar**: the symbol stays and the value is replaced with `---` until the file is readable again.

Recovery is automatic — there is nothing to "reset", and fixing the producer is enough:

- If the file was deleted or renamed, RunCat re-opens it, retrying every 5 seconds while it stays unreachable. This is also what makes the atomic `mv` pattern below work.
- If the file is still there but held invalid JSON, the watch stays alive and the card recovers on your next write.

## Constraints

- Use strict JSON. Comments (`//`, `/* */`) and trailing commas are **not** supported.
- Write atomically: write to a temporary file in the same directory and `mv` it into place. This avoids RunCat reading half-written content. The bundled samples do this.
- Keep file size modest (well under a megabyte). RunCat re-decodes the file on every change.

## Update frequency

There is no minimum cadence. Update the file every second, or only when something interesting changes — RunCat reacts to filesystem events. The watch stream keeps only the newest pending event, so a burst of writes collapses into a single re-read instead of queueing up.

## Examples

See `docs/samples/` for working scripts:

- `docs/samples/claude-code/` — Claude Code statusLine integration that writes context-window and cost rows.
- `docs/samples/codex/` — Codex lifecycle hook that writes model, context-window, and rate-limit rows.
- `docs/samples/bitcoin/` — launchd-scheduled shell script that shows the current Bitcoin price in USD via the CoinGecko public API.

Want to share an integration? Open a PR adding a sibling directory under `docs/samples/`.
