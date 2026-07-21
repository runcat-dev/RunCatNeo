# GitHub Copilot Rate Limits Sample

A small Python script that shows how much of your GitHub Copilot plan's quotas is **left** — premium requests (the monthly allowance consumed by premium models), plus chat and completions when your plan meters them — on RunCat Neo's Custom Metrics card and in the Metrics Bar. It asks GitHub's Copilot user endpoint with the token the `gh` CLI is signed in with, writes a Custom Metrics JSON snapshot to `~/.copilot/runcat-copilot-limits.json`, and a `launchd` LaunchAgent re-runs it every 5 minutes.

```text
gh auth token → update-copilot-rate-limits.py → api.github.com/copilot_internal/user → runcat-copilot-limits.json → RunCat Neo
```

The card shows one row per quota: **Premium** gets a percentage with a bar and a **Resets** row (quotas reset monthly, e.g. `Aug 1`); **Chat** and **Completions** show `Unlimited` on paid plans, or their own percentages on plans that meter them. If you've gone past the premium allowance with overage billing enabled, a `Premium overage` row appears with the extra request count. This is the same structure as the [`claude-rate-limits`](../claude-rate-limits/) sample — run both for side-by-side Claude and Copilot gauges.

The script sends the token only to `api.github.com` and never modifies your `gh` credentials. Note that `/copilot_internal/user` is the endpoint Copilot's own clients use but is not officially documented, so its response shape may change without notice.

## Setup

1. You need the [`gh` CLI](https://cli.github.com) installed and signed in (`gh auth login`) with an account that has a Copilot plan.
2. Copy the script and make it executable:
   ```bash
   cp update-copilot-rate-limits.py ~/.copilot/update-copilot-rate-limits.py
   chmod +x ~/.copilot/update-copilot-rate-limits.py
   ```
3. Run it once by hand and check the output:
   ```bash
   ~/.copilot/update-copilot-rate-limits.py && python3 -m json.tool ~/.copilot/runcat-copilot-limits.json
   ```
   If macOS shows a Keychain permission dialog for `gh` — click **Always Allow** so the scheduled runs don't stall on it.
4. Register the LaunchAgent so it keeps running every 5 minutes:
   ```bash
   cp dev.runcat.copilot-rate-limits.plist ~/Library/LaunchAgents/dev.runcat.copilot-rate-limits.plist
   ```
   Open the copied plist and replace `/Users/YOU` with your home path, then:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.runcat.copilot-rate-limits.plist
   ```
5. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add JSON Source**, and choose `~/.copilot/runcat-copilot-limits.json`. The folder is hidden in the open panel — press `⌘⇧.` or `⌘⇧G` and type the path. The card appears on the dashboard immediately.
6. Optional: click the Metrics Bar and flip the source's toggle to show the premium-requests remaining percentage (`metricsBarValue`, e.g. `17%`) directly in the menu bar.

To stop updating, unload the agent:

```bash
launchctl bootout gui/$(id -u)/dev.runcat.copilot-rate-limits
```

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). Edit the `build_snapshot(...)` block to add rows, change the card title, or pick a different SF Symbol.

Environment overrides:

| Variable             | Default                                 | Description |
|----------------------|-----------------------------------------|-------------|
| `RUNCAT_OUT_FILE`    | `~/.copilot/runcat-copilot-limits.json` | Where the snapshot is written. |
| `RUNCAT_LIMITS_SHOW` | `remaining`                             | `remaining` shows what is left (`17% left`); `used` shows consumption (`83% used`). The bars follow the same choice. |
| `RUNCAT_GH_CLI`      | auto-detected                           | Path to the `gh` binary. Set this if the script can't find `gh` on its own (see Troubleshooting). |

Set them in the plist with an `EnvironmentVariables` dict. `StartInterval` controls the update cadence; the endpoint reports quotas that move slowly, so a few minutes is plenty — please don't hammer it.

## Troubleshooting

- File never appears → run the script by hand (step 3); errors are printed to stderr. It needs Python 3, which ships with the Xcode Command Line Tools (`xcode-select --install`).
- `` `gh` CLI not found `` → under `launchd` the job runs with a minimal `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`) that omits Homebrew. The script already probes `/opt/homebrew/bin` and `/usr/local/bin`; if your `gh` lives elsewhere, set `RUNCAT_GH_CLI` to its full path (check with `which gh`) in the plist's `EnvironmentVariables`.
- `` `gh auth token` returned no token `` → sign in with `gh auth login`.
- `usage request failed: HTTP Error 401/403` → the stored token was revoked or lacks access; re-run `gh auth login`.
- `response contains no quota snapshots` → the signed-in account has no Copilot plan, or the undocumented endpoint changed shape.
- Card stops updating under `launchd` but works by hand → the Keychain dialog was dismissed instead of **Always Allow**-ed. Re-run step 3.
- Agent status → `launchctl print gui/$(id -u)/dev.runcat.copilot-rate-limits`.
- Card footer shows **Last updated: Failed** in red → the file became unreadable or contains invalid JSON. Re-run the script by hand (step 3); the card recovers on the next successful read.
