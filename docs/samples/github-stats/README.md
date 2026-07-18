# GitHub Statistics Integration

A Python script that tracks your GitHub contribution activity in RunCat Neo. Shows your daily commits, weekly progress, contribution streak, and merged PRs at a glance.

## Features

- **Today's commits** - How active you've been today
- **This week's commits** - Weekly progress with a visual bar
- **Current streak** - Consecutive days with contributions
- **Best streak** - Your personal record
- **PRs merged this week** - Actual shipped work

## Setup

### 1. Install and authenticate GitHub CLI

```bash
# Install if you haven't already
brew install gh

# Authenticate (if not already done)
gh auth login
```

That's it! The script uses your existing GitHub CLI authentication - no tokens to manage.

### 2. Install the script

```bash
cp update-github-stats.py ~/.runcat/update-github-stats.py
chmod +x ~/.runcat/update-github-stats.py
```

### 3. Test it

```bash
~/.runcat/update-github-stats.py
python3 -m json.tool ~/.runcat/github-stats.json
```

You should see your GitHub stats in the JSON output.

### 4. Set up automatic updates

Copy the launchd configuration:

```bash
cp dev.runcat.github-stats.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/dev.runcat.github-stats.plist
```

This runs the script:
- Every 10 minutes (600 seconds)
- Automatically on login
- In the background

### 5. Add to RunCat Neo

1. Open **RunCat Neo → Settings → Metrics → Custom Metrics**
2. Click **"Add JSON Source"**
3. Select `~/.runcat/github-stats.json`
4. The card appears on your dashboard immediately

### Optional: Show in Menu Bar

Click the Metrics Bar icon and toggle the GitHub stats source to show your today's commit count directly in the menu bar.

## Customization

Edit the script to adjust:
- **`metricsBarValue`** - Currently shows today's commits; change to streak or week count
- **Metric normalization** - Line 197 normalizes weekly commits to max 100; adjust as needed
- **SF Symbol** - Line 209 uses `chevron.left.forwardslash.chevron.right`; pick any [SF Symbol](https://developer.apple.com/sf-symbols/)

## Troubleshooting

**"Error: GitHub CLI (gh) not found"**
- Install it with: `brew install gh`

**"Error getting GitHub credentials"**
- Make sure you're logged in: `gh auth login`
- Check your auth status: `gh auth status`

**"GitHub API error"**
- Your GitHub CLI session may have expired - re-authenticate with `gh auth login`

**Card shows old data**
- Check if the script is running: `launchctl list | grep github-stats`
- View logs: `log show --predicate 'process == "update-github-stats.py"' --last 1h`
- Run manually to see errors: `~/.runcat/update-github-stats.py`

**Rate limiting**
- Authenticated requests get 5,000 requests/hour (plenty for this use case)
- The script makes 3 GraphQL queries per run
- Running every 10 minutes = 144 runs/day = 432 API calls/day (well under limit)
