#!/usr/bin/env bash
set -e

LANG=C
LC_NUMERIC=C

: ${TMPDIR:=/tmp}
SESSION_DIR="${TMPDIR%/}/ticker.sh-$(whoami)"
COOKIE_FILE="${SESSION_DIR}/cookies.txt"
CRUMB_FILE="${SESSION_DIR}/crumb.txt"

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

if [ -z "$SYMBOLS" ]; then
  echo "Usage: ./ticker.sh AAPL MSFT GOOG BTC-USD"
  exit
fi

FIELDS=(symbol marketState regularMarketPrice regularMarketChange regularMarketChangePercent \
  preMarketPrice preMarketChange preMarketChangePercent postMarketPrice postMarketChange postMarketChangePercent)
API_ENDPOINT="https://query1.finance.yahoo.com/v7/finance/quote?lang=en-US&region=US&corsDomain=finance.yahoo.com"

if [ -z "$NO_COLOR" ]; then
  : "${COLOR_BOLD:=\e[1;37m}"
  : "${COLOR_GREEN:=\e[32m}"
  : "${COLOR_RED:=\e[31m}"
  : "${COLOR_RESET:=\e[00m}"
fi

symbols=$(IFS=,; echo "${SYMBOLS[*]}")
fields=$(IFS=,; echo "${FIELDS[*]}")

[ ! -d "$SESSION_DIR" ] && mkdir -m 700 "$SESSION_DIR"

preflight () {
  curl --silent --output /dev/null --cookie-jar "$COOKIE_FILE" "https://finance.yahoo.com" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
  curl --silent -b "$COOKIE_FILE" "https://query1.finance.yahoo.com/v1/test/getcrumb" \
    > "$CRUMB_FILE"
}

fetch_quotes () {
  curl --silent -b "$COOKIE_FILE" "$API_ENDPOINT&fields=$fields&symbols=$symbols&crumb=$(cat "$CRUMB_FILE")"
}

[ ! -f "$COOKIE_FILE" -o ! -f "$CRUMB_FILE" ] && preflight
results=$(fetch_quotes)
if $(echo "$results" | grep -q '"code":"Unauthorized"'); then
  preflight
  results=$(fetch_quotes)
fi

results=$(echo $results | jq '.quoteResponse .result')

query () {
  echo $results | jq -r ".[] | select(.symbol == \"$1\") | .$2"
}

for symbol in $(IFS=' '; echo "${SYMBOLS[*]}" | tr '[:lower:]' '[:upper:]'); do
  marketState="$(query $symbol 'marketState')"

  if [ -z $marketState ]; then
    printf 'No results for symbol "%s"\n' $symbol
    continue
  fi

  preMarketChange="$(query $symbol 'preMarketChange')"
  postMarketChange="$(query $symbol 'postMarketChange')"

  if [ $marketState = "PRE" ] \
    && [ $preMarketChange != "0" ] \
    && [ $preMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'preMarketPrice')
    diff=$preMarketChange
    percent=$(query $symbol 'preMarketChangePercent')
  elif [ $marketState != "REGULAR" ] \
    && [ $postMarketChange != "0" ] \
    && [ $postMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'postMarketPrice')
    diff=$postMarketChange
    percent=$(query $symbol 'postMarketChangePercent')
  else
    nonRegularMarketSign=''
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
  fi

  # see https://github.com/pstadler/ticker.sh/issues/40
  [ "$diff" = "null" ] && diff="0.0"
  [ "$percent" = "null" ] && percent="0.0"

  if [ "$diff" = "0" ] || [ "$diff" = "0.0" ]; then
    color=
  elif ( echo "$diff" | grep -q ^- ); then
    color=$COLOR_RED
  else
    color=$COLOR_GREEN
  fi

  if [ "$price" != "null" ]; then
    printf "%-10s$COLOR_BOLD%8.2f$COLOR_RESET" $symbol $price
    printf "$color%10.2f%12s$COLOR_RESET" $diff $(printf "(%.2f%%)" $percent)
    printf " %s\n" "$nonRegularMarketSign"
  fi
done
