# Claude usage limits & out-of-band updates

The [statusLine sample](runcat-statusline.py) refreshes the card **only while Claude Code is
running** — the status line command fires on Claude Code's turns, so when Claude Code is closed
the card freezes at its last value. This note covers (1) what the statusLine can tell you about
your subscription rate limits, (2) a supported way to show reset countdowns, and (3) an
**unofficial, unsupported** way to update the card without a Claude Code session.

## The rate-limit fields

For Claude.ai **Pro/Max** subscribers, Claude Code's statusLine JSON includes rolling usage
windows. They're absent for API-key / Console usage, and only populate after the first API
response in a session:

```jsonc
{
  "rate_limits": {
    "five_hour": { "used_percentage": 41, "resets_at": 1784150400 },  // 5-hour window
    "seven_day": { "used_percentage": 29, "resets_at": 1784606400 }   //  7-day window
  }
}
```

`used_percentage` is 0–100; `resets_at` is Unix epoch seconds. These are the subscription's
*account-wide* limits (shared across claude.ai, the desktop app, and Claude Code) — but the
statusLine only surfaces them **to Claude Code, during a session**.

## Supported: reset countdowns

The stock sample shows `5h: 41%`. `resets_at` lets you also show *when* the window clears —
often the more actionable number. Drop-in replacement for the `pct()` helper:

```python
from datetime import datetime, timezone

def limit_row(title, node):
    node = node or {}
    used = node.get("used_percentage")
    if used is None:
        return None
    text = f"{used:g}%"
    resets_at = node.get("resets_at")
    if resets_at:
        secs = int(resets_at - datetime.now(timezone.utc).timestamp())
        if secs > 0:
            h, m = divmod(secs // 60, 60)
            text += f" · resets {h}h{m:02d}m" if h else f" · resets {m}m"
    return {"title": title, "formattedValue": text, "normalizedValue": round(used / 100, 4)}

# rate_limits = payload.get("rate_limits") or {}
# limit_row("5h", rate_limits.get("five_hour"))
#   ->  {"title": "5h", "formattedValue": "41% · resets 2h11m", "normalizedValue": 0.41}
```

## Can the card update without Claude Code running?

**Not through any supported API.** If you want the card to reflect your subscription usage while
Claude Code is closed, know up front that there is no sanctioned path (verified against the
public docs, 2026-07):

- The `anthropic-ratelimit-*` / `x-ratelimit-*` **response headers** on `/v1/messages` describe
  **API-key** limits (RPM/TPM) — a separate bucket from the Claude.ai subscription's 5h/7d windows.
- The **Admin usage/cost API** (`/v1/organizations/usage_report/messages`,
  `/v1/organizations/cost_report`) is scoped to **API-key organizations**, needs an admin key, and
  reports API token usage/cost — not consumer subscription limits.
- No documented endpoint returns a consumer Pro/Max subscription's 5h/7d usage, and nothing
  persists it to a local file between sessions.

So the supported answer is: the card is a **Claude-Code-session gauge**. RunCat's "Last updated"
footer already signals when it has gone stale.

## ⚠️ Unofficial / Experimental: out-of-band poller

> **This is not a supported integration.** It calls an **undocumented internal endpoint** that
> Claude Code uses for its `/usage` command, authenticating with the OAuth token Claude Code
> stores in your macOS login Keychain. It will break without warning if Anthropic changes the
> endpoint or the token storage, and automated calls to a non-public endpoint may run against
> Anthropic's terms of service. Use at your own risk, and please don't open RunCat issues when it
> breaks — start by re-reading this section.

[`runcat-usage-poll.py`](runcat-usage-poll.py) fetches your 5h / 7d (and, if present, per-model
weekly) runway from:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token from Keychain item "Claude Code-credentials">
anthropic-beta: oauth-2025-04-20
```

…and writes the same `~/.claude/runcat-usage.json` card — **with no Claude Code session running**.
Drive it on a schedule with launchd ([`com.example.runcat-usage-poll.plist`](com.example.runcat-usage-poll.plist)).

### Setup

1. `cp runcat-usage-poll.py ~/.claude/ && chmod +x ~/.claude/runcat-usage-poll.py`
2. Run it once by hand: `python3 ~/.claude/runcat-usage-poll.py`. macOS prompts for Keychain access
   to `Claude Code-credentials` → **Always Allow** (so the scheduled job can read it later). On
   success it prints the card values.
   - `--debug` also saves the raw response to `~/.claude/runcat-usage-raw.json` (useful if the
     endpoint's shape ever changes).
   - `--selftest` checks the parser with no network and no Keychain access.
3. Edit `com.example.runcat-usage-poll.plist` (set your real `/Users/YOU/` paths), copy it to
   `~/Library/LaunchAgents/`, then
   `launchctl load -w ~/Library/LaunchAgents/com.example.runcat-usage-poll.plist`. Default interval
   is 10 minutes. Stop it with `launchctl unload …`.

### Known limits

- **Unlocked Mac only.** A launchd agent can read the login Keychain only while your session is
  unlocked. Asleep / locked / logged-out → no update.
- **Token expiry when idle.** Claude Code refreshes the stored token when you use it. Go long
  enough without running Claude Code and the poller gets `401` until you open it again. The script
  notes where to add a token-refresh flow if you want true independence.
- **Undocumented.** If the card stops updating, run with `--debug` and check whether the endpoint
  or response shape changed.

## Payload reference — build any card row you want

`/api/oauth/usage` returns far more than 5h/7d. Every field below can become a card row. Run
`runcat-usage-poll.py --debug` to see exactly which are populated on your plan — many are
plan-specific and arrive as `null`. Shapes are undocumented and may change.

### Rolling usage windows (top-level keys)

Each is either `null` or `{"utilization": 0-100, "resets_at": "<ISO-8601>", "limit_dollars": …,
"used_dollars": …, "remaining_dollars": …}`. The `*_dollars` fields populate only on
money-metered windows; percentage plans leave them `null`.

| Key | Window |
|---|---|
| `five_hour` | 5-hour session window |
| `seven_day` | 7-day, all models |
| `seven_day_opus` | 7-day, Opus only |
| `seven_day_sonnet` | 7-day, Sonnet only |
| `seven_day_oauth_apps` | 7-day, third-party OAuth-app usage |
| `seven_day_cowork` | 7-day, Cowork surface |

The response also carries several additional, usually-`null` experimental windows (internal
code-names) — ignore them unless they show up populated.

### `limits[]` — normalized list (easiest to iterate)

An array of every active limit, already flattened. Iterate this to build rows generically instead
of reaching for the top-level keys one by one.

| Field | Meaning |
|---|---|
| `kind` | `session` \| `weekly_all` \| `weekly_scoped` |
| `group` | `session` \| `weekly` |
| `percent` | 0-100 used |
| `severity` | `normal`, and elevated values as you approach the cap — map to a warning color |
| `resets_at` | ISO-8601 reset time |
| `scope` | `null`, or `{"model": {"display_name": "Fable"}, "surface": …}` for `weekly_scoped` |
| `is_active` | whether this is the currently-binding limit |

### `extra_usage` — pay-as-you-go credits

| Field | Meaning |
|---|---|
| `is_enabled` | credits turned on |
| `utilization` | 0-100 of the credit budget used |
| `used_credits` / `monthly_limit` | minor units — divide by `10 ** decimal_places` |
| `currency` / `decimal_places` | e.g. `"EUR"`, `2` → `2691` means `26.91` |
| `disabled_reason` / `daily` / `weekly` | usually `null` |

### `spend` — the same credits as money (richer)

| Field | Meaning |
|---|---|
| `used` / `limit` / `cap.money` | `{"amount_minor", "currency", "exponent"}` — divide `amount_minor` by `10 ** exponent` |
| `percent` / `severity` | 0-100 and alert level |
| `enabled` / `disabled_reason` | credit state |
| `can_purchase_credits` / `can_toggle` | UI capability flags |
| `disclaimer` | Markdown blurb |
| `balance` / `auto_reload` | usually `null` |

### `member_dashboard_available`

Boolean — whether a team/member usage dashboard is available.

### Turning a field into a row

RunCat rows are `{"title", "formattedValue", "normalizedValue"}`, where `normalizedValue` (0–1)
drives the gauge. The poller's `_row()` / `find_window()` helpers make each of these one line:

```python
# one row per entry in limits[], with per-model scope folded into the title
for lim in data.get("limits") or []:
    model = ((lim.get("scope") or {}).get("model") or {}).get("display_name")
    title = f"{lim['kind']} {model}".strip() if model else lim["kind"]
    rows.append(_row(title, lim.get("percent"), lim.get("resets_at"), now))

# credits as money, e.g. "26.91 / 150.00 EUR"
spend = data.get("spend") or {}
if spend.get("enabled"):
    used = spend["used"]["amount_minor"] / 10 ** spend["used"]["exponent"]
    cap = spend["limit"]["amount_minor"] / 10 ** spend["limit"]["exponent"]
    rows.append({
        "title": "Credits",
        "formattedValue": f"{used:.2f} / {cap:.2f} {spend['used']['currency']}",
        "normalizedValue": round(spend.get("percent", 0) / 100, 4),
    })
```
