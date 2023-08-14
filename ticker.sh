#!/usr/bin/env bash
set -e

LANG=C
LC_NUMERIC=C

: ${TMPDIR:=/tmp}
SESSION_DIR="${TMPDIR%/}/ticker.sh-$(whoami)"
COOKIE_FILE="${SESSION_DIR}/cookies.txt"
API_ENDPOINT="https://query1.finance.yahoo.com/v8/finance/chart/"
API_SUFFIX="?interval=1d"

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

if [ -z "$SYMBOLS" ]; then
  echo "Usage: ./ticker.sh AAPL MSFT GOOG BTC-USD"
  exit
fi

[ ! -d "$SESSION_DIR" ] && mkdir -m 700 "$SESSION_DIR"

preflight () {
  curl --silent --output /dev/null --cookie-jar "$COOKIE_FILE" "https://finance.yahoo.com" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
}

fetch_chart () {
  local symbol=$1
  local url="${API_ENDPOINT}${symbol}${API_SUFFIX}"
  curl --silent -b "$COOKIE_FILE" "$url"
}

[ ! -f "$COOKIE_FILE" ] && preflight

# printf "%-10s %12s %10s %10s\n" "Symbol" "Price" "Change" "Change (%)"

for symbol in "${SYMBOLS[@]}"; do
  results=$(fetch_chart "$symbol")

  currentPrice=$(echo "$results" | jq -r '.chart.result[0].meta.regularMarketPrice')
  previousClose=$(echo "$results" | jq -r '.chart.result[0].meta.chartPreviousClose')
  currency=$(echo "$results" | jq -r '.chart.result[0].meta.currency')
  symbol=$(echo "$results" | jq -r '.chart.result[0].meta.symbol')

  priceChange=$(python -c "print('{:.2f}'.format($currentPrice - $previousClose))")
  percentChange=$(python -c "print('{:.2f}'.format(($currentPrice - $previousClose) / $previousClose * 100))")

  if (( $(echo "$priceChange >= 0" | bc -l) )); then
    color=$'\e[32m'
  elif (( $(echo "$priceChange < 0" | bc -l) )); then
    color=$'\e[31m'
  fi

  printf "%s%-10s%8.2f%10.2f%8s%6.2f%%%s\n" \
    "$color" "$symbol" \
    "$currentPrice" "$priceChange" "$color" "$percentChange" \
    $'\e[0m'

done

