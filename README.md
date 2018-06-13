# ticker.sh

> Real-time stock tickers from the command-line.

`ticker.sh` is a simple shell script using the Yahoo Finance API as a data source. It features colored output and is able to display pre- and post-market prices.

![ticker.sh](https://raw.githubusercontent.com/pstadler/ticker.sh/master/screenshot.png)

## Install

```sh
$ curl -o ticker.sh https://raw.githubusercontent.com/pstadler/ticker.sh/master/ticker.sh
```

Make sure to install [jq](https://stedolan.github.io/jq/), a versatile command-line JSON processor.

## Usage

```sh
# Single symbol:
$ ./ticker.sh AAPL

# Multiple symbols:
$ ./ticker.sh AAPL MSFT GOOG BTC-USD

# Read from file:
$ echo "AAPL MSFT GOOG BTC-USD" > ~/.ticker.conf
$ ./ticker.sh $(cat ~/.ticker.conf)

# Update every five seconds:
$ while true; do clear; ./ticker.sh AAPL MSFT GOOG BTC-USD; sleep 5; done
```

This script works well with [GeekTool](https://www.tynsoe.org/v2/geektool/) and similar software:

```sh
# GeekTool example script:

PATH=/usr/local/bin:$PATH # make sure to include the path where jq is located
~/GitHub/ticker.sh/ticker.sh AAPL MSFT GOOG BTC-USD
```
