# OpenCode Go Usage Sample

A shell script that shows your OpenCode Go subscription usage (rolling / weekly / monthly limits) on RunCat Neo's Custom Metrics card and in the Metrics Bar. It scrapes the usage page at `opencode.ai/workspace/:id/go` through the [opencode-go-usage](https://git.sr.ht/~hrbrmstr/opencode-go-usage) CLI, writes a Custom Metrics JSON snapshot to `~/.runcat/opencode-go.json`, and a `launchd` LaunchAgent re-runs it every 10 minutes.

```text
opencode.ai (web scrape) → opencode-go-usage CLI → update-opencode-go.sh → opencode-go.json → RunCat Neo
```

Unlike the Claude Code / Codex samples, nothing triggers the script for you — this uses the same `launchd` scheduling pattern as the Bitcoin sample.

## Setup

### 1. Get your workspace ID

Open `https://opencode.ai/auth` in your browser. The URL will redirect to `https://opencode.ai/workspace/wrk_XXXXXXXXXX/go`. Copy the `wrk_` part from the URL.

### 2. Get your session cookie

Still in your browser, open DevTools and copy the `auth` cookie value for `opencode.ai`:

- **Chrome / Arc / Brave**: `Application` → `Cookies` → `opencode.ai` → `auth`
- **Firefox**: `Storage` → `Cookies` → `opencode.ai` → `auth`
- **Safari**: `Settings` → `Privacy` → `Manage Website Data` → `opencode.ai`

```bash
mkdir -p ~/.config/opencode-go-usage
echo "Fe26.2_YOUR_COOKIE_VALUE_HERE..." > ~/.config/opencode-go-usage/session
chmod 600 ~/.config/opencode-go-usage/session
```

### 3. Build the CLI

```bash
git clone https://git.sr.ht/~hrbrmstr/opencode-go-usage /tmp/opencode-go-usage
cd /tmp/opencode-go-usage
go build -o opencode-go-usage .
mkdir -p ~/.runcat/bin
cp opencode-go-usage ~/.runcat/bin/opencode-go-usage
chmod +x ~/.runcat/bin/opencode-go-usage
```

### 4. Install the script

```bash
cp update-opencode-go.sh ~/.runcat/update-opencode-go.sh
chmod +x ~/.runcat/update-opencode-go.sh
```

### 5. Test it

```bash
OPENCODE_WORKSPACE=wrk_XXXXXXXXXX ~/.runcat/update-opencode-go.sh && cat ~/.runcat/opencode-go.json | python3 -m json.tool
```

### 6. Register the LaunchAgent

```bash
cp dev.runcat.opencode-go-sample.plist ~/Library/LaunchAgents/dev.runcat.opencode-go.plist
```

Open the copied plist and replace both placeholders:
- `/Users/YOU` → your home path (e.g. `/Users/jm`)
- `wrk_YOUR_WORKSPACE_ID` → your workspace ID from step 1

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.runcat.opencode-go.plist
```

### 7. Add to RunCat Neo

Open **Settings → Metrics → Custom Metrics**, click **Add JSON Source**, and choose `~/.runcat/opencode-go.json`. The folder is hidden in the open panel — press `⌘⇧.` or `⌘⇧G` and type the path.

### 8. Optional: show in the Metrics Bar

Click the Metrics Bar and flip the source's toggle to show the rolling usage (`metricsBarValue`, e.g. `38%`) directly in the menu bar.

## What it displays

| Row | Description |
|---|---|
| **Rolling (5h)** | Current 5-hour window usage with progress bar |
| **Weekly** | Current weekly window usage with progress bar |
| **Monthly** | Current monthly window usage with progress bar |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `OPENCODE_WORKSPACE` | *(required)* | Your workspace ID (`wrk_...`) |
| `RUNCAT_OUT_FILE` | `~/.runcat/opencode-go.json` | JSON snapshot path |
| `OPENCODE_COOKIE_FILE` | `~/.config/opencode-go-usage/session` | Session cookie file |
| `OPENCODE_GO_USAGE_BIN` | `~/.runcat/bin/opencode-go-usage` | CLI binary path |

## Customizing

| What | How |
|---|---|
| Card title / symbol / rows | Edit the `cat > "$temporaryFile"` block in the script |
| Update cadence | Change `StartInterval` in the plist (seconds; 5-10 min recommended) |
| Workspace ID | Set `OPENCODE_WORKSPACE` env var or edit the plist's `EnvironmentVariables` |

## Stopping

```bash
launchctl bootout gui/$(id -u)/dev.runcat.opencode-go
```

## Troubleshooting

- **File never appears** → test step 5. The CLI prints errors to stderr.
- **`Failed to fetch`** → session cookie may be expired. Re-copy from browser (step 2).
- **`jq: command not found`** → `brew install jq`.
- **Card shows `Last updated: Failed`** → file became unreadable or contains invalid JSON. Re-run step 5; the card recovers on the next successful read.
- **File exists but stops updating** → `launchctl print gui/$(id -u)/dev.runcat.opencode-go`.
- **Workspace ID wrong** → the default `wrk_01KT241XYZ...` inside the CLI is not yours. Always set `OPENCODE_WORKSPACE`.

## Output example

```json
{
  "title": "OpenCode Go",
  "symbol": "rectangle.ratio.3.to.4",
  "metricsBarValue": "38%",
  "metrics": [
    { "title": "Rolling (5h)", "formattedValue": "38%",  "normalizedValue": 0.38 },
    { "title": "Weekly",      "formattedValue": "50%",  "normalizedValue": 0.50 },
    { "title": "Monthly",     "formattedValue": "28%",  "normalizedValue": 0.28 }
  ],
  "lastUpdatedDate": "2026-07-17T15:02:00+09:00"
}
```
