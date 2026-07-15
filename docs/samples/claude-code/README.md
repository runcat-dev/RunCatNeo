# Claude Code Integration Sample

A minimal Python script that lets RunCat Neo's Custom Metrics card show your Claude Code session at a glance. Each time Claude Code runs its statusLine command, the script writes a Custom Metrics JSON snapshot to `~/.claude/runcat-usage.json` and prints the current model name as the terminal status line.

## Setup

1. Copy the script and make it executable:
   ```bash
   cp runcat-statusline.py ~/.claude/runcat-statusline.py
   chmod +x ~/.claude/runcat-statusline.py
   ```
2. Register it in `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/Users/YOU/.claude/runcat-statusline.py"
     }
   }
   ```
   Replace `/Users/YOU` with your home path. The shebang at the top of the script picks up `python3` automatically.
3. In RunCat Neo, open **Settings → Metrics → Custom Metrics**, click **Add JSON Source**, and choose `~/.claude/runcat-usage.json`. The card appears on the dashboard immediately.
4. Run Claude Code. The card updates each turn.
5. Optional: click the Metrics Bar and flip the source's toggle to show the context usage (`metricsBarValue`) directly in the menu bar.

## Already have a statusLine?

`~/.claude/settings.json` only allows a single `statusLine.command`, so combine yours and this one yourself. Asking Claude works well: "Here's my existing statusline script and the RunCat sample — write me one that does both" usually produces a clean merge in one shot.

## Customizing the output

The output JSON shape is documented in [`../../CustomMetricsSchema.md`](../../CustomMetricsSchema.md). Edit the `snapshot = {...}` block to add rows, change the card title, or pick a different SF Symbol.

`RUNCAT_OUT_FILE` overrides where the snapshot is written (default: `~/.claude/runcat-usage.json`).

## Troubleshooting

- Card shows nothing → confirm Claude Code is calling the statusLine. Run the script by hand to see what it writes:
  ```bash
  printf '{}' | ~/.claude/runcat-statusline.py && python3 -m json.tool ~/.claude/runcat-usage.json
  ```
- Card stays at the same values → check `~/.claude/runcat-usage.json`'s mtime. If it doesn't update on every Claude Code turn, Claude Code isn't invoking the statusLine.
- Card footer shows **Last updated: Failed** in red → the file became unreadable. Confirm `~/.claude/runcat-usage.json` still exists, then run another Claude Code turn; the card recovers on the next successful read.
