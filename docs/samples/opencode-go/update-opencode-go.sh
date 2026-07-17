#!/bin/sh
# RunCat Neo — OpenCode Go usage sample.
#
# Fetches your OpenCode Go subscription usage (rolling / weekly / monthly)
# from opencode.ai and writes a Custom Metrics JSON snapshot shaped like:
#
#     {
#       "title": "OpenCode Go",
#       "symbol": "rectangle.portrait",
#       "metricsBarValue": "12.5%",
#       "metrics": [
#         { "title": "Rolling (5h)", "formattedValue": "12.5%", "normalizedValue": 0.125 },
#         { "title": "Weekly",      "formattedValue": "8.3%",  "normalizedValue": 0.083 },
#         { "title": "Monthly",     "formattedValue": "3.1%",  "normalizedValue": 0.031 }
#       ],
#       "lastUpdatedDate": "2026-06-06T10:15:00Z"
#     }

set -eu

outputFile="${RUNCAT_OUT_FILE:-$HOME/.runcat/opencode-go.json}"
cookieFile="${OPENCODE_COOKIE_FILE:-$HOME/.config/opencode-go-usage/session}"
binPath="${OPENCODE_GO_USAGE_BIN:-$HOME/.runcat/bin/opencode-go-usage}"
workspace="${OPENCODE_WORKSPACE:-}"

args="-cookie-file $cookieFile -json"
if [ -n "$workspace" ]; then
    args="$args -workspace $workspace"
fi

usage=$("$binPath" $args 2>/dev/null) || {
    echo "Failed to fetch OpenCode Go usage. Is the cookie file valid?" >&2
    exit 1
}

rollingPct=$(echo "$usage" | jq -r '.rolling.percent')
weeklyPct=$(echo "$usage" | jq -r '.weekly.percent')
monthlyPct=$(echo "$usage" | jq -r '.monthly.percent')
plan=$(echo "$usage" | jq -r '.plan')
lastUpdated=$(echo "$usage" | jq -r '.fetched_at')

# Clamp to 0-1 for normalizedValue
normalize() {
    awk -v v="$1" 'BEGIN { v = v + 0; if (v < 0) v = 0; if (v > 100) v = 100; printf "%.4f", v / 100 }'
}

rollingNorm=$(normalize "$rollingPct")
weeklyNorm=$(normalize "$weeklyPct")
monthlyNorm=$(normalize "$monthlyPct")

# Format percentage string for metricsBarValue (no decimals for integers)
formatPct() {
    awk -v v="$1" 'BEGIN { v = v + 0; printf "%g%%", v }'
}

outputDirectory=$(dirname "$outputFile")
mkdir -p "$outputDirectory"
temporaryFile=$(mktemp "$outputDirectory/.opencode-go-XXXXXX")
cat > "$temporaryFile" <<EOF
{
  "title": "OpenCode Go",
  "symbol": "rectangle.portrait",
  "metricsBarValue": "$(formatPct "$rollingPct")",
  "metrics": [
    { "title": "Rolling (5h)", "formattedValue": "$(formatPct "$rollingPct")",  "normalizedValue": $rollingNorm },
    { "title": "Weekly",      "formattedValue": "$(formatPct "$weeklyPct")",   "normalizedValue": $weeklyNorm },
    { "title": "Monthly",     "formattedValue": "$(formatPct "$monthlyPct")",  "normalizedValue": $monthlyNorm }
  ],
  "lastUpdatedDate": "$lastUpdated"
}
EOF
mv "$temporaryFile" "$outputFile"
