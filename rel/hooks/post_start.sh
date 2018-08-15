#!/usr/bin/env bash

set -o posix

## Pings the running node, or an arbitrary peer node
## by supplying `--peer` and `--cookie` flags.
##
## If the node is running and can be connected to,
## 'pong' will be printed to stdout. If the node is
## not reachable or cannot be connected to due to an
## invalid cookie, 'pang' will be printed to stdout
## and the command will exit with a non-zero status code.

set -e

require_cookie

echo "Waiting for node."

while true; do
  release_ctl ping --peer="$NAME" --cookie="$COOKIE" "$@" > /dev/null
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 0 ]; then
    echo " up."
    break
  fi
  echo -n "."
done

set -e

echo "-*- Running migrations"

require_live_node

release_remote_ctl rpc "Fd.ReleaseTasks.migrate()"

echo "-*- Migrations run successfully"

