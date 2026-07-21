# Claude Rate Limits Sample

A small Python script that shows how much of your Claude subscription's rate-limit windows is **left** — the same 5-hour and 7-day gauges as Claude Code's `/usage` screen — on RunCat Neo's Custom Metrics card and in the Metrics Bar. It asks Anthropic's OAuth usage endpoint with the credentials Claude Code already maintains, writes a Custom Metrics JSON snapshot to `~/.claude/runcat-claude-limits.json`, and a `launchd` LaunchAgent re-runs it every 5 minutes.

```text
Keychain ("Claude Code-credentials") → update-claude-rate-limits.py → api.anthropic.com/api/oauth/usage → runcat-claude-limits.json → RunCat Neo
```

## How this differs from the other Claude samples

The [`claude-code`](../claude-code/) statusLine sample also shows rate limits, but only updates while Claude Code is running a session — and it shows **used** percentages. This sample runs on a `launchd` schedule like the [`bitcoin`](../bitcoin/) sample, so the card stays current even when Claude Code is idle, and it shows the **remaining** percentage with a reset time for the 5-hour window. Model-scoped weekly limits (e.g. a separate Opus gauge) get their own `7d <Model>` row when your plan has one. The two Claude samples are complementary; run both if you like.

The script reuses the OAuth access token Claude Code stores in the macOS Keychain (falling back to `~/.claude/.credentials.json`). It sends the token only to `api.anthropic.com`. If it finds the token expired, it runs `claude -p "hi"` once to make Claude Code rotate it, then re-reads and retries — it never rewrites the credentials itself. Note that the usage endpoint is not officially documented by Anthropic, so its response shape may change without notice.

## Setup

1. You need Claude Code installed and signed in with a subscription (Pro/Max/Team) — the script reads its stored credentials.
2. Copy the script and make it executable:
   ```bash
   cp update-claude-rate-limits.py ~/.claude/update-claude-rate-limits.py
   chmod +x ~/.claude/update-claude-rate-limits.py
   ```
3. Run it once by hand and check the output:
   ```bash
   ~/.claude/update-claude-rate-limits.py && python3 -m json.tool ~/.claude/runcat-claude-limits.json
   ```
   macOS may show a Keychain permission dialog for `security` — click **Always Allow** so the scheduled runs don't stall on it.
4. Register the LaunchAgent so it keeps running every 5 minutes:
   ```bash
   cp dev.runcat.claude-rate-limits.plist ~/Library/LaunchAgents/dev.runcat.claude-rate-limits.plist
   ```
   Open the copied plist and replace `/Users/YOU` with your home path, then:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.runcat.claude-rate-limits.plist
   ```
5. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add JSON Source**, and choose `~/.claude/runcat-claude-limits.json`. The folder is hidden in the open panel — press `⌘⇧.` or `⌘⇧G` and type the path. The card appears on the dashboard immediately.
6. Optional: click the Metrics Bar and flip the source's toggle to show the 5-hour remaining percentage (`metricsBarValue`, e.g. `74%`) directly in the menu bar.

To stop updating, unload the agent:

```bash
launchctl bootout gui/$(id -u)/dev.runcat.claude-rate-limits
```

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). Edit the `build_snapshot(...)` block to add rows, change the card title, or pick a different SF Symbol.

Environment overrides:

| Variable             | Default                               | Description |
|----------------------|---------------------------------------|-------------|
| `RUNCAT_OUT_FILE`    | `~/.claude/runcat-claude-limits.json` | Where the snapshot is written. |
| `RUNCAT_LIMITS_SHOW` | `remaining`                           | `remaining` shows what is left (`74% left`); `used` shows consumption (`26% used`). The bars follow the same choice. |
| `RUNCAT_CLAUDE_CLI`  | auto-detected                         | Path to the `claude` binary used to refresh an expired token. Set this if the script can't find `claude` on its own (see Troubleshooting). |

Set them in the plist with an `EnvironmentVariables` dict. `StartInterval` controls the update cadence; the endpoint reports window utilization that moves slowly, so a few minutes is plenty — please don't hammer it.

## Troubleshooting

- File never appears → run the script by hand (step 3); errors are printed to stderr. It needs Python 3, which ships with the Xcode Command Line Tools (`xcode-select --install`).
- `access token has expired and automatic refresh ... didn't recover it` → the script already tried running `claude -p "hi"` itself and the token was still expired afterward. Under `launchd` this usually means the `claude` CLI isn't on the job's minimal `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`) — set `RUNCAT_CLAUDE_CLI` to its full path (check with `which claude`) in the plist's `EnvironmentVariables`. Otherwise, sign in with `claude login` and try again.
- `no credentials found` → sign in to Claude Code first, or check the Keychain item `Claude Code-credentials` exists in Keychain Access.
- Card stops updating under `launchd` but works by hand → the Keychain dialog was dismissed instead of **Always Allow**-ed. Re-run step 3.
- Agent status → `launchctl print gui/$(id -u)/dev.runcat.claude-rate-limits`.
- Card footer shows **Last updated: Failed** in red → the file became unreadable or contains invalid JSON. Re-run the script by hand (step 3); the card recovers on the next successful read.
