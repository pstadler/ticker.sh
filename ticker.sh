#!/usr/bin/env bash
set -e

LANG=C
LC_NUMERIC=C

: ${TMPDIR:=/tmp}
SESSION_DIR="${TMPDIR%/}/ticker.sh-$(whoami)"
COOKIE_FILE="${SESSION_DIR}/cookies.txt"
API_ENDPOINT="https://query1.finance.yahoo.com/v8/finance/chart/"
API_SUFFIX="?interval=1d"

# Check if NO_COLOR is set to disable colorization
if [ -z "$NO_COLOR" ]; then
  : "${COLOR_GREEN:=$'\e[32m'}"
  : "${COLOR_RED:=$'\e[31m'}"
  : "${COLOR_RESET:=$'\e[00m'}"
fi

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

# Adding bc check for colors correct. Thank you @milanico2309
if ! $(type bc > /dev/null 2>&1); then
  echo "'bc' is not in the PATH. (See: https://www.gnu.org/software/bc/)"
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

# Initialize an array to hold background process IDs
pids=()

for symbol in "${SYMBOLS[@]}"; do
 (
  # Running in subshell 
  results=$(fetch_chart "$symbol")

  currentPrice=$(echo "$results" | jq -r '.chart.result[0].meta.regularMarketPrice')
  previousClose=$(echo "$results" | jq -r '.chart.result[0].meta.chartPreviousClose')
  currency=$(echo "$results" | jq -r '.chart.result[0].meta.currency')
  symbol=$(echo "$results" | jq -r '.chart.result[0].meta.symbol')

  priceChange=$(awk -v currentPrice="$currentPrice" -v previousClose="$previousClose" 'BEGIN {printf "%.2f", currentPrice - previousClose}')
  percentChange=$(awk -v currentPrice="$currentPrice" -v previousClose="$previousClose" 'BEGIN {printf "%.2f", ((currentPrice - previousClose) / previousClose) * 100}')

  if (( $(echo "$priceChange >= 0" | bc -l) )); then
    color="$COLOR_GREEN"
  elif (( $(echo "$priceChange < 0" | bc -l) )); then
    color="$COLOR_RED"
  fi

  if [ -z "$NO_COLOR" ]; then
    printf "%s%-10s%8.2f%10.2f%8s%6.2f%%%s\n" \
      "$color" "$symbol" \
      "$currentPrice" "$priceChange" "$color" "$percentChange" \
      "$COLOR_RESET"
  else
    printf "%-10s%8.2f%10.2f%9.2f%%\n" \
      "$symbol" \
      "$currentPrice" "$priceChange" "$percentChange"
  fi 
 ) &

 # Stack PIDs
 pids+=($!)

done

# Wait for all background processes to finish
for pid in "${pids[@]}"; do
  wait "$pid"
done
