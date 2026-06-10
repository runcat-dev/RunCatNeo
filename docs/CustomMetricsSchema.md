# Custom Metrics JSON Schema

RunCat Neo can watch any local JSON file you point it at and render it as a card on the dashboard. This document describes the file format the JSON must follow and how each field is displayed.

## Overview

You decide what to track (Claude Code usage, GPU temperature, GitHub contributions, remaining reminders, anything else). You write a small script or program that keeps a JSON file on disk up to date. RunCat watches the file with FSEvents/DispatchSource and updates the card the moment the file changes — no polling, no network calls.

To add a source: open RunCat's settings, go to **Custom Metrics**, and click **Add JSON Source**, then pick the JSON file. The file is bookmarked with a security-scoped bookmark so the access survives sandbox restarts.

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

The values above are illustrative — `title`, `symbol`, and the metric labels are all your choice; pick whatever makes sense for what you're tracking. The `Model` row omits `normalizedValue`, so RunCat renders just the text on the right with no bar; the other three rows include it, so a bar is drawn alongside the formatted text.

### Top level

| Field             | Type           | Required | Description |
|-------------------|----------------|----------|-------------|
| `title`           | string         | yes      | Card header text. |
| `symbol`          | string         | no       | SF Symbol identifier shown next to the title. Defaults to `chart.bar.horizontal.page.fill`. |
| `metricsBarValue` | string         | no       | Short text shown in the Metrics Bar (the dedicated menu-bar item) next to the source's symbol. Displayed verbatim; keep it short — the bar caps the label width and truncates longer strings. Each source is hidden in the bar by default: click the Metrics Bar and flip the source's toggle to show it. When the source is shown but this field is omitted, the bar renders `---`. |
| `metrics`         | array<Metric\> | yes      | Rows displayed inside the card. Empty array is allowed. |
| `lastUpdatedDate` | string         | yes      | ISO 8601 timestamp (e.g. `"2026-06-05T04:50:40Z"`) of when the producer wrote this file. Shown as a relative time (`"3 min ago"`) at the bottom of the card; updates automatically. |

### Metric

| Field             | Type    | Required | Description |
|-------------------|---------|----------|-------------|
| `title`           | string  | yes      | Row label shown on the left. |
| `formattedValue`  | string  | yes      | The completed display string. Include any units, currency symbols, or suffixes (e.g. `"5.4%"`, `"$3.21"`, `"42 days"`). |
| `normalizedValue` | number  | no       | A value between 0 and 1. When present, a horizontal progress bar is drawn whose tint color reflects the value: `< 0.5` green, `< 0.7` yellow, `< 0.9` orange, otherwise red. When omitted, only `formattedValue` is shown. |

## Display rules

- Producer-side formatting is intentional. RunCat does **not** apply units, percent signs, or rounding — whatever you put in `formattedValue` is shown verbatim.
- `normalizedValue` is clamped to `[0, 1]` before the bar is drawn.
- The card uses a monospaced digit font for `formattedValue` so values stay aligned across updates.
- If `metrics` is empty, the card shows a faint "no metrics" placeholder until your file contains rows.
- `metricsBarValue` is rendered verbatim in the Metrics Bar with a monospaced digit font, prefixed by the source's `symbol`.

## Failure behavior

If the file becomes unreadable (deleted, moved, permission revoked) or contains invalid JSON, the previous snapshot stays on the dashboard but is flagged as stale:

- **Dashboard**: the card's footer shows a red `⚠ missing` badge next to the `lastUpdatedDate`. Once the file becomes readable again, the badge clears on the next successful read.
- **Settings → Metrics → Custom Metrics**: the row's title and file name turn red with a `missing` badge next to the title.
- **Metrics Bar**: the symbol stays and the value is replaced with `---` until the file is readable again.

RunCat keeps retrying every few seconds until the file is reachable again — there is nothing to "reset". Fixing the producer (re-writing the file) is enough.

## Constraints

- Use strict JSON. Comments (`//`, `/* */`) and trailing commas are **not** supported.
- Write atomically: write to a temporary file in the same directory and `mv` it into place. This avoids RunCat reading half-written content. The bundled samples do this.
- Keep file size modest (well under a megabyte). RunCat re-decodes the file on every change.

## Update frequency

There is no minimum cadence. Update the file every second, or only when something interesting changes — RunCat reacts to filesystem events. A debounce on the consumer side prevents bursts from saturating the dashboard.

## Examples

See `docs/samples/` for working scripts:

- `docs/samples/claude-code/` — Claude Code statusLine integration that writes context-window and cost rows.

Want to share an integration? Open a PR adding a sibling directory under `docs/samples/`.
