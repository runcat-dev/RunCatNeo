# Codex Integration Sample

A small Python script that lets RunCat Neo's Custom Metrics card show the current Codex model, context-window usage, and account rate limits. Codex runs the script after each turn through a `Stop` lifecycle hook. The script reads the latest token-count event from the session transcript and writes a Custom Metrics JSON snapshot to `~/.codex/runcat-usage.json`.

This sample uses Codex's local session transcript, whose format may change between Codex releases. If it stops working after an update, inspect the latest `token_count` event under `~/.codex/sessions/` and adjust the parser in `runcat-hook.py`.

## Setup

1. Copy the script and make it executable:
   ```bash
   cp runcat-hook.py ~/.codex/runcat-hook.py
   chmod +x ~/.codex/runcat-hook.py
   ```
2. Register it in `~/.codex/hooks.json`:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "/Users/YOU/.codex/runcat-hook.py",
               "timeout": 5
             }
           ]
         }
       ]
     }
   }
   ```
   Replace `/Users/YOU` with your home path. If you already have `~/.codex/hooks.json`, add the inner entry to its existing `Stop` array instead of replacing the file.
3. Restart Codex, then use `/hooks` to review and trust the new hook if prompted.
4. Complete a turn in Codex. The script creates `~/.codex/runcat-usage.json` after the turn finishes.
5. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add JSON Source**, and choose `~/.codex/runcat-usage.json`.
6. Optional: click the Metrics Bar and flip the source's toggle to show context usage in the menu bar.

The hook feature is enabled by default in current Codex releases. If `/hooks` is unavailable, add this to `~/.codex/config.toml` and restart Codex:

```toml
[features]
hooks = true
```

## What it displays

- **Model** — the active model slug provided to the hook.
- **Context** — the latest context token count divided by the model's context-window size.
- **5h**, **7d**, or another duration — the used percentage for each rate-limit window included in the latest token-count event.
- **Metrics Bar** — context-window usage by default. Weekly mode shows the remaining 7-day allowance; for example, a `7d` row showing `23%` used produces `7d 77%` in the menu bar.

If a snapshot already exists, sessions without a recognized token-count event or account rate limits leave the last valid snapshot untouched. This prevents concurrent API-key, local-model, or incomplete sessions from replacing account usage with a Model-only card. The script always exits successfully so a parsing failure does not interrupt Codex.

## Choose the Metrics Bar value

RunCat Neo's toggle controls whether the Custom Metrics source is visible in the Metrics Bar; it does not select one of the card's rows. Context usage remains the default for compatibility.

To show the remaining 7-day allowance instead, create `~/.codex/runcat-bar-mode` with `weekly` as its content:

```bash
printf 'weekly\n' > ~/.codex/runcat-bar-mode
```

The mode file is optional and is not created automatically. If it is missing or invalid, the script uses `context`. You can also select that mode explicitly:

```bash
printf 'context\n' > ~/.codex/runcat-bar-mode
```

The change appears after the next completed Codex turn. If the selected metric is unavailable, the script falls back to the other value so the Metrics Bar does not show `---`.

`RUNCAT_BAR_MODE` overrides the file with `weekly` or `context` for one invocation. `RUNCAT_BAR_MODE_FILE` overrides the mode file path.

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). Edit the `snapshot` dictionary to add rows, change the card title, or pick a different SF Symbol.

`RUNCAT_OUT_FILE` overrides where the snapshot is written (default: `~/.codex/runcat-usage.json`).

## Troubleshooting

- File never appears → run the script manually with a recent session transcript:
  ```bash
  transcript="$(find ~/.codex/sessions -name '*.jsonl' -type f -print0 \
    | xargs -0 stat -f '%m %N' \
    | sort -nr \
    | head -n 1 \
    | cut -d ' ' -f 2-)"
  printf '{"model":"Codex","transcript_path":"%s"}\n' "$transcript" \
    | ~/.codex/runcat-hook.py
  python3 -m json.tool ~/.codex/runcat-usage.json
  ```
- The card shows only **Model** → no valid snapshot existed before a transcript without a recognized `token_count` event was processed. Check that `transcript_path` exists and compare its latest token-count event with `latest_token_count()` in the script.
- The hook does not run → open `/hooks` in Codex and confirm the hook is enabled and trusted.
- The card footer shows **Last updated: Failed** in red → confirm `~/.codex/runcat-usage.json` still exists and is readable, then complete another Codex turn.
