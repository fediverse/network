set +e

echo "Starting app."
echo "Waiting for node"

while true; do
  nodetool ping > /dev/null
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 0 ]; then
    echo " up!"
    break
  fi
  echo -n "."
done

set -e

echo "-*- Running migrations"
bin/fd rpc Elixir.Fd.ReleaseTasks migrate
echo "-*- Migrations run successfully"

