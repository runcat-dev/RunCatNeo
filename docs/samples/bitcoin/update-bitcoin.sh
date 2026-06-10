#!/bin/sh
# RunCat Neo — Bitcoin price sample.
#
# Fetches the current Bitcoin price in USD from the CoinGecko public API
# and writes a Custom Metrics JSON snapshot shaped like:
#
#     {
#       "title": "Bitcoin",
#       "symbol": "bitcoinsign",
#       "metricsBarValue": "$61.9K",
#       "metrics": [
#         { "title": "Current", "formattedValue": "$61888.04" }
#       ],
#       "lastUpdatedDate": "2026-06-05T04:50:40Z"
#     }

set -eu

outputFile="${RUNCAT_OUT_FILE:-$HOME/.runcat/bitcoin.json}"
apiURL="https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"

price=$(curl -fsS --max-time 15 "$apiURL" | sed -nE 's/.*"usd" *: *([0-9]+(\.[0-9]+)?).*/\1/p')
if [ -z "$price" ]; then
    echo "Failed to extract the Bitcoin price from the CoinGecko response" >&2
    exit 1
fi

metricsBarValue=$(awk -v price="$price" 'BEGIN {
    if (price >= 1000000) printf "$%.2fM", price / 1000000
    else if (price >= 1000) printf "$%.1fK", price / 1000
    else printf "$%.2f", price
}')
currentValue=$(awk -v price="$price" 'BEGIN { printf "$%.2f", price }')
lastUpdatedDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)

outputDirectory=$(dirname "$outputFile")
mkdir -p "$outputDirectory"
temporaryFile=$(mktemp "$outputDirectory/.bitcoin-XXXXXX")
cat > "$temporaryFile" <<EOF
{
  "title": "Bitcoin",
  "symbol": "bitcoinsign",
  "metricsBarValue": "$metricsBarValue",
  "metrics": [
    { "title": "Current", "formattedValue": "$currentValue" }
  ],
  "lastUpdatedDate": "$lastUpdatedDate"
}
EOF
mv "$temporaryFile" "$outputFile"
