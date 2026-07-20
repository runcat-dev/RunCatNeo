# Bitcoin Price Sample

A lightweight shell script that shows the current Bitcoin price in USD on RunCat Neo's Custom Metrics card and in the Metrics Bar. It fetches the price from the [CoinGecko public API](https://docs.coingecko.com/) — no account, no API key — writes a Custom Metrics JSON snapshot to `~/.runcat/bitcoin.json`, and a `launchd` LaunchAgent re-runs it every 10 minutes.

```text
CoinGecko API → update-bitcoin.sh → bitcoin.json → RunCat Neo
```

Unlike the Claude Code sample, nothing triggers the script for you, so this sample also demonstrates how to schedule a producer with `launchd` — the same pattern works for any metric you can fetch with `curl`.

## Setup

1. Copy the script and make it executable:
   ```bash
   mkdir -p ~/.runcat
   cp update-bitcoin.sh ~/.runcat/update-bitcoin.sh
   chmod +x ~/.runcat/update-bitcoin.sh
   ```
2. Run it once by hand and check the output:
   ```bash
   ~/.runcat/update-bitcoin.sh && cat ~/.runcat/bitcoin.json
   ```
3. Register the LaunchAgent so it keeps running every 10 minutes:
   ```bash
   cp dev.runcat.bitcoin-sample.plist ~/Library/LaunchAgents/dev.runcat.bitcoin-sample.plist
   ```
   Open the copied plist and replace `/Users/YOU` with your home path, then:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.runcat.bitcoin-sample.plist
   ```
4. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add Custom Metrics Source**, and choose `~/.runcat/bitcoin.json`. The folder is hidden in the open panel — press `⌘⇧.` or `⌘⇧G` and type the path. The card appears on the dashboard immediately.
5. Optional: click the Metrics Bar and flip the source's toggle to show the price (`metricsBarValue`, e.g. `$61.9K`) directly in the menu bar.

To stop updating, unload the agent:

```bash
launchctl bootout gui/$(id -u)/dev.runcat.bitcoin-sample
```

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). The CoinGecko endpoint takes other coin ids and currencies (e.g. `ids=ethereum`, `vs_currencies=jpy`), so a different asset is a two-line edit: change the query in `apiURL` and adjust the `$` formatting in the two `awk` calls.

`RUNCAT_OUT_FILE` overrides where the snapshot is written (default: `~/.runcat/bitcoin.json`). `StartInterval` in the plist controls the update cadence; CoinGecko's keyless API is rate-limited, so keep it at a few minutes or more.

## Troubleshooting

- File never appears → run the script by hand (step 2). `curl` errors print to stderr.
- File exists but stops updating → check the agent is loaded: `launchctl print gui/$(id -u)/dev.runcat.bitcoin-sample`.
- Card footer shows **Last updated: Failed** in red → the file became unreadable or contains invalid JSON. Re-run the script by hand (step 2); the card recovers on the next successful read.
